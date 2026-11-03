param(
    [string]$DeployVersion='1.10.1',
    [int]$DeployBuild=125,
    [string]$AgentVersion='1.7.0',
    [Parameter(Mandatory=$true)][string]$OutputDirectory
)
$ErrorActionPreference='Stop'
$source = Split-Path $PSScriptRoot -Parent
$output = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $output) { throw 'Release directory already exists.' }
New-Item -ItemType Directory -Path $output | Out-Null
$tools = 'D:\Projects AI\tools\SubnetDesk-v1.3.0\tools'
$env:CARGO_HOME=Join-Path $tools 'cargo'
$env:RUSTUP_HOME=Join-Path $tools 'rustup'
$env:PUB_CACHE=Join-Path $tools 'pub-cache'
$env:VCPKG_ROOT=Join-Path $tools 'vcpkg'
$env:VCPKG_INSTALLED_ROOT=Join-Path $tools 'native-installed'
$env:LIBCLANG_PATH=Join-Path $tools 'llvm\bin'
# This release changes deployment UI/services only. Require the existing native
# Helper library rather than silently substituting a different system build.
$native = Join-Path $source 'target\release\librustdesk.dll'
if (-not (Test-Path -LiteralPath $native)) { throw 'Build the native library with the bundled Rust toolchain first.' }
$agentOutput = Join-Path $output 'agent'
& (Join-Path $PSScriptRoot 'build-agent.ps1') -Version $AgentVersion -OutputDirectory $agentOutput
Push-Location (Join-Path $source 'flutter')
try {
    & (Join-Path $tools 'flutter\bin\flutter.bat') build windows --release --no-pub "--build-name=$DeployVersion" "--build-number=$DeployBuild" --dart-define=SUBNETDESK_DEPLOYMENT_UTILITY=true
    if ($LASTEXITCODE -ne 0) { throw 'Deploy Flutter build failed.' }
} finally { Pop-Location }
$bundle = Join-Path $output 'DeployBundle'
New-Item -ItemType Directory -Path $bundle | Out-Null
Copy-Item -Path (Join-Path $source 'flutter\build\windows\x64\runner\Release\*') -Destination $bundle -Recurse
Rename-Item -LiteralPath (Join-Path $bundle 'SubnetDesk.exe') -NewName 'SubnetDeskDeploy.exe'
if ((Get-FileHash (Join-Path $bundle 'librustdesk.dll')).Hash -ne (Get-FileHash $native).Hash) { throw 'Flutter bundle contains a stale native DLL.' }
$management = Join-Path $bundle 'deployment'
New-Item -ItemType Directory -Path $management | Out-Null
foreach ($name in @('SubnetDeskManagement.exe','Initialize-Management.ps1','SubnetDeskAgent.exe')) { Copy-Item -LiteralPath (Join-Path $agentOutput $name) -Destination $management }
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'README.md') -Destination (Join-Path $management 'README.md')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'QUICKSTART-1.6.md') -Destination (Join-Path $management 'QUICKSTART-1.6.md')
& (Join-Path $source 'res\msi\build-deploy-msi.ps1') -DeployBundlePath $bundle -OutputPath (Join-Path $output 'SubnetDesk-Deploy.msi') -WorkPath (Join-Path $output 'wix-work') -WixPath (Join-Path $tools 'wix4\wix.exe') -Version $DeployVersion
Copy-Item -LiteralPath (Join-Path $agentOutput 'SubnetDeskAgent.exe') -Destination $output
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'QUICKSTART-1.6.md') -Destination (Join-Path $output 'QUICKSTART.md')
Write-Output "Deployment release ready: $output"
