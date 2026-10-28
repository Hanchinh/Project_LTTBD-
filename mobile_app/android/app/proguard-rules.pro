# Flutter rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Sqflite plugin
-keep class com.tekartik.sqflite.** { *; }

# Mobile scanner & ML Kit
-keep class com.google.mlkit.** { *; }
-keep class androidx.camera.** { *; }

# General JNI, Reflection & Model preservation
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

