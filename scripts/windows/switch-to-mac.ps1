$ErrorActionPreference = 'Stop'

$displaySwitch = Join-Path $env:WINDIR 'System32\DisplaySwitch.exe'
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
        Add-Content -LiteralPath $logFile -Value "$timestamp [$Level] [Mac] $Message" -Encoding UTF8 -ErrorAction Stop
    }
    catch {
    }
}

$switchStartTime = Get-Date
Write-WorkspaceLog -Level INFO -Message 'Switch started'
Write-WorkspaceLog -Level INFO -Message 'SSH remote command not used by the verified Switch to Mac flow'
Write-WorkspaceLog -Level INFO -Message 'm1ddc not invoked; U8 returns to Mac HDMI automatically after Windows releases DP'

try {

Write-Host 'Switching Windows to BenQ only and releasing U8 DP...'
& $displaySwitch /external
$displaySwitchExitCode = $LASTEXITCODE

if ($displaySwitchExitCode -ne 0) {
    Write-WorkspaceLog -Level ERROR -Message "DisplaySwitch /external failed with exit code $displaySwitchExitCode"
    throw "DisplaySwitch.exe failed with exit code $displaySwitchExitCode."
}

Write-WorkspaceLog -Level INFO -Message 'DisplaySwitch /external succeeded'
Write-Host 'Windows switched to external display mode. U8 should return to Mac HDMI.'
Write-WorkspaceLog -Level INFO -Message 'U8 DP released; automatic return to Mac HDMI expected'
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
