$ErrorActionPreference = 'Stop'

$displaySwitch = Join-Path $env:WINDIR 'System32\DisplaySwitch.exe'
$multiMonitorTool = Join-Path $PSScriptRoot '..\..\tools\MultiMonitorTool.exe'
$macTarget = 'jiaxiangdong@192.168.1.134'
$remoteCommand = '/opt/homebrew/bin/m1ddc display 1 set input 7'
$u8MonitorId = 'TCL2701'
$u8MonitorName = 'U8'
$targetDisplay = $null
$logFile = Join-Path $PSScriptRoot '..\..\logs\workspace-switch.log'

function Write-WorkspaceLog {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('INFO', 'ERROR')]
        [string]$Level,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    try {
        $logDirectory = Split-Path -Parent $logFile

        if (-not (Test-Path -LiteralPath $logDirectory -PathType Container)) {
            [void](New-Item -ItemType Directory -Path $logDirectory -Force -ErrorAction Stop)
        }

        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Add-Content -LiteralPath $logFile -Value "$timestamp [$Level] [Windows] $Message" -Encoding UTF8 -ErrorAction Stop
    }
    catch {
    }
}

$switchStartTime = Get-Date
Write-WorkspaceLog -Level INFO -Message 'Switch started'

try {

if (-not (Test-Path $multiMonitorTool)) {
    throw "MultiMonitorTool.exe not found: $multiMonitorTool"
}

Write-Host 'Restoring Windows extended desktop on U8 and BenQ...'
& $displaySwitch /extend
$displaySwitchExitCode = $LASTEXITCODE

if ($null -ne $displaySwitchExitCode -and $displaySwitchExitCode -ne 0) {
    Write-WorkspaceLog -Level ERROR -Message "DisplaySwitch /extend failed with exit code $displaySwitchExitCode"
    throw "DisplaySwitch.exe failed with exit code $displaySwitchExitCode."
}

Write-WorkspaceLog -Level INFO -Message 'DisplaySwitch /extend succeeded'
Write-Host 'Windows extended desktop restored.'
Write-Host 'Waiting for displays to become available...'
Start-Sleep -Seconds 3

Write-Host 'Switching Thunderbird U8 to Windows DP through SSH...'
& ssh -o BatchMode=yes -o ConnectTimeout=5 $macTarget $remoteCommand
$sshExitCode = $LASTEXITCODE

if ($sshExitCode -ne 0) {
    Write-WorkspaceLog -Level ERROR -Message "SSH remote command failed with exit code $sshExitCode"
    Write-WorkspaceLog -Level ERROR -Message "m1ddc input switch failed with remote exit code $sshExitCode"
    throw "SSH remote m1ddc command failed with exit code $sshExitCode."
}

Write-WorkspaceLog -Level INFO -Message 'SSH remote command succeeded'
Write-WorkspaceLog -Level INFO -Message 'm1ddc input 7 succeeded'
Write-Host 'Waiting up to 20 seconds for Thunderbird U8 to become active...'
$displayReady = $false
$deadline = (Get-Date).AddSeconds(20)

do {
    $monitorStateFile = Join-Path ([System.IO.Path]::GetTempPath()) (
        "WorkspaceManager-monitor-state-{0}.csv" -f ([Guid]::NewGuid().ToString('N'))
    )

    try {
        $monitorExportArguments = @('/scomma', ('"{0}"' -f $monitorStateFile))
        $monitorExportProcess = Start-Process -FilePath $multiMonitorTool -ArgumentList $monitorExportArguments -Wait -PassThru

        if ($monitorExportProcess.ExitCode -ne 0) {
            Write-WorkspaceLog -Level ERROR -Message "MultiMonitorTool detection failed with exit code $($monitorExportProcess.ExitCode)"
            throw "MultiMonitorTool.exe monitor detection failed with exit code $($monitorExportProcess.ExitCode)."
        }

        $display = $null

        if (Test-Path -LiteralPath $monitorStateFile -PathType Leaf) {
            try {
                $monitorRows = @(Import-Csv -LiteralPath $monitorStateFile)
                $display = $monitorRows |
                    Where-Object {
                        $monitorIdMatches = $_.'Monitor ID' -like "*$u8MonitorId*"
                        $shortMonitorIdMatches = $_.'Short Monitor ID' -eq $u8MonitorId
                        $monitorNameMatches = $_.'Monitor Name' -like "*$u8MonitorName*"
                        $monitorIdMatches -or $shortMonitorIdMatches -or $monitorNameMatches
                    } |
                    Where-Object {
                        $_.Active -eq 'Yes' -and
                        $_.Disconnected -ne 'Yes' -and
                        -not ([string]::IsNullOrWhiteSpace($_.Name))
                    } |
                    Select-Object -First 1
            }
            catch {
                Write-WorkspaceLog -Level ERROR -Message 'MultiMonitorTool monitor data could not be read; readiness polling will continue'
                $display = $null
            }
        }

        if ($null -ne $display) {
            $targetDisplay = $display.Name
            $displayReady = $true
        }
    }
    finally {
        for ($cleanupAttempt = 1; $cleanupAttempt -le 5; $cleanupAttempt++) {
            if (-not (Test-Path -LiteralPath $monitorStateFile)) {
                break
            }

            try {
                Remove-Item -LiteralPath $monitorStateFile -Force -ErrorAction Stop
                break
            }
            catch {
                if ($cleanupAttempt -eq 5) {
                    throw "Failed to remove temporary monitor state file: $monitorStateFile"
                }

                Start-Sleep -Milliseconds 100
            }
        }
    }

    if ($displayReady) {
        break
    }

    Start-Sleep -Seconds 1
} while ((Get-Date) -lt $deadline)

if (-not $displayReady) {
    Write-WorkspaceLog -Level ERROR -Message 'U8 detection timed out after 20 seconds'
    throw "Timed out after 20 seconds waiting for Thunderbird U8 to become active."
}

Write-WorkspaceLog -Level INFO -Message "U8 detected: $targetDisplay"
Write-Host "Thunderbird U8 detected as $targetDisplay."
Write-Host 'Setting Thunderbird U8 as the Windows primary display...'
& $multiMonitorTool /SetPrimary $targetDisplay
$setPrimaryExitCode = $LASTEXITCODE

if ($null -ne $setPrimaryExitCode -and $setPrimaryExitCode -ne 0) {
    Write-WorkspaceLog -Level ERROR -Message "SetPrimary failed for $targetDisplay with exit code $setPrimaryExitCode"
    throw "MultiMonitorTool.exe failed with exit code $setPrimaryExitCode."
}

Write-WorkspaceLog -Level INFO -Message "SetPrimary succeeded: $targetDisplay"
Write-Host 'Windows mode and U8 input switch completed.'
Write-WorkspaceLog -Level INFO -Message 'Switch succeeded'
$switchElapsedSeconds = ((Get-Date) - $switchStartTime).TotalSeconds
Write-WorkspaceLog -Level INFO -Message ('Switch completed in {0:N1}s' -f $switchElapsedSeconds)
}
catch {
    $switchElapsedSeconds = ((Get-Date) - $switchStartTime).TotalSeconds
    Write-WorkspaceLog -Level ERROR -Message "Switch failed: $($_.Exception.Message)"
    Write-WorkspaceLog -Level ERROR -Message ('Switch failed after {0:N1}s' -f $switchElapsedSeconds)
    throw
}
