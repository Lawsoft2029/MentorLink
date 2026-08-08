plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // ... other plugins
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.mentorlinks_app_project"
    compileSdk = 36 // Set to 36 to satisfy AndroidX browser and core library requirements
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
        minSdk = flutter.minSdkVersion 
        targetSdk = 36 // Updated to match compileSdk
        
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