$ErrorActionPreference = 'Stop'

$displaySwitch = Join-Path $env:WINDIR 'System32\DisplaySwitch.exe'
$multiMonitorTool = Join-Path $PSScriptRoot '..\..\tools\MultiMonitorTool.exe'
$macTarget = 'jiaxiangdong@192.168.1.134'
$remoteCommand = '/opt/homebrew/bin/m1ddc display 1 set input 7'

if (-not (Test-Path $multiMonitorTool)) {
    throw "MultiMonitorTool.exe not found: $multiMonitorTool"
}

Write-Host 'Restoring Windows extended desktop on U8 and BenQ...'
& $displaySwitch /extend

if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
    throw "DisplaySwitch.exe failed with exit code $LASTEXITCODE."
}

Write-Host 'Windows extended desktop restored.'
Write-Host 'Waiting for displays to become available...'
Start-Sleep -Seconds 3

Write-Host 'Switching Thunderbird U8 to Windows DP through SSH...'
& ssh -o BatchMode=yes -o ConnectTimeout=5 $macTarget $remoteCommand

if ($LASTEXITCODE -ne 0) {
    throw "SSH remote m1ddc command failed with exit code $LASTEXITCODE."
}

Write-Host 'Waiting for the U8 input switch to complete...'
Start-Sleep -Seconds 10

Write-Host 'Setting Thunderbird U8 as the Windows primary display...'
& $multiMonitorTool /SetPrimary '\\.\DISPLAY1'

if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
    throw "MultiMonitorTool.exe failed with exit code $LASTEXITCODE."
}

Write-Host 'Windows mode and U8 input switch completed.'
