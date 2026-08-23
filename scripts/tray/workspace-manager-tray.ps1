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
$iconPath = Join-Path $rootDir 'assets\workspace-manager.ico'
$startTrayLauncherPath = Join-Path $rootDir 'scripts\launcher\start-workspace-manager-tray.vbs'
$startupFolderPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Startup)
$startupShortcutPath = if ([string]::IsNullOrWhiteSpace($startupFolderPath)) {
    $null
}
else {
    Join-Path $startupFolderPath 'WorkspaceManager.lnk'
}
$startupShortcutDescription = 'WorkspaceManager Tray Controller (managed by WorkspaceManager)'
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

function Get-WorkspaceTrayIcon {
    if (Test-Path -LiteralPath $iconPath -PathType Leaf) {
        $sourceIcon = $null

        try {
            $sourceIcon = New-Object System.Drawing.Icon -ArgumentList $iconPath
            return [System.Drawing.Icon]($sourceIcon.Clone())
        }
        catch {
        }
        finally {
            if ($null -ne $sourceIcon) {
                $sourceIcon.Dispose()
            }
        }
    }

    return [System.Drawing.Icon]([System.Drawing.SystemIcons]::Application.Clone())
}

function Release-WorkspaceComObject {
    param(
        [object]$ComObject
    )

    if ($null -eq $ComObject) {
        return
    }

    try {
        [void][System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($ComObject)
    }
    catch {
    }
}

function Test-WorkspacePathsEqual {
    param(
        [string]$Left,
        [string]$Right
    )

    if ([string]::IsNullOrWhiteSpace($Left) -or [string]::IsNullOrWhiteSpace($Right)) {
        return $false
    }

    try {
        $leftPath = [System.IO.Path]::GetFullPath($Left)
        $rightPath = [System.IO.Path]::GetFullPath($Right)
        return [string]::Equals($leftPath, $rightPath, [System.StringComparison]::OrdinalIgnoreCase)
    }
    catch {
        return $false
    }
}

function Get-StartupShortcutInfo {
    if ([string]::IsNullOrWhiteSpace($startupShortcutPath)) {
        return $null
    }

    if (-not (Test-Path -LiteralPath $startupShortcutPath -PathType Leaf)) {
        return $null
    }

    $shell = $null
    $shortcut = $null

    try {
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($startupShortcutPath)

        return [PSCustomObject]@{
            TargetPath = [string]$shortcut.TargetPath
            Description = [string]$shortcut.Description
        }
    }
    finally {
        Release-WorkspaceComObject -ComObject $shortcut
        Release-WorkspaceComObject -ComObject $shell
    }
}

function Test-ManagedStartupShortcut {
    param(
        [object]$ShortcutInfo
    )

    if ($null -eq $ShortcutInfo) {
        return $false
    }

    return (
        (Test-WorkspacePathsEqual -Left $ShortcutInfo.TargetPath -Right $startTrayLauncherPath) -or
        $ShortcutInfo.Description -eq $startupShortcutDescription
    )
}

function Test-StartWithWindows {
    try {
        $shortcutInfo = Get-StartupShortcutInfo

        if ($null -eq $shortcutInfo) {
            return $false
        }

        return Test-WorkspacePathsEqual -Left $shortcutInfo.TargetPath -Right $startTrayLauncherPath
    }
    catch {
        return $false
    }
}

function Enable-StartWithWindows {
    if (-not (Test-Path -LiteralPath $startTrayLauncherPath -PathType Leaf)) {
        throw "Tray launcher not found: $startTrayLauncherPath"
    }

    if ([string]::IsNullOrWhiteSpace($startupFolderPath)) {
        throw 'Current user Startup folder could not be resolved.'
    }

    if (Test-Path -LiteralPath $startupShortcutPath -PathType Leaf) {
        $existingShortcut = Get-StartupShortcutInfo

        if (-not (Test-ManagedStartupShortcut -ShortcutInfo $existingShortcut)) {
            throw "Startup item already exists and is not managed by WorkspaceManager: $startupShortcutPath"
        }
    }

    $shell = $null
    $shortcut = $null

    try {
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($startupShortcutPath)
        $shortcut.TargetPath = $startTrayLauncherPath
        $shortcut.WorkingDirectory = Split-Path -Parent $startTrayLauncherPath
        $shortcut.Description = $startupShortcutDescription
        $shortcut.Save()
    }
    finally {
        Release-WorkspaceComObject -ComObject $shortcut
        Release-WorkspaceComObject -ComObject $shell
    }

    if (-not (Test-StartWithWindows)) {
        throw "Startup shortcut could not be verified: $startupShortcutPath"
    }
}

function Disable-StartWithWindows {
    if ([string]::IsNullOrWhiteSpace($startupShortcutPath)) {
        throw 'Current user Startup folder could not be resolved.'
    }

    if (-not (Test-Path -LiteralPath $startupShortcutPath -PathType Leaf)) {
        return
    }

    $shortcutInfo = Get-StartupShortcutInfo

    if (-not (Test-ManagedStartupShortcut -ShortcutInfo $shortcutInfo)) {
        throw "Startup item is not managed by WorkspaceManager and was not removed: $startupShortcutPath"
    }

    Remove-Item -LiteralPath $startupShortcutPath -Force -ErrorAction Stop
}

function Show-WorkspaceNotification {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    try {
        if ($null -ne $notifyIcon) {
            $notifyIcon.BalloonTipTitle = 'WorkspaceManager'
            $notifyIcon.BalloonTipText = $Message
            $notifyIcon.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Info
            $notifyIcon.ShowBalloonTip(2000)
        }
    }
    catch {
    }
}

function Toggle-StartWithWindows {
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Forms.ToolStripMenuItem]$MenuItem
    )

    $wasEnabled = Test-StartWithWindows

    try {
        if ($wasEnabled) {
            Disable-StartWithWindows
            $MenuItem.Checked = $false
            Show-WorkspaceNotification -Message 'Start with Windows disabled.'
        }
        else {
            Enable-StartWithWindows
            $MenuItem.Checked = $true
            Show-WorkspaceNotification -Message 'Start with Windows enabled.'
        }
    }
    catch {
        $MenuItem.Checked = $wasEnabled
        Show-WorkspaceMessage -Message "Unable to update Start with Windows:`r`n$($_.Exception.Message)" -Icon Error
    }
}

