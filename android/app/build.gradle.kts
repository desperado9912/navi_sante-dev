plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.navi_sante"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.navi_sante"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Google Sign-In — keep in sync with .env (GOOGLE_WEB_CLIENT_ID, iOS REVERSED_CLIENT_ID)
        val googleWebClientId =
            "692742796179-t1jpnngktg3klip41u6q8i8sl6p8ajon.apps.googleusercontent.com"
        val googleRedirectScheme =
            "com.googleusercontent.apps.692742796179-le2hgmlo6nrctn46ruhur4mbgrjt16fr"

        resValue("string", "default_web_client_id", googleWebClientId)
        manifestPlaceholders["googleRedirectScheme"] = googleRedirectScheme
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
