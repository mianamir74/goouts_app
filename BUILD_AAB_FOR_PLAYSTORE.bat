@echo off
REM ============================================================================
REM  BUILD_AAB_FOR_PLAYSTORE.bat
REM  Builds the .aab (Android App Bundle) — the format Google Play actually
REM  wants, and has required for all new apps since 2021.
REM
REM  ── WHY THIS FILE EXISTS, SEPARATE FROM THE INVESTOR APK SCRIPT ────────────
REM
REM  BUILD_APK_FOR_INVESTORS.bat makes ONE fixed file for sideloading — it has
REM  to contain everything because there's no Play Store standing between it
REM  and the phone it lands on.
REM
REM  An .aab is different: you upload it once, and Google Play's Dynamic
REM  Delivery builds a SEPARATE minimal package for every device that installs
REM  — that phone's CPU architecture only, that phone's screen density only,
REM  that phone's language only. This is not a manual optimization, it's
REM  automatic and it's how Uber Eats, Deliveroo, and every major Play Store
REM  app actually ships. Industry average is 15% smaller than a universal APK,
REM  up to 50% with on-demand feature modules on top.
REM
REM  This is the real, permanent fix for "phones with no space" — not a
REM  single trimmed-down file, a different package built per phone.
REM ============================================================================

cd /d "%~dp0"

echo.
echo ============================================================
echo   GoOuts (Consumer) - Build Android App Bundle (Play Store)
echo ============================================================
echo.

echo --- cleaning old build output ---
call flutter clean
if errorlevel 1 goto :fail

echo.
echo --- getting packages ---
call flutter pub get
if errorlevel 1 goto :fail

echo.
echo --- building app bundle (all architectures - Play Store splits per device) ---
call flutter build appbundle --release
if errorlevel 1 goto :fail

echo.
echo ============================================================
echo   DONE
echo ============================================================
echo.
echo   Bundle file:
echo   %cd%\build\app\outputs\bundle\release\app-release.aab
echo.
echo   This is what gets UPLOADED to Google Play Console — it is
echo   not installable on a phone directly. Play Console will show
echo   you the actual per-device download size after upload, which
echo   will be well under this file's own size.
echo.
echo   ^>^> Still signed with the DEBUG key ^<^<
echo   Fine for the investor APK. NOT fine for a real Play Store
echo   submission — Google Play requires (and can manage for you,
echo   via Play App Signing) a real release key before this can go
echo   live. Ask Claude when you're ready to set that up.
echo.
pause
exit /b 0

:fail
echo.
echo ############################################################
echo #   BUILD FAILED — scroll up to see the error
echo ############################################################
echo.
pause
exit /b 1
