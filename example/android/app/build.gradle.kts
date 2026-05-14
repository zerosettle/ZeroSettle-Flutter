import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Optional release-signing credentials. Same pattern as the
// ZeroSettle-Android sample app. Generate a keystore via Android
// Studio (Build → Generate Signed App Bundle → Create new keystore)
// and either let it write key.properties next to this file, OR
// create example/android/keystore.properties manually with:
//     storeFile=upload-keystore.jks
//     storePassword=...
//     keyAlias=upload
//     keyPassword=...
// Without the file, release builds fall back to debug signing so
// `flutter run --release` keeps working.
val keystorePropsFile = rootProject.file("keystore.properties")
val keystoreProps = Properties().apply {
    if (keystorePropsFile.exists()) {
        keystorePropsFile.inputStream().use { load(it) }
    }
}

android {
    namespace = "io.zerosettle.zsstorefront"
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
        applicationId = "io.zerosettle.zsstorefront"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystoreProps.isNotEmpty()) {
            create("release") {
                storeFile = file(keystoreProps["storeFile"] as String)
                storePassword = keystoreProps["storePassword"] as String
                keyAlias = keystoreProps["keyAlias"] as String
                keyPassword = keystoreProps["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Use the release keystore if keystore.properties is present
            // (Play Console upload path); otherwise debug-sign so
            // `flutter run --release` keeps working out of the box.
            signingConfig = if (keystoreProps.isNotEmpty())
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Google Play Billing — needed so manifest merging picks up the
    // com.android.vending.BILLING permission required for Play Console
    // to enable IAP product configuration. The Flutter plugin's
    // :zerosettle module also pulls this in transitively via the
    // io.zerosettle:zerosettle-android SDK; the explicit declaration
    // here documents intent and keeps the example app self-describing.
    implementation("com.android.billingclient:billing-ktx:7.1.1")
}
