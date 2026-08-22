Option Explicit

Dim shell, fso, toolsRoot, launcher, serverRoot, command, result

If WScript.Arguments.Count <> 1 Then
    MsgBox "MilkyCraft server root was not supplied.", vbCritical, "MilkyCraft Vanilla+ Server"
    WScript.Quit 2
End If

Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
toolsRoot = fso.GetParentFolderName(WScript.ScriptFullName)
launcher = fso.BuildPath(toolsRoot, "Start-Server.ps1")
serverRoot = fso.GetAbsolutePathName(WScript.Arguments(0))

If Not fso.FileExists(launcher) Then
    MsgBox "The managed server launcher is missing:" & vbCrLf & launcher, vbCritical, "MilkyCraft Vanilla+ Server"
    WScript.Quit 3
End If

shell.CurrentDirectory = serverRoot
command = "powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File " & _
    QuoteArgument(launcher) & " -ServerRoot " & QuoteArgument(serverRoot) & " -ServerGui"

On Error Resume Next
result = shell.Run(command, 0, True)
If Err.Number <> 0 Then
    MsgBox "Windows could not start the MilkyCraft server launcher." & vbCrLf & Err.Description, vbCritical, "MilkyCraft Vanilla+ Server"
    WScript.Quit 4
End If
On Error GoTo 0

If result <> 0 Then
    MsgBox "The server did not start. It may already be running." & vbCrLf & _
        "Use SERVER STATUS.bat or VIEW LATEST LOG.bat for details.", vbExclamation, "MilkyCraft Vanilla+ Server"
End If

Function QuoteArgument(value)
    QuoteArgument = Chr(34) & Replace(CStr(value), Chr(34), Chr(34) & Chr(34)) & Chr(34)
End Function
