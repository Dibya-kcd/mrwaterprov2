plugins {
    id("com.android.application")
    id("kotlin-android")
    // id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.mrwater.mrwaterprov1"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        create("release") {
            storeFile = file("mrwater-release.jks")
            storePassword = System.getenv("KEYSTORE_STORE_PASSWORD") ?: "android"
            keyAlias = System.getenv("KEYSTORE_KEY_ALIAS") ?: "androiddebugkey"
            keyPassword = System.getenv("KEYSTORE_KEY_PASSWORD") ?: "android"
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.mrwater.mrwaterprov1"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false  // Disable minification to resolve ML Kit R8 conflicts
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}
