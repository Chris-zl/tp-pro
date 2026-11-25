plugins {
    id("com.android.application")
<<<<<<< HEAD
=======
    id("kotlin-android")
>>>>>>> 71821f7 (Mise à jour finale TP Flutter Zawadi Christelle)
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
<<<<<<< HEAD
    namespace = "com.example.zawadi_lufungulo"
=======
    namespace = "com.example.christelle_cv_flutter"
>>>>>>> 71821f7 (Mise à jour finale TP Flutter Zawadi Christelle)
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
<<<<<<< HEAD
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
=======
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
>>>>>>> 71821f7 (Mise à jour finale TP Flutter Zawadi Christelle)
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
<<<<<<< HEAD
        applicationId = "com.example.zawadi_lufungulo"
=======
        applicationId = "com.example.christelle_cv_flutter"
>>>>>>> 71821f7 (Mise à jour finale TP Flutter Zawadi Christelle)
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
<<<<<<< HEAD
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
=======
>>>>>>> 71821f7 (Mise à jour finale TP Flutter Zawadi Christelle)
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

<<<<<<< HEAD
kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

=======
>>>>>>> 71821f7 (Mise à jour finale TP Flutter Zawadi Christelle)
flutter {
    source = "../.."
}
