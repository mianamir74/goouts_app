@echo off
cd /d "%~dp0"
echo Working in: %CD%

del /F /Q ".git\index.lock" 2>NUL

git config user.email "mianamir74@gmail.com"
git config user.name "Maz"

git add "lib/widgets/pre_auth_support_sheet.dart"

git commit -m "Fix missing GoOutsSheet import in pre_auth_support_sheet.dart"

git push

echo.
echo === Import fix pushed! Trigger Codemagic build. ===
echo.
pause
