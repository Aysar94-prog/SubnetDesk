param(
    [string]$Version = '1.4.7',
    [int]$Build = 125,
    [switch]$ReuseFrontendBuild,
    [string]$ToolsRoot = 'D:\Projects AI\tools\SubnetDesk-v1.3.0\tools'
)
$ErrorActionPreference = 'Stop'
$project = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$bundle = Join-Path $project "output\SubnetDesk-Helper-bundle-$Version-build$Build"
$stage = Join-Path $project "output\helper-$Version-build$Build-msi-stage"
$engineRegression = Join-Path $project "output\helper-$Version-build$Build-engine-regression"
$msi = Join-Path $project "output\SubnetDesk-Helper-$Version-build$Build-Windows-x64.msi"
foreach ($path in @($bundle, $stage, $msi)) {
    if (Test-Path -LiteralPath $path) { throw "Candidate already exists: $path" }
}
$native = Join-Path $project 'target\release\librustdesk.dll'
$previousNative = Join-Path $project 'output\SubnetDesk-Helper-bundle-1.4.6-build123\librustdesk.dll'
if ($Version -eq '1.4.6') {
    if ((Get-FileHash -LiteralPath $native).Hash -ne (Get-FileHash -LiteralPath $previousNative).Hash) {
        throw 'This frontend-only repair requires the validated Build123 backend.'
    }
} else {
    $nativeManifest = Get-Content -LiteralPath (Join-Path $project "output\native-$Version-build$Build.json") -Raw | ConvertFrom-Json
    if ($nativeManifest.version -ne $Version -or $nativeManifest.build -ne $Build -or
        (Get-FileHash -LiteralPath $native).Hash -ne $nativeManifest.sha256) {
        throw 'The versioned native build manifest does not match the backend.'
    }
}
& python (Join-Path $PSScriptRoot 'test_flutter_accessibility.py') -v
if ($LASTEXITCODE -ne 0) { throw 'Native accessibility guard regression failed.' }
$vcvars = 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat'
$environment = & $env:ComSpec /d /c ('"' + $vcvars + '" >nul && set')
if ($LASTEXITCODE -ne 0) { throw 'Visual Studio environment setup failed.' }
foreach ($entry in $environment) {
    if ($entry -match '^([^=]+)=(.*)$') {
        [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process')
    }
}
$env:PUB_CACHE = Join-Path $ToolsRoot 'pub-cache'
$frontend = Join-Path $project 'flutter\build\windows\x64\runner\Release'
if (!$ReuseFrontendBuild) {
    Push-Location (Join-Path $project 'flutter')
    try {
        & (Join-Path $ToolsRoot 'flutter\bin\flutter.bat') --verbose --no-version-check build windows --release --no-pub "--build-name=$Version" "--build-number=$Build" --dart-define=SUBNETDESK_DEPLOYMENT_UTILITY=false
        if ($LASTEXITCODE -ne 0) { throw 'Flutter release build failed.' }
    } finally { Pop-Location }
}
if ((Get-Item -LiteralPath (Join-Path $frontend 'SubnetDesk.exe')).VersionInfo.FileVersion -ne "$Version+$Build") {
    throw 'The frontend executable does not match the requested version/build.'
}
New-Item -ItemType Directory -Path $bundle | Out-Null
Copy-Item -Path (Join-Path $frontend '*') -Destination $bundle -Recurse
# The frontend may be built while the version-only native rebuild runs. Always
# package the separately verified current native DLL, never its earlier copy.
Copy-Item -LiteralPath $native -Destination (Join-Path $bundle 'librustdesk.dll') -Force
if ((Get-FileHash -LiteralPath (Join-Path $bundle 'librustdesk.dll')).Hash -ne (Get-FileHash -LiteralPath $native).Hash) {
    throw 'Stale backend in the release bundle.'
}
& python (Join-Path $PSScriptRoot 'patch_flutter_accessibility.py') (Join-Path $bundle 'flutter_windows.dll') --manifest (Join-Path $bundle 'flutter-accessibility-fix.json')
if ($LASTEXITCODE -ne 0) { throw 'Pinned engine patch failed.' }
& python (Join-Path $PSScriptRoot 'test_flutter_accessibility_engine.py') (Join-Path $ToolsRoot 'flutter\bin\cache\artifacts\engine\windows-x64-release\flutter_windows.dll') $engineRegression
if ($LASTEXITCODE -ne 0) { throw 'Patched engine integration regression failed.' }
if ((Get-FileHash -LiteralPath (Join-Path $bundle 'flutter_windows.dll')).Hash -ne
    (Get-FileHash -LiteralPath (Join-Path $engineRegression 'flutter_windows.dll')).Hash) {
    throw 'Packaged engine differs from the integration-tested engine.'
}
# Preserve the previously validated installer custom actions, including the
# device-wide Receiver-only reset on install/reinstall/repair/upgrade.
Copy-Item -LiteralPath (Join-Path $project 'output\helper-discovery-build122-msi-stage') -Destination $stage -Recurse
& python (Join-Path $stage 'preprocess.py') --dist-dir $bundle --app-name SubnetDesk --version $Version --revision-version $Build
if ($LASTEXITCODE -ne 0) { throw 'MSI preprocessing failed.' }
& msbuild (Join-Path $stage 'CustomActions\CustomActions.vcxproj') /t:Build /p:Configuration=Release /p:Platform=x64 /v:quiet
if ($LASTEXITCODE -ne 0) { throw 'MSI custom actions build failed.' }
$packageRoot = Join-Path $stage 'Package'
$wixArgs = @('build') + @(Get-ChildItem -LiteralPath $packageRoot -Filter '*.wxs' -Recurse | ForEach-Object FullName)
$wixArgs += @('-arch','x64','-culture','en-us','-d',"CustomActions.TargetDir=$stage\CustomActions\x64\Release\",'-d','CustomActions.TargetName=CustomActions','-out',$msi)
foreach ($extension in @('Firewall','Netfx','UI','Util')) {
    $extensionPath = Join-Path $env:USERPROFILE ".nuget\packages\wixtoolset.$($extension.ToLower()).wixext\4.0.5\wixext4\WixToolset.$extension.wixext.dll"
    $wixArgs += @('-ext', $extensionPath)
}
foreach ($localization in Get-ChildItem (Join-Path $packageRoot 'Language') -Filter '*.wxl') {
    $wixArgs += @('-loc', $localization.FullName)
}
Push-Location $packageRoot
try {
    & (Join-Path $ToolsRoot 'wix4\wix.exe') @wixArgs
    if ($LASTEXITCODE -ne 0) { throw 'Helper MSI build failed.' }
} finally { Pop-Location }
& (Join-Path $ToolsRoot 'wix4\wix.exe') msi validate $msi
if ($LASTEXITCODE -ne 0) { throw 'Helper MSI validation failed.' }
Write-Output "Validated candidate: $msi"
