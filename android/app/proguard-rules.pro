# คงไว้ซึ่งคลาสทั้งหมดที่เกี่ยวข้องกับ TensorFlow Lite
-keep class org.tensorflow.** { *; }
-keep class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.lite.gpu.** { *; }
-keep class org.tensorflow.lite.nnapi.** { *; }
-keep class org.tensorflow.lite.support.** { *; }

# คงไว้ซึ่งคลาสที่เกี่ยวข้องกับ Play Core
-keep class com.google.android.play.core.** { *; }
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }

# คงไว้ซึ่งคลาส Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.engine.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }

# ป้องกันการลบคลาสที่มี native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# คงไว้ซึ่ง annotations และข้อมูลที่สำคัญ
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes SourceFile,LineNumberTable
-keepattributes RuntimeVisibleAnnotations
-keepattributes RuntimeInvisibleAnnotations
-keepattributes InnerClasses
-keepattributes Exceptions

# คงไว้ซึ่งคลาสอื่นๆ ที่อาจจำเป็น
-dontwarn kotlinx.**
-dontwarn javax.annotation.**
-dontwarn org.checkerframework.**
-dontwarn org.ow2.asm.**
-dontwarn org.tensorflow.lite.task.gms.vision.**
-dontwarn org.tensorflow.lite.task.gms.**