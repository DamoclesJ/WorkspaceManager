$ErrorActionPreference = 'Stop'

$multiMonitorTool = Join-Path $PSScriptRoot '..\..\tools\MultiMonitorTool.exe'
$macTarget = 'jiaxiangdong@192.168.1.134'
$m1ddcPath = '/opt/homebrew/bin/m1ddc'
$failed = $false

Write-Host 'WorkspaceManager health check'
Write-Host ''

if (Test-Path -LiteralPath $multiMonitorTool -PathType Leaf) {
    Write-Host "[OK] MultiMonitorTool.exe found: $multiMonitorTool"
}
else {
    Write-Host "[FAIL] MultiMonitorTool.exe not found: $multiMonitorTool" -ForegroundColor Red
    $failed = $true
}

$sshCommand = Get-Command ssh.exe -CommandType Application -ErrorAction SilentlyContinue

if ($null -eq $sshCommand) {
    Write-Host '[FAIL] Windows OpenSSH Client not found in PATH.' -ForegroundColor Red
    Write-Host "[FAIL] Mac SSH connectivity and m1ddc could not be checked: $macTarget" -ForegroundColor Red
    $failed = $true
}
else {
    & $sshCommand.Source -o BatchMode=yes -o ConnectTimeout=5 $macTarget 'true'
    $sshExitCode = $LASTEXITCODE

    if ($sshExitCode -eq 0) {
        Write-Host "[OK] Mac SSH connection succeeded: $macTarget"

        & $sshCommand.Source -o BatchMode=yes -o ConnectTimeout=5 $macTarget "test -x '$m1ddcPath'"
        $m1ddcExitCode = $LASTEXITCODE

        if ($m1ddcExitCode -eq 0) {
            Write-Host "[OK] Remote m1ddc exists and is executable: $m1ddcPath"
        }
        elseif ($m1ddcExitCode -eq 1) {
            Write-Host "[FAIL] Remote m1ddc is missing or not executable: $m1ddcPath" -ForegroundColor Red
            $failed = $true
        }
        else {
            Write-Host "[FAIL] Remote m1ddc check failed with SSH exit code $m1ddcExitCode." -ForegroundColor Red
            $failed = $true
        }
    }
    else {
        Write-Host "[FAIL] Mac SSH connection failed: $macTarget (exit code $sshExitCode)." -ForegroundColor Red
        Write-Host "[FAIL] Remote m1ddc could not be checked because SSH is unavailable: $m1ddcPath" -ForegroundColor Red
        $failed = $true
    }
}

Write-Host ''

if ($failed) {
    Write-Host 'WorkspaceManager health check failed.' -ForegroundColor Red
    exit 1
}

Write-Host 'WorkspaceManager health check passed.' -ForegroundColor Green
exit 0
