plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

android {
    namespace = "com.goouts.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.goouts.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // ── 4 September 2026 — the actual fix for the 101MB investor APK ──────
        // `flutter build apk --target-platform android-arm64` only restricts
        // the Dart/Flutter engine to arm64. It does NOT restrict native .so
        // files bundled by plugin AARs — the ML Kit face/OCR/barcode models
        // still shipped all three ABIs (x86_64, armeabi-v7a, arm64-v8a) inside
        // the "arm64-only" build regardless, ~40MB of pure waste. This is the
        // setting that actually filters every native library in the APK, not
        // just the Dart one.
        //
        // ⚠ GATED, NOT ALWAYS ON. This build.gradle.kts is shared by the
        // investor sideload APK AND the real Play Store app bundle. Applying
        // this unconditionally would also lock the Play Store release to
        // arm64-only forever, silently dropping every 32-bit and x86 device —
        // exactly the kind of change that should be a deliberate choice, not
        // a side effect of a demo build. BUILD_APK_FOR_INVESTORS.bat sets the
        // ORG_GRADLE_PROJECT_arm64Only environment variable before calling
        // Gradle; BUILD_AAB_FOR_PLAYSTORE.bat does not, so the real bundle
        // ships all architectures and lets Play's Dynamic Delivery split per
        // device instead.
        if (project.hasProperty("arm64Only")) {
            ndk {
                abiFilters += listOf("arm64-v8a")
            }
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            // Flutter enables R8 minification by default for release builds.
            // Without proguard-rules.pro wired in, R8 has no keep/dontwarn
            // rules for the ML Kit text recognition plugin and fails the
            // build outright — see the file for what and why.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            isMinifyEnabled = true
            // Strips unused Android resources (layouts/drawables pulled in by
            // dependencies but never referenced) on top of R8's code shrinking.
            isShrinkResources = true
        }
    }
}

flutter {
    source = "../.."
}

// ── ML Kit: unbundled models, 4 September 2026 ─────────────────────────────
//
// google_mlkit_face_detection and google_mlkit_text_recognition each default
// to the BUNDLED native artifact — the recognition model shipped as a .so
// file and data files inside the APK itself, once per CPU architecture. That
// was ~30-40MB of the 101MB investor build. The API surface
// (com.google.mlkit.vision.face.*, com.google.mlkit.vision.text.*) is
// identical between bundled and unbundled, so the plugins' own Dart<->native
// bridge code works unchanged either way — only which artifact backs it
// changes.
//
// This excludes the bundled artifacts the plugins pull in transitively and
// adds the unbundled Play-Services equivalents explicitly. The model then
// downloads via Google Play Services — the AndroidManifest.xml
// com.google.mlkit.vision.DEPENDENCIES entry ("face,ocr") tells Play
// Services to fetch it automatically right after install, not on first use.
//
// Text recognition's Chinese/Japanese/Korean/Devanagari variants were never
// a dependency of this app (Latin-only, for the KYC document scan) — the
// -dontwarn rules in proguard-rules.pro already cover the plugin's defensive
// reference to them, unbundled or not.
//
// ⚠ CORRECTED 4 September 2026. This originally also excluded
// com.google.mlkit:barcode-scanning, reasoned as "nothing in lib/ calls a
// barcode scanner". That grep checked for the strings "barcode" and
// "BarcodeScanner" and missed it: `mobile_scanner` (used in
// partner_details_screen.dart, for scanning a partner's QR code in-store) is
// a REAL dependency and its native Kotlin code — MobileScanner.kt,
// MobileScannerHandler.kt — calls straight into
// com.google.mlkit.vision.barcode.* directly. Excluding the group didn't
// shrink an unused feature, it deleted classes a real feature's compiled
// code still referenced, and the very next build failed R8 with ~20 missing
// classes. libbarhopper_v3.so (~13.5MB across three architectures) stays —
// it is not dead weight, it is what QR redemption runs on. Left as the
// default artifact mobile_scanner declares rather than force-substituting
// the unbundled Play-Services one, since that hasn't been verified against
// this plugin's own code the way it has for face detection and text
// recognition above.
configurations.all {
    exclude(group = "com.google.mlkit", module = "face-detection")
    exclude(group = "com.google.mlkit", module = "text-recognition")
    exclude(group = "com.google.mlkit", module = "text-recognition-chinese")
    exclude(group = "com.google.mlkit", module = "text-recognition-devanagari")
    exclude(group = "com.google.mlkit", module = "text-recognition-japanese")
    exclude(group = "com.google.mlkit", module = "text-recognition-korean")
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:34.13.0"))
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
    implementation("com.google.firebase:firebase-storage")

    // Unbundled (Play-Services-downloaded) ML Kit models — see the note above.
    implementation("com.google.android.gms:play-services-mlkit-face-detection:17.1.0")
    implementation("com.google.android.gms:play-services-mlkit-text-recognition:19.0.1")
}