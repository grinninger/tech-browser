Option Explicit

Dim shell, files, basePath, quote, sevenZip, browser, arguments, item, exitCode, logPath
Set shell = CreateObject("WScript.Shell")
Set files = CreateObject("Scripting.FileSystemObject")

basePath = files.GetParentFolderName(WScript.ScriptFullName)
logPath = basePath & "\Tech-Browser-launcher.log"
quote = Chr(34)
sevenZip = quote & basePath & "\7za.exe" & quote
browser = quote & basePath & "\app\Tech Browser.exe" & quote

LogMessage "Launcher started; BasePath=" & basePath

If Not files.FileExists(basePath & "\app\Tech Browser.exe") Then
    LogMessage "Browser not extracted; starting 7-Zip"
    exitCode = shell.Run(sevenZip & " x " & quote & basePath & "\payload.7z" & quote & " -o" & quote & basePath & "\app" & quote & " -y", 0, True)
    LogMessage "7-Zip exit code=" & exitCode
    If exitCode <> 0 Then
        MsgBox "Tech Browser konnte nicht entpackt werden. Fehlercode: " & exitCode, vbCritical, "Tech Browser"
        WScript.Quit exitCode
    End If
End If

arguments = ""
For Each item In WScript.Arguments
    arguments = arguments & " " & quote & Replace(item, quote, quote & quote) & quote
Next

LogMessage "Starting browser; Command=" & browser & arguments
exitCode = shell.Run(browser & arguments, 1, True)
LogMessage "Browser exit code=" & exitCode
WScript.Quit exitCode

Sub LogMessage(message)
    Dim stream
    On Error Resume Next
    Set stream = files.OpenTextFile(logPath, 8, True)
    stream.WriteLine Now & "  " & message
    stream.Close
    On Error GoTo 0
End Sub
