param([switch]$RustOnly, [switch]$PolicyTest, [switch]$FrontendOnly, [string]$BuildName = '1.3.3', [int]$BuildNumber = 78)
$ErrorActionPreference = 'Stop'
$taskSource = 'D:\LAN-Messenger\reference\SubnetDesk-v1.3.0\source\zibo-chen-SubnetDesk-1d3ac5a'
$taskTools = 'D:\LAN-Messenger\reference\SubnetDesk-v1.3.0\tools'
$taskChecks = 'D:\LAN-Messenger\outputs\SubnetDesk-helper-cm\checks'
if ($FrontendOnly -and ($RustOnly -or $PolicyTest)) { throw 'FrontendOnly cannot select Rust tests/build.' }
if ($FrontendOnly -and (Get-FileHash -LiteralPath "$taskSource\target\release\librustdesk.dll").Hash -ne
    '9054FD39049AF4C52CCE0D7DB86F82D53A9EE85EFA59552F68958BDC62F2D570') {
    throw 'Frontend-only build requires the verified no-updater1.3.3 backend.'
}
$taskVcvars = 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat'
$taskEnvironment = & $env:ComSpec /d /c ('"' + $taskVcvars + '" >nul && set')
if ($LASTEXITCODE -ne 0) { throw 'MSVC environment setup failed.' }
foreach ($entry in $taskEnvironment) {
    if ($entry -match '^([^=]+)=(.*)$') {
        [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process')
    }
}
$taskMapped = $false
$taskMappings = @(& subst.exe)
$taskSMapping = @($taskMappings | Where-Object { $_ -like 'S:\:*' })
if ($taskSMapping.Count -gt 0) {
    if ($taskSMapping[0] -ne ('S:\: => ' + $taskTools)) { throw 'S: belongs to another target.' }
} elseif (Test-Path 'S:\') { throw 'S: is already in use.' }
else {
    & subst.exe S: $taskTools
    if ($LASTEXITCODE -ne 0) { throw 'Scoped S: mapping failed.' }
    $taskMapped = $true
}
try {
    $env:CARGO_HOME = 'S:\cargo'
    $env:RUSTUP_HOME = 'S:\rustup'
    $env:PUB_CACHE = "$taskTools\pub-cache"
    $env:VCPKG_ROOT = 'S:\vcpkg'
    $env:VCPKG_INSTALLED_ROOT = 'S:\native-installed'
    $env:LIBCLANG_PATH = 'S:\llvm\bin'
    $env:CC = 'cl.exe'
    $env:CXX = 'cl.exe'
    $env:PATH = "S:\cargo\bin;$taskTools\flutter\bin;" + $env:PATH
    Push-Location $taskSource
    try {
        if ($PolicyTest) {
            & cargo.exe test --locked --features flutter,hwcodec,vram,software-update --lib --release private_build -- --nocapture
            if ($LASTEXITCODE -ne 0) { throw 'Private updater policy regression failed.' }
            & cargo.exe test --locked --features flutter,hwcodec,vram,software-update --lib --release camera_access -- --nocapture
            if ($LASTEXITCODE -ne 0) { throw 'Private camera policy regression failed.' }
        } elseif (!$FrontendOnly) {
            & cargo.exe build --locked --features flutter,hwcodec,vram --lib --release
            if ($LASTEXITCODE -ne 0) { throw 'Private Rust release build failed.' }
        }
    } finally { Pop-Location }
    if (!$RustOnly -and !$PolicyTest) {
        Push-Location "$taskSource\flutter"
        try {
            & "$taskTools\flutter\bin\flutter.bat" build windows --release --no-pub --build-name $BuildName --build-number $BuildNumber
            if ($LASTEXITCODE -ne 0) { throw 'Private Flutter Windows build failed.' }
            & "$taskTools\flutter\bin\flutter.bat" test --no-pub
            if ($LASTEXITCODE -ne 0) { throw 'Private Flutter regression failed.' }
        } finally { Pop-Location }
    }
} finally {
    if ($taskMapped) {
        $taskMappingNow = @(& subst.exe | Where-Object { $_ -like 'S:\:*' })
        if ($taskMappingNow.Count -eq 1 -and $taskMappingNow[0] -eq ('S:\: => ' + $taskTools)) {
            & subst.exe S: /D
        }
    }
}
