Option Explicit

Dim fileSystem, shell, launcherDir, scriptsDir, rootDir
Dim healthScriptPath, scriptPath, healthCommand, command, healthExitCode

Set fileSystem = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")

launcherDir = fileSystem.GetParentFolderName(WScript.ScriptFullName)
scriptsDir = fileSystem.GetParentFolderName(launcherDir)
rootDir = fileSystem.GetParentFolderName(scriptsDir)
healthScriptPath = fileSystem.BuildPath(rootDir, "scripts\health\check-workspace-health.ps1")
scriptPath = fileSystem.BuildPath(rootDir, "scripts\windows\switch-to-mac.ps1")

If Not fileSystem.FileExists(healthScriptPath) Then
    MsgBox "Health check script not found: " & healthScriptPath, vbCritical, "WorkspaceManager"
    WScript.Quit 1
End If

If Not fileSystem.FileExists(scriptPath) Then
    MsgBox "PowerShell script not found: " & scriptPath, vbCritical, "WorkspaceManager"
    WScript.Quit 1
End If

healthCommand = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & healthScriptPath & """"
healthExitCode = shell.Run(healthCommand, 0, True)

If healthExitCode <> 0 Then
    MsgBox "Workspace health check failed (exit code " & healthExitCode & ")." & vbCrLf & _
        "Run the health check manually for details:" & vbCrLf & healthScriptPath, _
        vbCritical, "WorkspaceManager"
    WScript.Quit healthExitCode
End If

command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & scriptPath & """"
shell.Run command, 0, False
