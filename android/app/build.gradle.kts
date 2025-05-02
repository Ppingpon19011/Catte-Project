plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // เปิดใช้งาน BuildConfig
    buildFeatures {
        buildConfig = true
    }
    
    namespace = "com.example.test"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_1_8.toString()
    }

    defaultConfig {
        applicationId = "com.example.test"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            // *ข้อสำคัญ*: ปิด minify เป็นการชั่วคราวเพื่อทดสอบการ build ให้สำเร็จก่อน
            // จากนั้นค่อยเปิดกลับมาเมื่อแก้ไข proguard-rules.pro เรียบร้อยแล้ว
            isMinifyEnabled = false 
            isShrinkResources = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
        
        debug {
            isDebuggable = true
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
    
    // สำหรับ TensorFlow Lite
    aaptOptions {
        noCompress.add("tflite")
    }
    
    // แก้ไขปัญหาไฟล์ซ้ำซ้อน
    packagingOptions {
        resources {
            excludes.add("META-INF/*")
            pickFirsts.add("lib/armeabi-v7a/libtensorflowlite_jni.so")
            pickFirsts.add("lib/arm64-v8a/libtensorflowlite_jni.so")
            pickFirsts.add("lib/x86/libtensorflowlite_jni.so")
            pickFirsts.add("lib/x86_64/libtensorflowlite_jni.so")
        }
    }
    
    // แก้ไขปัญหา lint
    lint {
        disable.add("InvalidPackage")
        checkReleaseBuilds = false
        abortOnError = false
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:1.2.2")
    
    // จำเป็นสำหรับ MultiDex
    implementation("androidx.multidex:multidex:2.0.1")
    
    // TensorFlow Lite - ใช้เวอร์ชันเก่าที่เสถียรกว่า
    implementation("org.tensorflow:tensorflow-lite:2.8.0")
    implementation("org.tensorflow:tensorflow-lite-gpu:2.8.0")
    
    // Play Core - เพิ่มเพื่อแก้ปัญหา Missing Classes
    implementation("com.google.android.play:core:1.10.3")
}

flutter {
    source = "../.."
}