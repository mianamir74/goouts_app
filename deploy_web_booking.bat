@echo off
setlocal enabledelayedexpansion
title GoOuts Web (Short Stay + Food Ordering) - Firebase Deploy
color 0A
cd /d "%~dp0"

REM ============================================================================
REM  WHAT THIS SCRIPT DOES
REM
REM  Builds this SAME app (goouts_app) for a web browser and publishes it to
REM  Firebase Hosting as a new site, goouts-book. This is not a second
REM  codebase - it is the phone app compiled for the web, so booking/ordering
REM  logic never has to be built twice.
REM
REM  On the web, main.dart sends visitors straight into Short Stay browsing
REM  (no phone-style onboarding wall). Booking still requires signing in -
REM  that gate is on the checkout screen, not on browsing.
REM
REM  NO REAL PAYMENT IS TAKEN by this build, same as the phone app today.
REM  A booking/order goes through as pending. See
REM  lib/features/short_stay/services/stay_booking_service.dart's own note
REM  on this if that ever changes.
REM
REM  Every external command below uses CALL. On Windows, flutter and firebase
REM  are both .bat/.cmd files - without CALL, control never returns to this
REM  script after the first one runs, and everything after it is silently
REM  skipped. See goouts_website\deploy_website.bat for the same lesson
REM  learned there on 30 July 2026.
REM ============================================================================

echo.
echo =====================================================
echo   GoOuts Web (Short Stay + Food Ordering)
echo   Site:    goouts-book
echo   Project: goouts-f16db
echo =====================================================
echo.

REM ---- Step 0: sanity check the files being shipped --------------------------
echo [0/5] Checking the files...

if not exist "lib\main.dart" (
  color 0C
  echo   ERROR: lib\main.dart not found. Are you in the right folder?
  goto :done
)
echo   OK
echo.

REM ---- Step 1: Flutter CLI ----------------------------------------------------
echo [1/5] Checking Flutter CLI...
call flutter --version >nul 2>&1
if errorlevel 1 (
  color 0C
  echo.
  echo   ERROR: Flutter CLI not found on this machine.
  echo   Install it from https://flutter.dev/docs/get-started/install
  echo.
  goto :done
)
echo   OK
echo.

REM ---- Step 2: get packages + build for web -----------------------------------
echo [2/5] Getting packages...
call flutter pub get
if errorlevel 1 (
  color 0C
  echo   ERROR: flutter pub get failed. See errors above.
  goto :done
)
echo.

echo [3/5] Building for web (this can take a few minutes)...
call flutter build web --release
if errorlevel 1 (
  color 0C
  echo.
  echo   ERROR: flutter build web failed. See errors above.
  echo   Common cause: a plugin with no web support was called somewhere
  echo   that runs even on web - the build error will name the file.
  goto :done
)
echo   OK, build\web is ready
echo.

REM ---- Step 4: Firebase CLI + login -------------------------------------------
echo [4/5] Checking Firebase CLI and login...
call firebase --version >nul 2>&1
if errorlevel 1 (
  color 0C
  echo.
  echo   ERROR: Firebase CLI not found.
  echo   Install it with:  npm install -g firebase-tools
  echo.
  goto :done
)

call firebase login:list 2>nul | findstr "@" >nul
if errorlevel 1 (
  echo   Not logged in. Opening a browser to sign in...
  call firebase login
  if errorlevel 1 (
    color 0C
    echo   ERROR: Login failed.
    goto :done
  )
) else (
  echo   Logged in
)
echo.

REM ---- First-time only: create the hosting site if it does not exist yet -----
REM  FIXED 9 September 2026: this used to run every time with no
REM  --non-interactive flag. The goouts-book site already existed after the
REM  first successful deploy, and firebase-tools asks a confirmation
REM  question when you try to create a site that is already there. That
REM  question was invisible (piped to nul) but the command was still
REM  sitting there waiting for a keypress that could never arrive, so the
REM  whole script looked frozen at "Logged in" forever. --non-interactive
REM  makes the CLI fail past any prompt instead of waiting on one, and the
REM  result is still ignored either way since this line only matters the
REM  very first time this script ever runs.
call firebase hosting:sites:create goouts-book --project goouts-f16db --non-interactive >nul 2>&1

REM ---- Step 5: deploy -----------------------------------------------------
echo [5/5] Deploying to Firebase Hosting...
echo.

call firebase deploy --only hosting --project goouts-f16db
set DEPLOY_RESULT=%ERRORLEVEL%

echo.
if "%DEPLOY_RESULT%"=="0" (
  color 0A
  echo =====================================================
  echo   DEPLOYED
  echo.
  echo   Live: https://goouts-book.web.app
  echo =====================================================
  echo.
  echo   Check before telling anyone about this:
  echo.
  echo     1. Open the link above in a normal browser window and
  echo        make sure Short Stay search actually loads. If it
  echo        shows a blank white screen, open the browser's
  echo        console (F12) and read the error - that is almost
  echo        always a plugin with no web support being called.
  echo.
  echo     2. Try booking a stay all the way through as a NEW
  echo        (signed-out) visitor. It should let you browse
  echo        freely and only ask you to sign in at checkout.
  echo.
  echo     3. Phone sign-in on web shows a reCAPTCHA the phone
  echo        app never shows. That is normal for Firebase Phone
  echo        Auth on web, not a bug - just confirm the code
  echo        still arrives and signs you in.
  echo.
  echo     4. No custom domain is attached yet - this is only
  echo        reachable at the goouts-book.web.app address above
  echo        until one is set up in Firebase Hosting.
) else (
  color 0C
  echo =====================================================
  echo   DEPLOY FAILED, error code %DEPLOY_RESULT%
  echo.
  echo   Nothing was published. The live site is unchanged.
  echo =====================================================
)

:done
echo.
echo   Press any key to close.
pause >nul
