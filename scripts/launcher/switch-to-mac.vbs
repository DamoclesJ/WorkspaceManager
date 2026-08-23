Option Explicit

Dim fileSystem, shell, launcherDir, scriptsDir, rootDir
Dim healthScriptPath, scriptPath, healthCommand, command, healthExitCode
Dim logDirPath, logFilePath

Set fileSystem = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")

launcherDir = fileSystem.GetParentFolderName(WScript.ScriptFullName)
scriptsDir = fileSystem.GetParentFolderName(launcherDir)
rootDir = fileSystem.GetParentFolderName(scriptsDir)
healthScriptPath = fileSystem.BuildPath(rootDir, "scripts\health\check-workspace-health.ps1")
scriptPath = fileSystem.BuildPath(rootDir, "scripts\windows\switch-to-mac.ps1")
logDirPath = fileSystem.BuildPath(rootDir, "logs")
logFilePath = fileSystem.BuildPath(logDirPath, "workspace-switch.log")

WriteLog "INFO", "Mac", "Launcher started"

If Not fileSystem.FileExists(healthScriptPath) Then
    WriteLog "ERROR", "Mac", "Health check script not found: " & healthScriptPath
    MsgBox "Health check script not found: " & healthScriptPath, vbCritical, "WorkspaceManager"
    WScript.Quit 1
End If

If Not fileSystem.FileExists(scriptPath) Then
    WriteLog "ERROR", "Mac", "Switch script not found: " & scriptPath
    MsgBox "PowerShell script not found: " & scriptPath, vbCritical, "WorkspaceManager"
    WScript.Quit 1
End If

healthCommand = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & healthScriptPath & """"
healthExitCode = shell.Run(healthCommand, 0, True)

If healthExitCode <> 0 Then
    WriteLog "ERROR", "Mac", "Health check failed with exit code " & healthExitCode
    MsgBox "Workspace health check failed (exit code " & healthExitCode & ")." & vbCrLf & _
        "Run the health check manually for details:" & vbCrLf & healthScriptPath, _
        vbCritical, "WorkspaceManager"
    WScript.Quit healthExitCode
End If

WriteLog "INFO", "Mac", "Health check passed"
command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & scriptPath & """"
WriteLog "INFO", "Mac", "Switch script launch requested"
shell.Run command, 0, False

Function FormatLogTimestamp(value)
    FormatLogTimestamp = Year(value) & "-" & _
        Right("0" & Month(value), 2) & "-" & _
        Right("0" & Day(value), 2) & " " & _
        Right("0" & Hour(value), 2) & ":" & _
        Right("0" & Minute(value), 2) & ":" & _
        Right("0" & Second(value), 2)
End Function

Sub WriteLog(level, target, message)
    Dim logStream

    On Error Resume Next

    If Not fileSystem.FolderExists(logDirPath) Then
        fileSystem.CreateFolder(logDirPath)
    End If

    Set logStream = fileSystem.OpenTextFile(logFilePath, 8, True)

    If Err.Number = 0 Then
        logStream.WriteLine FormatLogTimestamp(Now) & " [" & level & "] [" & target & "] " & message
        logStream.Close
    End If

    Err.Clear
    On Error GoTo 0
End Sub
