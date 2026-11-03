param(
  [string]$Version = '1.4.4',
  [int]$Build = 104,
  [string]$ToolsRoot = 'D:\Projects AI\tools\SubnetDesk-v1.3.0\tools'
)
$ErrorActionPreference = 'Stop'
$source = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$output = Join-Path $source 'output'
$manifestVersion = [regex]::Match((Get-Content (Join-Path $source 'Cargo.toml') -Raw), '(?m)^version = "([^"]+)"').Groups[1].Value
if ($manifestVersion -ne $Version) { throw "Update Cargo.toml and Cargo.lock to $Version before packaging." }
$helper = Join-Path $output "SubnetDesk-Helper-$Version-build$Build-Windows-x64.msi"
$deploy = Join-Path $output "SubnetDesk-Deploy-$Version-build$Build-Windows-x64.msi"
$helperBundle = Join-Path $output "SubnetDesk-Helper-bundle-$Version-build$Build"
$deployBundle = Join-Path $output "SubnetDesk-Deploy-bundle-$Version-build$Build"
foreach ($destination in @($helper, $deploy, $helperBundle, $deployBundle)) {
  if (Test-Path -LiteralPath $destination) { throw "Output already exists: $destination" }
}
$vcvars = 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat'
$environmentLines = & $env:ComSpec /d /c ('"' + $vcvars + '" >nul && set')
if ($LASTEXITCODE -ne 0) { throw 'Visual Studio environment setup failed' }
foreach ($entry in $environmentLines) {
  if ($entry -match '^([^=]+)=(.*)$') { [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process') }
}
$mapped = $false
$mapping = @(& subst.exe | Where-Object { $_ -like 'S:\:*' })
if ($mapping.Count) {
  if ($mapping[0] -ne ('S:\: => ' + $ToolsRoot)) { throw 'S: belongs to another folder' }
} elseif (Test-Path 'S:\') { throw 'S: is already in use' }
else { & subst.exe S: $ToolsRoot; if ($LASTEXITCODE -ne 0) { throw 'Tool mapping failed' }; $mapped = $true }
try {
  $env:CARGO_HOME = 'S:\cargo'
  $env:RUSTUP_HOME = 'S:\rustup'
  $env:PUB_CACHE = Join-Path $ToolsRoot 'pub-cache'
  $env:VCPKG_ROOT = 'S:\vcpkg'
  $env:VCPKG_INSTALLED_ROOT = 'S:\native-installed'
  $env:LIBCLANG_PATH = 'S:\llvm\bin'
  $env:CARGO_TARGET_DIR = Join-Path $output 'native-release'
  $env:CARGO_BUILD_JOBS = '4'
  $env:CC = 'cl.exe'; $env:CXX = 'cl.exe'
  $env:PATH = 'S:\cargo\bin;' + $env:PATH
  Push-Location $source
  try {
    $nativeLog = Join-Path $output "windows-native-$Version-build$Build.log"
    & 'S:\cargo\bin\cargo.exe' build --locked --offline --release --features flutter,hwcodec,vram --lib *> $nativeLog
    if ($LASTEXITCODE -ne 0) { throw "Native compilation failed: $nativeLog" }
    $native = Join-Path $env:CARGO_TARGET_DIR 'release\librustdesk.dll'
    $nativeHash = (Get-FileHash -LiteralPath $native -Algorithm SHA256).Hash
    Copy-Item -LiteralPath $native -Destination (Join-Path $source 'target\release\librustdesk.dll') -Force
    $flutter = Join-Path $ToolsRoot 'flutter\bin\flutter.bat'
    foreach ($flavor in @(@{Define='false';Bundle=$helperBundle}, @{Define='true';Bundle=$deployBundle})) {
      Push-Location (Join-Path $source 'flutter')
      try {
        & $flutter build windows --release "--build-name=$Version" "--build-number=$Build" "--dart-define=SUBNETDESK_DEPLOYMENT_UTILITY=$($flavor.Define)"
        if ($LASTEXITCODE -ne 0) { throw 'Flutter build failed' }
      } finally { Pop-Location }
      New-Item -ItemType Directory -Path $flavor.Bundle | Out-Null
      Copy-Item -Path (Join-Path $source 'flutter\build\windows\x64\runner\Release\*') -Destination $flavor.Bundle -Recurse
      if ((Get-FileHash (Join-Path $flavor.Bundle 'librustdesk.dll')).Hash -ne $nativeHash) { throw 'Stale native DLL in Flutter bundle' }
    }
    & python (Join-Path $PSScriptRoot 'preprocess.py') --dist-dir $helperBundle --app-name SubnetDesk --version $Version --revision-version $Build
    if ($LASTEXITCODE -ne 0) { throw 'Helper MSI preprocessing failed' }
    & msbuild (Join-Path $PSScriptRoot 'CustomActions\CustomActions.vcxproj') /t:Build /p:Configuration=Release /p:Platform=x64 /v:quiet
    if ($LASTEXITCODE -ne 0) { throw 'MSI custom actions build failed' }
    $packageRoot = Join-Path $PSScriptRoot 'Package'
    $wixArgs = @('build') + @(Get-ChildItem -LiteralPath $packageRoot -Filter '*.wxs' -Recurse | ForEach-Object FullName)
    $wixArgs += @('-arch','x64','-culture','en-us','-d',"CustomActions.TargetDir=$PSScriptRoot\CustomActions\x64\Release\",'-d','CustomActions.TargetName=CustomActions','-out',$helper)
    foreach ($extension in @('Firewall','Netfx','UI','Util')) {
      $extensionPath = Join-Path $env:USERPROFILE ".nuget\packages\wixtoolset.$($extension.ToLower()).wixext\4.0.5\wixext4\WixToolset.$extension.wixext.dll"
      $wixArgs += @('-ext', $extensionPath)
    }
    foreach ($localization in Get-ChildItem (Join-Path $packageRoot 'Language') -Filter '*.wxl') { $wixArgs += @('-loc', $localization.FullName) }
    Push-Location $packageRoot
    try { & (Join-Path $ToolsRoot 'wix4\wix.exe') @wixArgs; if ($LASTEXITCODE -ne 0) { throw 'Helper MSI build failed' } }
    finally { Pop-Location }
    & (Join-Path $PSScriptRoot 'build-deploy-msi.ps1') -DeployBundlePath $deployBundle -OutputPath $deploy -WorkPath (Join-Path $output "deploy-work-$Version-build$Build") -WixPath (Join-Path $ToolsRoot 'wix4\wix.exe') -Version $Version
    & (Join-Path $ToolsRoot 'wix4\wix.exe') msi validate $helper *> "$helper.validation.log"
    if ($LASTEXITCODE -ne 0) { throw "Helper MSI validation failed: $helper.validation.log" }
    @{version=$Version;build=$Build;nativeSha256=$nativeHash;helper=$helper;deploy=$deploy} | ConvertTo-Json | Set-Content (Join-Path $output "build$Build-manifest.json")
  } finally { Pop-Location }
} finally {
  if ($mapped) { & subst.exe S: /D }
}
