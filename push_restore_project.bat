@echo off
echo === Restoring full Flutter project source to git ===
cd /d C:\Users\Maz\goouts_app

echo Cleaning up lock files...
del /f .git\index.lock 2>nul
del /f .git\index_backup 2>nul

echo Deleting corrupt git index...
del /f .git\index 2>nul

echo Staging all project files...
git add -A

echo Committing...
git commit -m "Restore full Flutter project source (pubspec, lib, ios, android, assets)"

echo Pushing to GitHub...
git push

echo.
echo === Done! Now restart the Codemagic build ===
pause
