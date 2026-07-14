@echo off
cd /d "%~dp0"
del .git\index.lock 2>nul
git config user.email "mianamir74@gmail.com"
git config user.name "Maz"
git add lib/services/auth_service.dart ios/Runner/AppDelegate.swift
git commit -m "Fix iOS crash: wrap verifyPhoneNumber with try/catch, fix AppDelegate plugin registration"
git push
echo.
echo Done! Check above for any errors.
pause
