// Gradle root for everything Kotlin: the shared business-logic module and the Android app.
// iOS (Rollspot.xcodeproj) consumes :shared as a framework built by the Xcode build phase.
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    // Downloads the JDK the build asks for (17) so nobody has to install it by hand.
    id("org.gradle.toolchains.foojay-resolver-convention") version "1.0.0"
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "Rollspot"
include(":shared")
include(":androidApp")
project(":androidApp").projectDir = file("android/app")
