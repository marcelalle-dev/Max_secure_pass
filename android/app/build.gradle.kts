import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Signature de publication (clé d'importation Google Play), lue dans
// android/key.properties. Ce fichier contient des secrets : il est exclu de Git.
// Modèle : android/key.properties.example.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseKey = keystorePropertiesFile.exists()
if (hasReleaseKey) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
    val missing =
        listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
            .filter { keystoreProperties.getProperty(it).isNullOrBlank() }
    if (missing.isNotEmpty()) {
        throw GradleException("android/key.properties : valeur(s) manquante(s) : ${missing.joinToString()}")
    }
}

android {
    namespace = "dev.marcelalle.maxsecurepass"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.marcelalle.maxsecurepass"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // flutter_secure_storage (déverrouillage par empreinte) exige Android 7.
        minSdk = maxOf(24, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseKey) {
                signingConfig = signingConfigs.getByName("release")
            }
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

// Sans clé de publication, une compilation release s'arrête : Google Play
// refuse les bundles signés avec la clé de debug ou non signés.
gradle.taskGraph.whenReady {
    val releaseTask =
        allTasks.any { task ->
            task.project == project &&
                task.name.contains("Release") &&
                listOf("bundle", "assemble", "package").any { task.name.startsWith(it) }
        }
    if (releaseTask && !hasReleaseKey) {
        throw GradleException(
            "Signature de publication absente : créez android/key.properties " +
                "(modèle : android/key.properties.example).",
        )
    }
}

dependencies {
    // Thème AppCompat requis par la boîte de dialogue d'empreinte (BiometricPrompt).
    implementation("androidx.appcompat:appcompat:1.7.1")
}
