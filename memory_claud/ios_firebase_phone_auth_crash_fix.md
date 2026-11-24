# iOS Firebase Phone Auth — Crash Fix Knowledge Base
*Documented July 2026 — Applies to ALL GoOuts Flutter apps on iOS*

---

## The Problem
App crashes on iOS (TestFlight / App Store builds) with `EXC_BREAKPOINT / SIGTRAP`.
Crash type: Swift runtime `preconditionFailure` in Firebase's internal async code.
Stack signature: `libswift_Concurrency.dylib completeTaskWithClosure` → Runner binary offsets ~1.3MB → `_assertionFailure (libswiftCore)`

All frames appear under **Runner** (not separate Firebase frameworks) because Firebase iOS SDK 11.x is **statically linked** into the Runner binary.

---

## Root Cause Chain (3 crashes, 3 root causes)

### Crash Type A — Manual `setAPNSToken` crash (main thread, ~190s uptime)
**Stack:** `pushRegistry:didUpdatePushCredentials:forType:` → Firebase proxy → AppDelegate → `Auth.auth().setAPNSToken()` → `_assertionFailure`

**Cause:** Calling `Auth.auth().setAPNSToken(deviceToken, type: .unknown)` manually in `didRegisterForRemoteNotificationsWithDeviceToken`. Firebase proxy already handles this internally. The manual call fires `preconditionFailure` when called at a moment when there is no pending phone-verification callback in progress.

**Fix:** Remove the manual `Auth.auth().setAPNSToken()` call from AppDelegate. Let Firebase proxy handle it internally.

---

### Crash Type B — FCM init too early (async thread, 2s uptime)
**Stack:** `completeTaskWithClosure` → Runner offsets (1296205, 1364969, 1366372) → `_assertionFailure`

**Cause:** `DriverFcmService.initialize()` was called in `main()` before `runApp()`. Firebase's async Swift Task started before the Flutter UIWindow / UIWindowScene was active.

**Fix:** Move `DriverFcmService.initialize()` out of `main()`. Call it via `WidgetsBinding.instance.addPostFrameCallback()` in `AppLaunchCoordinator.initState()` so it runs after the first Flutter frame (UIWindow active).

---

### Crash Type C — `requestPermission()` double APNs registration (async thread, 7.3s uptime)
**Stack:** Same pattern as Type B — `completeTaskWithClosure` → Runner offsets shifted +356 bytes → `_assertionFailure`

**Cause:** THIS IS THE KEY ONE. `FirebaseMessaging.instance.requestPermission()` internally calls `UIApplication.registerForRemoteNotifications()`. If AppDelegate already called `registerForRemoteNotifications()` at startup, calling `requestPermission()` causes a **second APNs token registration**. Firebase's async Swift Task processing that second token fires `preconditionFailure`.

**Fix:** Do NOT call `requestPermission()` in `FcmService.initialize()`. Instead:
1. In `initialize()`: call `_messaging.getNotificationSettings()` only (reads status, no APNs side-effect)
2. Add a public `askPermission()` method
3. Call `askPermission()` from the home screen (post-login) via `addPostFrameCallback`

This exactly mirrors the pattern used by the working consumer app (goouts_app).

---

## Why Consumer App Works But Driver App Crashed

| | Consumer App (goouts_app) | Driver App (driver_app) before fix |
|---|---|---|
| `initialize()` calls `requestPermission()` | ❌ No — uses `getNotificationSettings()` | ✅ Yes — triggers 2nd APNs registration → crash |
| `requestPermission()` call location | Home screen post-login | Startup via `addPostFrameCallback` |
| Manual `setAPNSToken` in AppDelegate | ✅ Yes (works because only 1 APNs registration) | Removed (was crashing earlier) |

---

## Correct AppDelegate.swift Pattern

```swift
import Flutter
import UIKit
import FirebaseAuth

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    application.registerForRemoteNotifications()  // ← Required for silent push (Phone Auth)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // DO NOT call Auth.auth().setAPNSToken() here unless consumer app pattern confirmed safe
  override func application(_ application: UIApplication,
                             didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(_ application: UIApplication,
                             didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("⚠️ APNs registration FAILED: \(error.localizedDescription)")
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  override func application(_ application: UIApplication,
                             didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                             fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    if Auth.auth().canHandleNotification(userInfo) {
      completionHandler(.noData)
      return
    }
    super.application(application, didReceiveRemoteNotification: userInfo,
                      fetchCompletionHandler: completionHandler)
  }

  override func application(_ application: UIApplication,
                             open url: URL,
                             options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    if Auth.auth().canHandle(url) { return true }
    return super.application(application, open: url, options: options)
  }
}
```

