@echo off
REM ============================================================================
REM  BUILD_APK_FOR_INVESTORS.bat
REM  Builds ONE small release APK of the GoOuts consumer app, to attach
REM  directly to an email — not a Play Store build, just something an
REM  investor can install on an Android phone and try.
REM
REM  ── WHY IT'S SMALL ──────────────────────────────────────────────────────
REM  A normal release APK bundles native code for THREE processor types
REM  (arm64, arm32, x86_64) even though one phone only ever needs one. This
REM  builds arm64 only — that's virtually every Android phone sold since
REM  ~2019 — so the file is roughly a third the size of the full build.
REM
REM  ── SIGNING ──────────────────────────────────────────────────────────────
REM  Signed with the Flutter debug key (see android/app/build.gradle.kts —
REM  no release keystore has been set up for this app yet). That's fine for
REM  a phone install from an email attachment; it would need a real release
REM  key before this ever went to the Play Store.
REM ============================================================================

cd /d "%~dp0"

echo.
echo ============================================================
echo   GoOuts (Consumer) - Build investor APK
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
echo --- building release APK (arm64 only, reduced size) ---
REM  ORG_GRADLE_PROJECT_arm64Only is how Gradle receives this — see the
REM  matching check in android/app/build.gradle.kts. Only set for THIS
REM  script; BUILD_AAB_FOR_PLAYSTORE.bat does not set it, so the real Play
REM  Store bundle keeps every CPU architecture.
set ORG_GRADLE_PROJECT_arm64Only=true
call flutter build apk --release --target-platform android-arm64
if errorlevel 1 goto :fail

echo.
echo ============================================================
echo   DONE
echo ============================================================
echo.
echo   APK file:
echo   %cd%\build\app\outputs\flutter-apk\app-release.apk
echo.
echo   That's the file to attach to the investor email.
echo   Most inboxes cap attachments around 20-25MB — if it's
echo   bigger than that, upload it to Google Drive / WeTransfer
echo   and send the link instead.
echo.
echo   The recipient's phone will need "Install unknown apps"
echo   allowed for their email app (Android will prompt for this
echo   automatically the first time they tap the file).
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
