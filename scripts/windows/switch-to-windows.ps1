$ErrorActionPreference = 'Stop'

$displaySwitch = Join-Path $env:WINDIR 'System32\DisplaySwitch.exe'

Write-Host 'Restoring Windows extended desktop on U8 and BenQ...'
& $displaySwitch /extend

if ($LASTEXITCODE -ne 0) {
    throw "DisplaySwitch.exe failed with exit code $LASTEXITCODE."
}

Write-Host 'Windows extended desktop restored.'
Write-Host 'Now run scripts/mac/switch-input-to-windows.sh on the Mac.'
