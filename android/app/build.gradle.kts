plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.bizora.app"
    compileSdk = 36  // 👈 Set explicit version instead of flutter.compileSdkVersion
    
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.bizora.app"
        minSdk = flutter.minSdkVersion  // 👈 IMPORTANT: Set explicit minSdk to 23 for phone auth
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
    
    // 👈 ADD THIS for Play Integrity
    buildFeatures {
        buildConfig = true
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Firebase BOM
    implementation(platform("com.google.firebase:firebase-bom:32.8.0"))  // 👈 Updated to latest
    
    // Firebase Auth
    implementation("com.google.firebase:firebase-auth")
    
    // 👈 ADD THESE for Play Integrity and SMS Retriever
    implementation("com.google.android.gms:play-services-auth:20.7.0")
    implementation("com.google.android.gms:play-services-base:18.3.0")
    implementation("com.google.android.gms:play-services-safetynet:18.0.1")
    
    // 👈 ADD THIS for better compatibility
    implementation("androidx.browser:browser:1.7.0")
}