$mutex = $null
$ownsMutex = $false
$notifyIcon = $null
$contextMenu = $null
$trayIcon = $null

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
    $startWithWindowsItem = New-Object System.Windows.Forms.ToolStripMenuItem 'Start with Windows'
    $exitItem = New-Object System.Windows.Forms.ToolStripMenuItem 'Exit'

    $startWithWindowsItem.CheckOnClick = $false
    $startWithWindowsItem.Checked = Test-StartWithWindows

    $switchToWindowsItem.Add_Click({ Start-VbsLauncher -Path $switchToWindowsPath })
    $switchToMacItem.Add_Click({ Start-VbsLauncher -Path $switchToMacPath })
    $healthCheckItem.Add_Click({ Invoke-WorkspaceHealthCheck })
    $openLogsItem.Add_Click({ Open-WorkspaceLog })
    $startWithWindowsItem.Add_Click({ Toggle-StartWithWindows -MenuItem $startWithWindowsItem })
    $exitItem.Add_Click({ [System.Windows.Forms.Application]::Exit() })

    [void]$contextMenu.Items.Add($switchToWindowsItem)
    [void]$contextMenu.Items.Add($switchToMacItem)
    [void]$contextMenu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    [void]$contextMenu.Items.Add($healthCheckItem)
    [void]$contextMenu.Items.Add($openLogsItem)
    [void]$contextMenu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    [void]$contextMenu.Items.Add($startWithWindowsItem)
    [void]$contextMenu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    [void]$contextMenu.Items.Add($exitItem)

    $trayIcon = Get-WorkspaceTrayIcon
    $notifyIcon = New-Object System.Windows.Forms.NotifyIcon
    $notifyIcon.Icon = $trayIcon
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

    if ($null -ne $trayIcon) {
        $trayIcon.Dispose()
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