## Correct FcmService.initialize() Pattern

```dart
Future<void> initialize() async {
  if (_initialized) return;
  _initialized = true;

  await _messaging.setAutoInitEnabled(true);

  // DO NOT call requestPermission() here.
  // requestPermission() internally calls UIApplication.registerForRemoteNotifications()
  // causing a SECOND APNs registration → Firebase async Swift crash.
  // Use getNotificationSettings() — reads status only, zero APNs side-effect.
  final NotificationSettings settings = await _messaging.getNotificationSettings();
  await _syncTokenForCurrentUser(notificationsEnabled: _isNotificationsEnabled(settings));

  // ... set up listeners ...
}

/// Call from home screen initState via addPostFrameCallback — AFTER login.
Future<void> askPermission() async {
  try {
    final NotificationSettings settings = await _requestPermission();
    await _syncTokenForCurrentUser(notificationsEnabled: _isNotificationsEnabled(settings));
  } catch (e) {
    debugPrint('FCM askPermission error: $e');
  }
}
```

## Home Screen initState Pattern

```dart
@override
void initState() {
  super.initState();
  _loadData();
  // Request notification permission AFTER login — not at app startup.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    FcmService.instance.askPermission();
  });
}
```

---

## Podfile Required Settings

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
      config.build_settings['SWIFT_VERSION'] = '5'  # Prevents Swift 6 strict-concurrency crashes
    end
  end
end
```

---

## main.dart Pattern

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
  FirebaseMessaging.onBackgroundMessage(backgroundHandler);  // ← Must be before runApp()
  // FCM full init is deferred to home screen initState via addPostFrameCallback
  runApp(const MyApp());
}
```

---

## Checklist for New iOS App (Phone Auth)

| # | Item | Notes |
|---|------|-------|
| 1 | Phone Auth enabled in Firebase Console | Firebase → Authentication → Sign-in method |
| 2 | `GoogleService-Info.plist` in bundle | Must include `CLIENT_ID` + `REVERSED_CLIENT_ID` |
| 3 | `CFBundleURLTypes` with REVERSED_CLIENT_ID | In `Info.plist` — for reCAPTCHA redirect |
| 4 | `UIBackgroundModes: remote-notification` | In `Info.plist` |
| 5 | Push Notifications capability in App ID | Apple Developer Portal → Identifiers |
| 6 | APNs key (.p8) uploaded to Firebase | Firebase → Project Settings → Cloud Messaging |
| 7 | `Runner.entitlements` with `aps-environment: production` | Linked in `project.pbxproj` for all 3 configs |
| 8 | `application.registerForRemoteNotifications()` in AppDelegate | Silent push for Phone Auth |
| 9 | `canHandleNotification()` + `canHandle(url)` in AppDelegate | Let Firebase handle Auth notifications |
| 10 | `SceneDelegate: FlutterSceneDelegate` | If using scene-based architecture |
| 11 | **NO `requestPermission()` in FcmService.initialize()** | Use `getNotificationSettings()` instead |
| 12 | `askPermission()` called from home screen post-login | Via `addPostFrameCallback` |
| 13 | `SWIFT_VERSION = '5'` in Podfile post_install | Prevents Swift 6 concurrency crashes |
| 14 | FCM `initialize()` deferred to post-first-frame | Not in `main()`, not before `runApp()` |

---

## GoOuts App IDs Reference

| App | Bundle ID | APNs Key | Firebase Project |
|-----|-----------|----------|-----------------|
| Consumer (goouts_app) | com.goouts.app | GooutsAPNS2 (NNY4277W4X) | goouts-f16db |
| Driver Lead (driver_app) | com.goouts.driverapp | GooutsAPNS3 (C46JNW62L2) | goouts-f16db |
| Food Driver (goouts_drapp) | com.goouts.driver | Need to confirm | goouts-f16db |

Team ID: 6B62Z4423C

---

## Known Good Behaviour

- **reCAPTCHA screen** appearing in TestFlight is NORMAL — Firebase falls back when APNs token not yet ready. Not a bug, do not suppress.
- In production App Store builds, APNs works reliably and reCAPTCHA rarely appears.

---

## Build 40–41 Crash (July 21, 2026)

