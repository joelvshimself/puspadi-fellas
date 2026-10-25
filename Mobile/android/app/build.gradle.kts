import java.util.Properties
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
}

// Per-developer overrides live in Mobile/local.properties (gitignored), e.g.
//   rollspot.apiBaseUrl=http://10.0.2.2:8787      (local `npm run dev` from the emulator)
//   rollspot.googleWebClientId=....apps.googleusercontent.com
//   rollspot.firebase.apiKey / .appId / .projectId / .senderId   (push; see android/README.md)
//   rollspot.release.storeFile / .storePassword / .keyAlias / .keyPassword  (Play upload key; see android/README.md)
val localProperties = Properties().apply {
    rootProject.file("local.properties").takeIf { it.exists() }?.inputStream()?.use { load(it) }
}
fun local(key: String, default: String) = localProperties.getProperty(key) ?: default

kotlin { compilerOptions { jvmTarget.set(JvmTarget.JVM_17) } }

android {
    namespace = "com.rollspot.app"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.rollspot.app"
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "1.1.0"

        buildConfigField("String", "API_BASE_URL", "\"${local("rollspot.apiBaseUrl", "https://rollspot-api.joecast208.workers.dev")}\"")
        buildConfigField("String", "GOOGLE_WEB_CLIENT_ID", "\"${local("rollspot.googleWebClientId", "")}\"")
        // Firebase Cloud Messaging, set by hand instead of google-services.json; push is off while empty.
        buildConfigField("String", "FIREBASE_API_KEY", "\"${local("rollspot.firebase.apiKey", "")}\"")
        buildConfigField("String", "FIREBASE_APP_ID", "\"${local("rollspot.firebase.appId", "")}\"")
        buildConfigField("String", "FIREBASE_PROJECT_ID", "\"${local("rollspot.firebase.projectId", "")}\"")
        buildConfigField("String", "FIREBASE_SENDER_ID", "\"${local("rollspot.firebase.senderId", "")}\"")
    }

    // Play upload key, only when it's set up on this machine; otherwise release builds stay unsigned.
    val releaseStore = localProperties.getProperty("rollspot.release.storeFile")?.let(rootProject::file)
    signingConfigs {
        if (releaseStore != null) {
            create("release") {
                storeFile = releaseStore
                storePassword = local("rollspot.release.storePassword", "")
                keyAlias = local("rollspot.release.keyAlias", "upload")
                keyPassword = local("rollspot.release.keyPassword", "")
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            signingConfig = signingConfigs.findByName("release")
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    packaging {
        resources { excludes += "/META-INF/{AL2.0,LGPL2.1}" }
    }
}

dependencies {
    implementation(project(":shared"))

    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.navigation.compose)
    implementation(libs.coroutines.android)

    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.ui.graphics)
    implementation(libs.compose.ui.tooling.preview)
    implementation(libs.compose.material3)
    implementation(libs.compose.material.icons)
    debugImplementation(libs.compose.ui.tooling)

    // Google Sign-In through Credential Manager (ID token → shared AuthModel)
    implementation(libs.credentials)
    implementation(libs.credentials.play.services)
    implementation(libs.googleid)

    implementation(libs.maplibre)

    // Backdrop blur for glass buttons and sheets (Android has no native Liquid Glass).
    implementation(libs.haze)

    // Push notifications (no google-services plugin: options come from local.properties)
    implementation(platform(libs.firebase.bom))
    implementation(libs.firebase.messaging)

    implementation(libs.coil.compose)
    implementation(libs.coil.network.okhttp)
}
