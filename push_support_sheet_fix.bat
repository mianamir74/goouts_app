@echo off
cd /d "%~dp0"
echo Working in: %CD%

del /F /Q ".git\index.lock" 2>NUL

git config user.email "mianamir74@gmail.com"
git config user.name "Maz"

git add "lib/widgets/pre_auth_support_sheet.dart"

git commit -m "Fix pre_auth_support_sheet: replace snackbars with GoOutsSheet"

git push

echo.
echo === Support sheet fix pushed! ===
echo Trigger new Codemagic build at https://codemagic.io/apps
echo.
pause
