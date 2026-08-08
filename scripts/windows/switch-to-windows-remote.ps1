$ErrorActionPreference = 'Stop'

$displaySwitch = Join-Path $env:WINDIR 'System32\DisplaySwitch.exe'
$macTarget = 'jiaxiangdong@192.168.1.134'
$remoteCommand = '/opt/homebrew/bin/m1ddc display 1 set input 7'

Write-Host 'Restoring Windows extended desktop on U8 and BenQ...'
& $displaySwitch /extend

if ($LASTEXITCODE -ne 0) {
    throw "DisplaySwitch.exe failed with exit code $LASTEXITCODE."
}

Write-Host 'Windows extended desktop restored.'
Write-Host 'Switching Thunderbird U8 to Windows DP through SSH...'
& ssh $macTarget $remoteCommand

if ($LASTEXITCODE -ne 0) {
    throw "SSH remote m1ddc command failed with exit code $LASTEXITCODE."
}

Write-Host 'Windows mode and U8 input switch completed.'
