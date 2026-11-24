@echo off
echo === Fix missing assets: pubspec + bonus_added_screen ===
cd /d C:\Users\Maz\goouts\goouts_app
del /f .git\index.lock 2>nul
del /f .git\index_backup 2>nul
git add pubspec.yaml
git add lib/screens/bonus_added_screen.dart
git commit -m "Fix missing assets: remove goouts_logo.png from pubspec, fix logo_white.webp -> .png"
git push
echo === Done! Restart Codemagic build ===
pause
