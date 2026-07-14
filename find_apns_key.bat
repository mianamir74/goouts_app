@echo off
powershell.exe -ExecutionPolicy Bypass -Command ^
  "$found = Get-ChildItem -Path $env:USERPROFILE -Recurse -Filter 'AuthKey_CD2KNZ24U2.p8' -ErrorAction SilentlyContinue | Select-Object -First 1; " ^
  "if ($found) { Write-Host 'FOUND: ' + $found.FullName -ForegroundColor Green; [System.Windows.Forms.Clipboard]::SetText($found.FullName); Write-Host 'Path copied to clipboard!' } " ^
  "else { Write-Host 'Not found in home folder. Checking common locations...' -ForegroundColor Yellow; " ^
  "Get-ChildItem -Path 'C:\', 'D:\' -Recurse -Filter '*.p8' -ErrorAction SilentlyContinue | Select-Object FullName | Format-Table -AutoSize }"
pause
