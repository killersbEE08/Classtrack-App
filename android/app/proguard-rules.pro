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

# --- WorkManager + Room ----------------------------------------------------
# home_widget pulls in androidx.work, whose WorkDatabase is a Room database
# instantiated by reflection at startup (via the WorkManagerInitializer
# ContentProvider). Without these keeps, R8 strips Room's generated *_Impl
# classes and the app crashes on launch with:
#   "Failed to create an instance of androidx.work.impl.WorkDatabase".
-keep class androidx.work.** { *; }
-keep class androidx.room.** { *; }
-keep class androidx.sqlite.** { *; }
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class * extends androidx.work.ListenableWorker { <init>(...); }
-keep class * extends androidx.work.Worker
-dontwarn androidx.work.**
-dontwarn androidx.room.**

# Keep annotations and generic signatures used across the app.
-keepattributes InnerClasses,EnclosingMethod
