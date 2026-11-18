# ==========================================
# ProGuard / R8 Rules for SwipeFlick Release
# ==========================================

# Flutter Wrapper & Engine
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Flutter Secure Storage (KeyStore & EncryptedSharedPreferences)
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn com.it_nomads.fluttersecurestorage.**
-keep class androidx.security.crypto.** { *; }
-dontwarn androidx.security.crypto.**

# Image Picker & Native Camera
-keep class io.flutter.plugins.imagepicker.** { *; }
-dontwarn io.flutter.plugins.imagepicker.**

# Shared Preferences
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-dontwarn io.flutter.plugins.sharedpreferences.**

# Kotlin Metadata & Reflection safety
-dontwarn java.lang.invoke.**
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
-keep class kotlin.Metadata { *; }

# OkHttp & Netty (si son invocados por plugins nativos)
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
