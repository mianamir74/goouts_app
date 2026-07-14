# Session July 12, 2026

## Main Goal
Fix all iOS build errors blocking TestFlight upload via Codemagic, and get first successful build into TestFlight.

---

## Fixes Applied — goouts_app (Consumer App)

### 1. food_menu_screen.dart — Dart Type Inference
- Added `<_MenuItem>` explicit generic to all 4 `expand()` calls:
  - Line 147: `cats.expand<_MenuItem>((c) => c.items)`
  - Line 157: `cats.expand<_MenuItem>((c) => c.items)`
  - Line 1014: `widget.categories.expand<_MenuItem>((c) => c.items)`
  - Line 1016: `widget.categories.expand<_MenuItem>((c) => c.items)`
- Dart was failing to infer `_MenuItem` type through the `expand→fold→sort` chain

### 2. contact_support_screen.dart — Apostrophe & Literal Newline Errors
- Fixed strings with apostrophes inside single-quoted strings:
  - `'driver's'` → `"driver's"`
  - `'we'll'` → `"we'll"`
- Fixed multi-line strings with literal embedded newlines → replaced with `\n`
- Affected lines 1244–1293 (Order Late, Wrong Items, Driver Issue, Cancelled, Refund sections)

### 3. biometric_service.dart — Already fixed (no options param)
- Was correctly fixed previously; re-confirmed on disk

### 4. .gitignore — Added functions/node_modules/
- Prevents hundreds of node_modules files from showing as modified

---

## Fixes Applied — driver_app

### 1. iOS Bundle ID Wrong
- `ios/Runner.xcodeproj/project.pbxproj`: `com.example.driverApp` → `com.goouts.driverapp`
- Fixed in all 3 build configs: Debug, Release, Profile

### 2. codemagic.yaml — Complete Rewrite
- Removed duplicate `goouts-driver-ios` workflow (belonged in goouts_drapp)
- Switched from `ios_signing` block to explicit code signing scripts
- Removed broken `--export-options-plist=/Users/builder/export_options.plist`
- Added `groups: - appstore_credentials` to environment

---

## Fixes Applied — goouts_drapp

### 1. codemagic.yaml — Complete Rewrite
- Removed duplicate `goouts-driver-ios` workflow (was listed TWICE)
- Switched to explicit code signing scripts
- Removed broken export options plist
- Added `appstore_credentials` group

---

## Codemagic Signing Pattern (All 3 Apps)
All codemagic.yaml files now use this explicit signing approach:
```yaml
- name: Set up keychain
  script: keychain initialize
- name: Fetch signing files
  script: |
    app-store-connect fetch-signing-files "$BUNDLE_ID" \
      --type IOS_APP_STORE \
      --create
- name: Add certs to keychain
  script: keychain add-certificates
- name: Set up Xcode code signing
  script: xcode-project use-profiles
- name: Build iOS release
  script: |
    flutter build ipa \
      --release \
      --build-number=$BUILD_NUMBER
```

---

## TestFlight — GoOuts Cashback App ✅ LIVE

### Build Status
- Build 1783833403 (v1.0.0) — **Ready to Submit** in TestFlight
- App Store Connect app ID: 6790064438
- Bundle ID: com.goouts.app
- Encryption compliance: None (selected)
- Added mianamir74@icloud.com as Internal Tester
- Waiting for TestFlight invite email to arrive

### App Store Connect Setup Done
- App created: GoOuts Cashback App (com.goouts.app)
- SKU: goouts-cashback-app
- What to Test: "all app to test to make sure all functions working perfectly."

---

## Apple Developer Portal — Bundle IDs Registered
- `com.goouts.app` ✅ (done previously)
- `com.goouts.driverapp` ✅ (done this session — GoOuts Driver Lead)
- `com.goouts.driver` ✅ (done this session — GoOuts Driver)
- Push Notifications enabled on both new IDs

---

## Pending for Next Session

### TestFlight — GoOuts Cashback App
- [ ] Check for TestFlight invite on iPhone (mianamir74@icloud.com)
- [ ] Create **Investors** group in TestFlight (must be named exactly "Investors")
- [ ] Fill in Test Information: Feedback Email + First Name, Last Name, Phone, Email
- [ ] Add investor emails to Investors group when ready

### App Store Connect — Still To Create
- [ ] Create app for **GoOuts Driver Lead** (com.goouts.driverapp) in App Store Connect
- [ ] Create app for **GoOuts Driver** (com.goouts.driver) in App Store Connect
  - Note: driver_app App Store name = "GoOuts Lead" or "GoOuts Driver Lead" (user preference TBC)

### Git — Commits Still Needed
- goouts_app: `git add lib/screens/food_menu_screen.dart lib/screens/contact_support_screen.dart lib/services/biometric_service.dart .gitignore` then commit + push
- driver_app: `git add ios/Runner.xcodeproj/project.pbxproj codemagic.yaml` then commit + push
- goouts_drapp: `git add codemagic.yaml` then commit + push
- Note: `del .git\index.lock` may be needed before commit if lock file exists

### Codemagic Builds — Still Needed
- [ ] Start new goouts_app build (after git push — will fix food_menu + contact_support errors)
- [ ] Start driver_app build (after App Store Connect app created for com.goouts.driverapp)
- [ ] Start goouts_drapp build (after App Store Connect app created for com.goouts.driver)

### Firebase Console — Still Needed
- [ ] Download GoogleService-Info.plist for all 3 iOS apps and place in ios/Runner/
- [ ] Enable Crashlytics in Firebase Console for all 3 apps

### Deployments — Still Needed
- [ ] Admin panel: `flutter build web --release && firebase deploy --only hosting`
- [ ] Cloud Functions: `firebase deploy --only functions` (fetchFoodImages)

---

## Bundle IDs Summary
| App | iOS Bundle ID | Android applicationId |
|-----|--------------|----------------------|
| goouts_app (Consumer) | com.goouts.app | com.goouts.app |
| driver_app (Driver Lead/Support) | com.goouts.driverapp | com.goouts.driver_app |
| goouts_drapp (Food Delivery Driver) | com.goouts.driver | com.goouts.driver |

## Key File Locations
- Consumer app: `C:\Users\Maz\goouts_app\`
- Driver Lead app: `C:\Users\Maz\goouts\driver_app\`
- Food Delivery Driver app: `C:\Users\Maz\goouts\goouts_drapp\`
- Admin panel: `C:\Users\Maz\goouts\admin_panel\`
- Memory files: `C:\Users\Maz\goouts_app\memory_claud\`
