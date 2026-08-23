Option Explicit

Dim fileSystem, shell, launcherDir, scriptsDir
Dim trayScriptPath, powerShellPath, command

Set fileSystem = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")

launcherDir = fileSystem.GetParentFolderName(WScript.ScriptFullName)
scriptsDir = fileSystem.GetParentFolderName(launcherDir)
trayScriptPath = fileSystem.BuildPath(scriptsDir, "tray\workspace-manager-tray.ps1")
powerShellPath = shell.ExpandEnvironmentStrings("%WINDIR%\System32\WindowsPowerShell\v1.0\powershell.exe")

If Not fileSystem.FileExists(trayScriptPath) Then
    MsgBox "Tray script not found: " & trayScriptPath, vbCritical, "WorkspaceManager"
    WScript.Quit 1
End If

If Not fileSystem.FileExists(powerShellPath) Then
    MsgBox "Windows PowerShell not found: " & powerShellPath, vbCritical, "WorkspaceManager"
    WScript.Quit 1
End If

command = """" & powerShellPath & """ -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Sta -File """ & trayScriptPath & """"
shell.Run command, 0, False
