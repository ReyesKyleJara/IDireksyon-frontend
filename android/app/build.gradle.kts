import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val mapDefines = (project.findProperty("dart-defines") as String? ?: "")
    .split(",").filter { it.isNotBlank() }
    .map { String(Base64.getDecoder().decode(it)).split("=", limit = 2) }
    .filter { it.size == 2 }.associate { it[0] to it[1] }

// Without this a release build would succeed and ship a blank map.
val requireAndroidMapsKey = tasks.register("requireAndroidMapsKey") {
    val keyIsSet = !mapDefines["GOOGLE_MAPS_ANDROID_API_KEY"].isNullOrBlank()
    doLast {
        if (!keyIsSet) {
            throw GradleException(
                "GOOGLE_MAPS_ANDROID_API_KEY is missing or blank. Release builds need " +
                    "--dart-define=GOOGLE_MAPS_ANDROID_API_KEY=YOUR_ANDROID_KEY",
            )
        }
    }
}
tasks.matching { it.name == "preReleaseBuild" }.configureEach { dependsOn(requireAndroidMapsKey) }

// Git-ignored; release builds fail without it rather than using the debug key.
val keystoreProperties = Properties().apply {
    rootProject.file("key.properties").takeIf { it.exists() }?.inputStream()?.use { load(it) }
}

android {
    namespace = "com.IDireksyon.myapp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.IDireksyon.myapp"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(flutter.minSdkVersion, 24)
        manifestPlaceholders["googleMapsApiKey"] = mapDefines["GOOGLE_MAPS_ANDROID_API_KEY"] ?: mapDefines["GOOGLE_MAPS_API_KEY"] ?: ""
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
