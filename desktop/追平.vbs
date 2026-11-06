' 启动追平（无控制台窗口）
Dim sh, fso, p
Set fso = CreateObject("Scripting.FileSystemObject")
Set sh = CreateObject("WScript.Shell")
p = fso.BuildPath(fso.GetParentFolderName(WScript.ScriptFullName), "zhuiping.ps1")
sh.Run "powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & p & """", 0, False
