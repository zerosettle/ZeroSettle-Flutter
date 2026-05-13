pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

// Local-dev composite-build substitution for the ZeroSettle-Android SDK.
// Set `zerosettle.androidSdkPath` in local.properties (gitignored) to point at
// your local ZeroSettle-Android checkout. When set, Gradle substitutes the
// Maven coords with the local in-tree :core and :ui projects; when unset, the
// plugin resolves against Maven Central as normal. No file changes to revert
// at release time — clean local-dev story.
val zsLocalSdkPath: String? = run {
    val properties = java.util.Properties()
    val f = file("local.properties")
    if (f.exists()) f.inputStream().use { properties.load(it) }
    properties.getProperty("zerosettle.androidSdkPath")
}

if (zsLocalSdkPath != null) {
    includeBuild(zsLocalSdkPath) {
        dependencySubstitution {
            substitute(module("io.zerosettle:zerosettle-android"))
                .using(project(":core"))
            substitute(module("io.zerosettle:zerosettle-android-ui"))
                .using(project(":ui"))
        }
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")
