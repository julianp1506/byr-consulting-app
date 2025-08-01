// android/app/build.gradle.kts

import java.util.Properties
import java.io.FileInputStream

// 1) Carga segura de key.properties
val keystoreProperties = Properties().apply {
  rootProject.file("key.properties")
    .takeIf { it.exists() }
    ?.let { load(FileInputStream(it)) }
}

plugins {
  id("com.android.application")
  id("kotlin-android")
  id("dev.flutter.flutter-gradle-plugin")
  id("com.google.gms.google-services")
}

android {
  namespace = "com.byr.consulting"
  compileSdk = flutter.compileSdkVersion
  ndkVersion = "27.0.12077973"

  compileOptions {
    sourceCompatibility = JavaVersion.VERSION_11
    targetCompatibility = JavaVersion.VERSION_11
  }
  kotlinOptions {
    jvmTarget = "11"
  }

  defaultConfig {
    applicationId = "com.byr.consulting"
    minSdk = 23
    targetSdk = 34
    versionCode = 1
    versionName = "1.0"
  }

  signingConfigs {
  create("release") {
    // Alias de la clave
    keyAlias      = "byr_consulting"
    // Contraseña de la clave (igual que storePassword)
    keyPassword   = "JulianPrado2008"
    // Ruta al archivo .jks dentro de android/app
    storeFile     = file("my-release-key.jks")
    // Contraseña del almacén de claves
    storePassword = "JulianPrado2008"
  }
}

  buildTypes {
    getByName("debug") {
      signingConfig = signingConfigs.getByName("debug")
    }
    getByName("release") {
      // Importante: desactivar ambas para evitar el error de "shrink-resources"
      isMinifyEnabled   = false
      isShrinkResources = false

      proguardFiles(
        getDefaultProguardFile("proguard-android.txt"),
        "proguard-rules.pro"
      )
      signingConfig = signingConfigs.getByName("release")
    }
  }
}

flutter {
  source = "../.."
}
