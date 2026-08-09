Option Explicit

Dim fileSystem, shell, launcherDir, scriptsDir, rootDir, scriptPath, command

Set fileSystem = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")

launcherDir = fileSystem.GetParentFolderName(WScript.ScriptFullName)
scriptsDir = fileSystem.GetParentFolderName(launcherDir)
rootDir = fileSystem.GetParentFolderName(scriptsDir)
scriptPath = fileSystem.BuildPath(rootDir, "scripts\windows\switch-to-windows-remote.ps1")

If Not fileSystem.FileExists(scriptPath) Then
    MsgBox "PowerShell script not found: " & scriptPath, vbCritical, "WorkspaceManager"
    WScript.Quit 1
End If

command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & scriptPath & """"
shell.Run command, 0, False
