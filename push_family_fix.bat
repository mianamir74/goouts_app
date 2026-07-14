@echo off
cd /d "%~dp0"
echo Working in: %CD%

del /F /Q ".git\index.lock" 2>NUL

git config user.email "mianamir74@gmail.com"
git config user.name "Maz"

git add "lib/screens/family_plan_screen.dart"

git commit -m "Fix: restore Flutter imports in family_plan_screen.dart (iOS build fix)"

git push

echo.
echo === family_plan_screen fix pushed! ===
echo Trigger new Codemagic build at https://codemagic.io/apps
echo.
pause
