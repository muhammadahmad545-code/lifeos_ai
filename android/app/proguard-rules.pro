# flutter_local_notifications stores scheduled notifications with Gson; keep its model classes
# so reminders survive reboots in minified release builds.
-keep class com.dexterous.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn com.google.android.play.core.**
