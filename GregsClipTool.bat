@Echo off
REM # Executes the PowerShell script that matches this batch file's name
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dpn0.ps1" -NoSeparateRunspace
@pause
