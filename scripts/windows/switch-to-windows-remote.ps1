$ErrorActionPreference = 'Stop'

$displaySwitch = Join-Path $env:WINDIR 'System32\DisplaySwitch.exe'
$multiMonitorTool = Join-Path $PSScriptRoot '..\..\tools\MultiMonitorTool.exe'
$macTarget = 'jiaxiangdong@192.168.1.134'
$remoteCommand = '/opt/homebrew/bin/m1ddc display 1 set input 7'
$targetDisplay = '\\.\DISPLAY1'

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
            throw "MultiMonitorTool.exe monitor detection failed with exit code $($monitorExportProcess.ExitCode)."
        }

        $display = $null

        if (Test-Path -LiteralPath $monitorStateFile -PathType Leaf) {
            try {
                $monitorRows = @(Import-Csv -LiteralPath $monitorStateFile)
                $display = $monitorRows |
                    Where-Object { $_.Name -eq $targetDisplay } |
                    Select-Object -First 1
            }
            catch {
                $display = $null
            }
        }

        if ($null -ne $display -and $display.Active -eq 'Yes' -and $display.Disconnected -ne 'Yes') {
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
    throw "Timed out after 20 seconds waiting for $targetDisplay to become active."
}

Write-Host 'Setting Thunderbird U8 as the Windows primary display...'
& $multiMonitorTool /SetPrimary $targetDisplay

if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
    throw "MultiMonitorTool.exe failed with exit code $LASTEXITCODE."
}

Write-Host 'Windows mode and U8 input switch completed.'
