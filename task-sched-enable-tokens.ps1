# 1. Define the action (What you want the SYSTEM account to do)
# Example: This copies an administrative output file to your user desktop 
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -WindowStyle Hidden -Command ""whoami /priv > C:\Users\Public\system_privs.txt"""

# 2. Assign the structural principal identity to "SYSTEM"
$Principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest

# 3. Register the task inside Windows
Register-ScheduledTask -TaskName "TempSystemBypass" -Action $Action -Principal $Principal -Force

# 4. Fire the task manually immediately
Start-ScheduledTask -TaskName "TempSystemBypass"

# 5. Give it 2 seconds to complete the thread execution, then wipe it clean
Start-Sleep -Seconds 2
Unregister-ScheduledTask -TaskName "TempSystemBypass" -Confirm:$false

Write-Host "Task executed and completely removed. Check C:\Users\Public\system_privs.txt to see the token power output!" -ForegroundColor Green
