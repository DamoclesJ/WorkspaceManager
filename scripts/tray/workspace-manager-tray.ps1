Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$scriptsDir = Split-Path -Parent $PSScriptRoot
$rootDir = Split-Path -Parent $scriptsDir
$switchToWindowsPath = Join-Path $rootDir 'scripts\launcher\switch-to-windows.vbs'
$switchToMacPath = Join-Path $rootDir 'scripts\launcher\switch-to-mac.vbs'
$healthScriptPath = Join-Path $rootDir 'scripts\health\check-workspace-health.ps1'
$logFilePath = Join-Path $rootDir 'logs\workspace-switch.log'
$wscriptPath = Join-Path $env:WINDIR 'System32\wscript.exe'
$powerShellPath = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'

function Show-WorkspaceMessage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $true)]
        [System.Windows.Forms.MessageBoxIcon]$Icon
    )

    [void][System.Windows.Forms.MessageBox]::Show(
        $Message,
        'WorkspaceManager',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        $Icon
    )
}

function Start-VbsLauncher {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Show-WorkspaceMessage -Message "Launcher not found:`r`n$Path" -Icon Error
        return
    }

    if (-not (Test-Path -LiteralPath $wscriptPath -PathType Leaf)) {
        Show-WorkspaceMessage -Message "wscript.exe not found:`r`n$wscriptPath" -Icon Error
        return
    }

    try {
        $launcherArgument = '"{0}"' -f $Path
        [void](Start-Process -FilePath $wscriptPath -ArgumentList $launcherArgument -ErrorAction Stop)
    }
    catch {
        Show-WorkspaceMessage -Message "Unable to start launcher:`r`n$Path`r`n`r`n$($_.Exception.Message)" -Icon Error
    }
}

function Invoke-WorkspaceHealthCheck {
    if (-not (Test-Path -LiteralPath $healthScriptPath -PathType Leaf)) {
        Show-WorkspaceMessage -Message "Health check script not found:`r`n$healthScriptPath" -Icon Error
        return
    }

    if (-not (Test-Path -LiteralPath $powerShellPath -PathType Leaf)) {
        Show-WorkspaceMessage -Message "Windows PowerShell not found:`r`n$powerShellPath" -Icon Error
        return
    }

    try {
        $healthArguments = @(
            '-NoProfile'
            '-ExecutionPolicy'
            'Bypass'
            '-WindowStyle'
            'Hidden'
            '-File'
            ('"{0}"' -f $healthScriptPath)
        )
        $healthProcess = Start-Process `
            -FilePath $powerShellPath `
            -ArgumentList $healthArguments `
            -WindowStyle Hidden `
            -Wait `
            -PassThru `
            -ErrorAction Stop

        if ($healthProcess.ExitCode -eq 0) {
            Show-WorkspaceMessage -Message 'Workspace health check passed.' -Icon Information
        }
        else {
            Show-WorkspaceMessage `
                -Message "Workspace health check failed (exit code $($healthProcess.ExitCode)).`r`n`r`nRun the health check manually for details:`r`n$healthScriptPath" `
                -Icon Error
        }
    }
    catch {
        Show-WorkspaceMessage -Message "Unable to run health check:`r`n$($_.Exception.Message)" -Icon Error
    }
}

function Open-WorkspaceLog {
    if (-not (Test-Path -LiteralPath $logFilePath -PathType Leaf)) {
        Show-WorkspaceMessage `
            -Message "Workspace switch log does not exist yet:`r`n$logFilePath" `
            -Icon Information
        return
    }

    try {
        [void](Start-Process -FilePath $logFilePath -ErrorAction Stop)
    }
    catch {
        Show-WorkspaceMessage -Message "Unable to open log file:`r`n$logFilePath`r`n`r`n$($_.Exception.Message)" -Icon Error
    }
}

$mutex = $null
$ownsMutex = $false
$notifyIcon = $null
$contextMenu = $null

try {
    $createdNew = $false
    $mutex = [System.Threading.Mutex]::new($true, 'Local\WorkspaceManagerTray', [ref]$createdNew)

    if (-not $createdNew) {
        exit 0
    }

    $ownsMutex = $true

    [System.Windows.Forms.Application]::EnableVisualStyles()

    $contextMenu = New-Object System.Windows.Forms.ContextMenuStrip
    $switchToWindowsItem = New-Object System.Windows.Forms.ToolStripMenuItem 'Switch to Windows'
    $switchToMacItem = New-Object System.Windows.Forms.ToolStripMenuItem 'Switch to Mac'
    $healthCheckItem = New-Object System.Windows.Forms.ToolStripMenuItem 'Health Check'
    $openLogsItem = New-Object System.Windows.Forms.ToolStripMenuItem 'Open Logs'
    $exitItem = New-Object System.Windows.Forms.ToolStripMenuItem 'Exit'

    $switchToWindowsItem.Add_Click({ Start-VbsLauncher -Path $switchToWindowsPath })
    $switchToMacItem.Add_Click({ Start-VbsLauncher -Path $switchToMacPath })
    $healthCheckItem.Add_Click({ Invoke-WorkspaceHealthCheck })
    $openLogsItem.Add_Click({ Open-WorkspaceLog })
    $exitItem.Add_Click({ [System.Windows.Forms.Application]::Exit() })

    [void]$contextMenu.Items.Add($switchToWindowsItem)
    [void]$contextMenu.Items.Add($switchToMacItem)
    [void]$contextMenu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    [void]$contextMenu.Items.Add($healthCheckItem)
    [void]$contextMenu.Items.Add($openLogsItem)
    [void]$contextMenu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    [void]$contextMenu.Items.Add($exitItem)

    $notifyIcon = New-Object System.Windows.Forms.NotifyIcon
    $notifyIcon.Icon = [System.Drawing.SystemIcons]::Application
    $notifyIcon.Text = 'WorkspaceManager'
    $notifyIcon.ContextMenuStrip = $contextMenu
    $notifyIcon.Visible = $true

    [System.Windows.Forms.Application]::Run()
}
catch {
    Show-WorkspaceMessage -Message "WorkspaceManager tray failed to start:`r`n$($_.Exception.Message)" -Icon Error
}
finally {
    if ($null -ne $notifyIcon) {
        $notifyIcon.Visible = $false
        $notifyIcon.Dispose()
    }

    if ($null -ne $contextMenu) {
        $contextMenu.Dispose()
    }

    if ($ownsMutex -and $null -ne $mutex) {
        try {
            $mutex.ReleaseMutex()
        }
        catch {
        }
    }

    if ($null -ne $mutex) {
        $mutex.Dispose()
    }
}
