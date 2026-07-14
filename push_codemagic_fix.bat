@echo off
echo === Fixing codemagic.yaml build directory issue ===
cd /d C:\Users\Maz\goouts_app
del /f .git\index.lock 2>nul
del /f .git\index_backup 2>nul
git add codemagic.yaml
git commit -m "Fix codemagic.yaml: add cd $CM_BUILD_DIR to flutter/pod scripts"
git push
echo === Done! Restart the Codemagic build now ===
pause
