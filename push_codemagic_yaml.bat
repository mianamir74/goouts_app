@echo off
echo === Pushing codemagic.yaml to GitHub ===
cd /d C:\Users\Maz\goouts_app
del /f .git\index.lock 2>nul
git add codemagic.yaml
git commit -m "Add codemagic.yaml workflow config"
git push
echo === Done! Now refresh Codemagic and the workflow should appear ===
pause
