# --- Flutter ---------------------------------------------------------------
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }

# --- flutter_local_notifications -------------------------------------------
# The plugin (de)serializes scheduled notifications with Gson; without these
# keeps, R8 strips the generic TypeToken info and scheduled notifications
# throw at runtime.
-keep class com.dexterous.** { *; }
-keep class com.google.gson.** { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn com.dexterous.**

# --- Firebase --------------------------------------------------------------
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# --- RevenueCat (purchases_flutter) ----------------------------------------
-keep class com.revenuecat.purchases.** { *; }
-dontwarn com.revenuecat.purchases.**

# --- Google Play Core (deferred components / Play Store split) --------------
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Keep annotations and generic signatures used across the app.
-keepattributes InnerClasses,EnclosingMethod
