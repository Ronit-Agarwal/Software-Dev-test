# SignSync - ProGuard/R8 rules
#
# Flutter itself adds baseline keep rules via the Gradle plugin.
# This file focuses on common SDKs used by SignSync.

# --- Flutter / embedding ---
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# --- Firebase / Google Play services ---
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# --- Sentry ---
-keep class io.sentry.** { *; }
-dontwarn io.sentry.**

# --- TensorFlow Lite ---
-keep class org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.lite.**

# --- Google ML Kit ---
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# --- Kotlin metadata (safe defaults) ---
-keep class kotlin.Metadata { *; }

# If you see reflection-related crashes in release, add targeted -keep rules here.