**Symptom:** App crashes INSTANTLY on iOS when user enters mobile number and taps Continue on SignupScreen. Works fine on Android (shows reCAPTCHA → OTP screen successfully). iOS crashes every time at same point.

**Confirmed:** Android works = Flutter/Dart logic is correct. iOS-specific crash.

### Root Cause 1 — Fixed in Build 40
`FirebaseAppDelegateProxyEnabled` was MISSING from `Info.plist`.

When missing: Firebase method swizzling is ACTIVE. AppDelegate.swift ALSO manually handles APNs (`Auth.auth().setAPNSToken()`, `canHandleNotification()`). Double-handling → crash on first APNs interaction which happens immediately when `verifyPhoneNumber` is called (Firebase sends silent push).

**Fix:** Added to `ios/Runner/Info.plist`:
```xml
<key>FirebaseAppDelegateProxyEnabled</key>
<false/>
<key>GULAppDelegateProxyEnabled</key>
<false/>
```

### Root Cause 2 — Fixed in Build 41 (THREE CHANGES)

**Change A — SignupScreen missing AuthFlowGuard.start()**
`LoginScreen._handleContinue()` correctly calls `AuthFlowGuard.start()` before `sendOtp`. `SignupScreen` did not. Without it, when OTP verification completes and Firebase auth state fires `user != null`, `AppLaunchCoordinator`'s StreamBuilder swaps the root widget while `OtpVerificationScreen` simultaneously tries `pushAndRemoveUntil` → navigator context conflict on iOS.
- Import `auth_flow_guard.dart`
- Call `AuthFlowGuard.start()` before `sendOtp`
- Call `AuthFlowGuard.end()` in both `onAutoVerified` and `onError`

**Change B — SWIFT_VERSION = '5' in Podfile (NEW)**
Without a Podfile.lock, every Codemagic build picks the latest Firebase iOS SDK. Firebase SDK 11.x (which is statically linked into the Runner binary) uses Swift Concurrency internally. Without `SWIFT_VERSION = '5'`, Xcode compiles pods in Swift 6 strict-concurrency mode, which fires `preconditionFailure` in `libswift_Concurrency.dylib completeTaskWithClosure` — the exact crash signature seen in earlier builds. This is the most likely root cause of the instant crash on Continue.

**Change C — Removed proxy keys from Info.plist**
Build 40 added `FirebaseAppDelegateProxyEnabled = false` and `GULAppDelegateProxyEnabled = false`. These did NOT fix the crash (Build 40 still crashed) and are NOT present in the working consumer app. Removed to match the consumer app's exact iOS configuration.

*Last updated: July 21, 2026 — Build 41 combines all three fixes*

---

## ★ TRUE ROOT CAUSE FOUND (July 22, 2026 — after Build 502 still crashed)

**`GoogleService-Info.plist` was NEVER bundled into the iOS app.**

The file existed at `ios/Runner/GoogleService-Info.plist` on disk, but `project.pbxproj` had **ZERO references** to it (consumer app has 4). Xcode only packages files referenced in the project — so every driver_app IPA shipped WITHOUT the plist.

**Crash mechanism:** Tap Continue → `verifyPhoneNumber` → APNs token not instantly ready → Firebase falls back to reCAPTCHA web flow → native SDK needs CLIENT_ID (from the plist or FIROptions.clientID) to build/verify the callback URL scheme → finds nil → throws NSException → **instant crash (nanoseconds)**. Crash is native and pre-Crashlytics, so no crash reports appeared.

**Why Android worked:** no plist/URL-scheme requirement in Android's reCAPTCHA flow.
**Why consumer app worked:** its pbxproj bundles the plist (4 references).
**Why every previous fix failed:** they were all correct but irrelevant — the plist was still missing from the bundle.

**Fix (2 parts, both applied):**
1. `lib/firebase_options.dart` → added `iosClientId: '289872853637-hsn5qkb1g7fehvdelmc1rh18c847fame.apps.googleusercontent.com'` to ios FirebaseOptions.
2. `ios/Runner.xcodeproj/project.pbxproj` → added the 4 GoogleService-Info.plist references (PBXBuildFile, PBXFileReference, group children, Resources build phase) copied from the consumer app's pattern.

**CHECKLIST ADDITION: when adding GoogleService-Info.plist to any Flutter iOS app, it MUST be referenced in project.pbxproj (4 places) — dropping the file in the folder is NOT enough. Verify with: `grep -c GoogleService ios/Runner.xcodeproj/project.pbxproj` (must be ≥4).**
