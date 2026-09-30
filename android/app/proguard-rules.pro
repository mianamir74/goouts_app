# ─────────────────────────────────────────────────────────────────────────────
#  Added 4 September 2026 — first release-mode APK build failed R8 with
#  "Missing classes" for four ML Kit text recognizer language variants:
#
#    com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
#    com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
#    com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
#    com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
#
#  These are OPTIONAL companion packages of google_mlkit_text_recognition.
#  This app only depends on the base package (Latin-script recognition, used
#  for the KYC document scan) — the other four language packages were never
#  added as dependencies, so their classes genuinely do not exist in this
#  build. R8 still finds a reference to them (the plugin's Java code checks
#  for all five at runtime and calls whichever is present) and refuses to
#  proceed on an unresolved reference by default.
#
#  -dontwarn tells R8 that's expected and fine — the reference is inside a
#  runtime check the plugin already guards, not a real crash risk. This does
#  NOT disable minification for anything else in the app.
# ─────────────────────────────────────────────────────────────────────────────
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Keep the base (Latin) text recognizer and face detector this app actually
# uses for KYC — minification renaming/removing anything google_mlkit_* calls
# via reflection is the other common way this class of build breaks.
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.mlkit.vision.face.** { *; }
-keep class com.google_mlkit_text_recognition.** { *; }
-keep class com.google_mlkit_face_detection.** { *; }
-keep class com.google_mlkit_commons.** { *; }
