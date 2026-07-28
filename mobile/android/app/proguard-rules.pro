# ---------------------------------------------------------------------------
# Release shrinking rules.
#
# Flutter's own rules are applied automatically by the Gradle plugin. These
# cover the plugins in this app that resolve classes reflectively and would
# otherwise be stripped, failing only at runtime in the release build.
# ---------------------------------------------------------------------------

# --- Firebase / FCM -------------------------------------------------------
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# --- flutter_local_notifications -----------------------------------------
# Serialises scheduled notifications via Gson; the model classes and their
# generic signatures must survive.
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*

# --- local_auth (biometrics) ---------------------------------------------
-keep class androidx.biometric.** { *; }
-dontwarn androidx.biometric.**

# --- flutter_secure_storage ----------------------------------------------
-keep class androidx.security.crypto.** { *; }
-dontwarn androidx.security.crypto.**

# --- Keep line numbers so release crash reports stay readable -------------
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
