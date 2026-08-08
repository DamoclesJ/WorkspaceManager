$ErrorActionPreference = 'Stop'

$displaySwitch = Join-Path $env:WINDIR 'System32\DisplaySwitch.exe'

Write-Host 'Switching Windows to BenQ only and releasing U8 DP...'
& $displaySwitch /external

if ($LASTEXITCODE -ne 0) {
    throw "DisplaySwitch.exe failed with exit code $LASTEXITCODE."
}

Write-Host 'Windows switched to external display mode. U8 should return to Mac HDMI.'
