@echo off
echo.
echo ========================================
echo  GoOuts — Deploy Referral Reward CF
echo ========================================
echo.

cd /d "%~dp0"

echo [1/3] Installing function dependencies...
cd functions
call npm install
if %errorlevel% neq 0 (
  echo ERROR: npm install failed.
  pause
  exit /b 1
)
cd ..

echo.
echo [2/3] Deploying processReferralReward to Firebase (europe-west1)...
call firebase deploy --only functions:processReferralReward --project goouts-f16db
if %errorlevel% neq 0 (
  echo ERROR: Firebase deploy failed.
  pause
  exit /b 1
)

echo.
echo [3/3] Done!
echo.
echo  processReferralReward is live.
echo  It will automatically credit £2 to referrers
echo  when their friend places their first order.
echo.
pause
