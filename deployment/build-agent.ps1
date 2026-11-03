param([string]$Version='1.7.0',[Parameter(Mandatory=$true)][string]$OutputDirectory,[switch]$BuildLegacyMsi)
$ErrorActionPreference='Stop'
$output = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $output) { throw "Preserve existing builds; output already exists: $output" }
New-Item -ItemType Directory -Path $output | Out-Null
$csc = 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\Roslyn\csc.exe'
$wix = 'D:\Projects AI\tools\SubnetDesk-v1.3.0\tools\wix4\wix.exe'
$sources = @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'Agent') -Filter '*.cs' | ForEach-Object FullName)
$assembly = Join-Path $output 'AssemblyInfo.cs'
"[assembly: System.Reflection.AssemblyVersion(`"$Version.0`")]`n[assembly: System.Reflection.AssemblyFileVersion(`"$Version.0`")]`n[assembly: System.Reflection.AssemblyCompany(`"SubnetDesk`")]" | Set-Content -LiteralPath $assembly
Add-Content -LiteralPath $assembly -Value '[assembly: System.Reflection.AssemblyTitle("SubnetDesk Endpoint Agent")][assembly: System.Reflection.AssemblyProduct("SubnetDesk Device Management")][assembly: System.Reflection.AssemblyDescription("Managed Windows agent for SubnetDesk inventory and Helper lifecycle")]'
$sources += $assembly
$agent = Join-Path $output 'SubnetDeskAgent.exe'
& $csc /nologo /target:winexe /platform:x64 /optimize+ /r:System.Management.dll /r:System.ServiceProcess.dll /r:System.Web.Extensions.dll /r:System.Security.dll /r:System.Windows.Forms.dll /r:System.Drawing.dll /r:Microsoft.CSharp.dll "/win32manifest:$(Join-Path $PSScriptRoot 'Agent\app.manifest')" "/win32icon:$(Join-Path (Split-Path $PSScriptRoot -Parent) 'res\icon.ico')" "/out:$agent" @sources
if ($LASTEXITCODE -ne 0) { throw 'Agent compilation failed.' }
Copy-Item -LiteralPath $agent -Destination (Join-Path $output 'SubnetDeskManagement.exe')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Configure-Agent.ps1') -Destination $output
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Initialize-Management.ps1') -Destination $output
if ($BuildLegacyMsi) {
$msi = Join-Path $output 'SubnetDesk-Agent.msi'
& $wix build (Join-Path $PSScriptRoot 'Agent\Package.wxs') -arch x64 -d "Version=$Version" -d "Bundle=$output" -out $msi
if ($LASTEXITCODE -ne 0) { throw 'Agent MSI build failed.' }
& $wix msi validate $msi *> "$msi.validation.log"
if ($LASTEXITCODE -ne 0) { throw 'Agent MSI validation failed.' }
Write-Output "Created $msi"
} else { Write-Output "Created $agent" }
