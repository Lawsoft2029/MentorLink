plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.android.application")
    // ... other plugins
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.mentorlinks_app_project"
    compileSdk = 34 // Set to 34 for Android 14 compatibility
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.mentorlinks_app_project"
        
        // Agora requires a minimum SDK of at least 21
        minSdk = 21 
        targetSdk = 34 // Matches Android 14
        
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Agora often needs ProGuard to prevent code shrinking from breaking the SDK
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}