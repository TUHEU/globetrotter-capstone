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

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // Épinglés à ce que maplibre_gl 0.27.0 supporte réellement (voir son
    // propre CHANGELOG : "Android Gradle Plugin updated to 8.13.2",
    // "Kotlin updated to 2.3.0") plutôt que 9.0.1 / 2.3.20 par défaut du
    // SDK Flutter récent. AGP 9 change la gestion de Kotlin ("built-in
    // Kotlin") et maplibre_gl n'a pas encore été mis à jour pour ça - avec
    // AGP 9.0.1, son propre build.gradle échoue sur "Could not find method
    // kotlin()" à la ligne 77, faute d'extension Kotlin disponible dans ce
    // module. Revenir à AGP < 9 remet le plugin dans la configuration où
    // il fonctionne réellement.
    id("com.android.application") version "8.13.2" apply false
    id("org.jetbrains.kotlin.android") version "2.3.0" apply false
}

include(":app")