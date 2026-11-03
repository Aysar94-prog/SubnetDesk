param([string]$Version='1.4.5',[int]$Build=115,[string]$NativeBuildLog='output\windows-native-policy115.log',[Parameter(Mandatory=$true)][string]$OutputDirectory)
$ErrorActionPreference='Stop'
$source=Split-Path $PSScriptRoot -Parent
$tools='D:\Projects AI\tools\SubnetDesk-v1.3.0\tools'
$output=[IO.Path]::GetFullPath($OutputDirectory)
if(Test-Path -LiteralPath $output){throw 'Preserve existing release directories.'}
$native=Join-Path $source 'output\native-release\release\librustdesk.dll'
if((Get-Content (Join-Path $source $NativeBuildLog) -Raw) -notmatch 'Finished.*release.*target'){throw 'Completed bundled native policy build required.'}
if((Get-Content (Join-Path $source 'Cargo.toml') -Raw) -notmatch ('(?m)^version = "'+[regex]::Escape($Version)+'"')){throw 'Native source version mismatch.'}
New-Item -ItemType Directory -Path $output | Out-Null
$vcvars='C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat'
$environment=& $env:ComSpec /d /c ('"'+$vcvars+'" >nul && set')
if($LASTEXITCODE -ne 0){throw 'MSVC setup failed.'}
foreach($entry in $environment){if($entry -match '^([^=]+)=(.*)$'){[Environment]::SetEnvironmentVariable($matches[1],$matches[2],'Process')}}
$env:CARGO_HOME=Join-Path $tools 'cargo'; $env:RUSTUP_HOME=Join-Path $tools 'rustup'
$env:PUB_CACHE=Join-Path $tools 'pub-cache'; $env:VCPKG_ROOT=Join-Path $tools 'vcpkg'
$env:VCPKG_INSTALLED_ROOT=Join-Path $tools 'native-installed'; $env:LIBCLANG_PATH=Join-Path $tools 'llvm\bin'
Copy-Item -LiteralPath $native -Destination (Join-Path $source 'target\release\librustdesk.dll') -Force
Push-Location (Join-Path $source 'flutter')
try {
 & (Join-Path $tools 'flutter\bin\flutter.bat') build windows --release --no-pub "--build-name=$Version" "--build-number=$Build" --dart-define=SUBNETDESK_DEPLOYMENT_UTILITY=false
 if($LASTEXITCODE -ne 0){throw 'Helper Flutter build failed.'}
} finally {Pop-Location}
$bundle=Join-Path $output 'HelperBundle'; New-Item -ItemType Directory -Path $bundle | Out-Null
Copy-Item -Path (Join-Path $source 'flutter\build\windows\x64\runner\Release\*') -Destination $bundle -Recurse
if((Get-FileHash -LiteralPath (Join-Path $bundle 'librustdesk.dll')).Hash -ne (Get-FileHash -LiteralPath $native).Hash){throw 'Stale native DLL.'}
$python='C:\Users\user\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
& $python (Join-Path $source 'res\msi\preprocess.py') --dist-dir $bundle --app-name SubnetDesk --version $Version --revision-version $Build
if($LASTEXITCODE -ne 0){throw 'Helper MSI preprocessing failed.'}
& 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe' (Join-Path $source 'res\msi\CustomActions\CustomActions.vcxproj') /t:Build /p:Configuration=Release /p:Platform=x64 /v:quiet
if($LASTEXITCODE -ne 0){throw 'MSI custom actions build failed.'}
$package=Join-Path $source 'res\msi\Package'; $wix=Join-Path $tools 'wix4\wix.exe'; $msi=Join-Path $output 'SubnetDesk-Helper.msi'
$arguments=@('build')+@(Get-ChildItem -LiteralPath $package -Filter '*.wxs' -Recurse | ForEach-Object FullName)
$arguments+=@('-arch','x64','-culture','en-us','-d',"CustomActions.TargetDir=$source\res\msi\CustomActions\x64\Release\",'-d','CustomActions.TargetName=CustomActions','-out',$msi)
foreach($extension in @('Firewall','Netfx','UI','Util')){$arguments+=@('-ext',(Join-Path $env:USERPROFILE ".nuget\packages\wixtoolset.$($extension.ToLower()).wixext\4.0.5\wixext4\WixToolset.$extension.wixext.dll"))}
foreach($localization in Get-ChildItem (Join-Path $package 'Language') -Filter '*.wxl'){$arguments+=@('-loc',$localization.FullName)}
Push-Location $package
try{& $wix @arguments; if($LASTEXITCODE -ne 0){throw 'Helper MSI build failed.'}}finally{Pop-Location}
& $wix msi validate $msi *> "$msi.validation.log"
if($LASTEXITCODE -ne 0){throw 'Helper MSI validation failed.'}
Write-Output "Helper release ready: $msi"
