plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.roborazzi)
}

android {
    namespace = "uz.wasira"
    compileSdk = 37

    defaultConfig {
        applicationId = "uz.wasira"
        minSdk = 26
        targetSdk = 37
        versionCode = 2
        versionName = "1.1.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // Release signing comes from the environment, never the repo:
    //   WASIRA_KEYSTORE           path to the .jks (kept outside the repo)
    //   WASIRA_KEYSTORE_PASSWORD  store and key password
    // Without them a release build is produced unsigned.
    val keystorePath = System.getenv("WASIRA_KEYSTORE")
    val keystorePassword = System.getenv("WASIRA_KEYSTORE_PASSWORD")
    val releaseSigning = if (keystorePath != null && keystorePassword != null) {
        signingConfigs.create("release") {
            storeFile = file(keystorePath)
            storePassword = keystorePassword
            keyAlias = "wasira"
            keyPassword = keystorePassword
        }
    } else null

    buildTypes {
        // Debug installs as uz.wasira.debug beside the signed release, so a
        // development build never has to replace or uninstall it.
        debug {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
        }
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"))
            signingConfig = releaseSigning
        }
    }

    buildFeatures { compose = true }

    androidResources {
        generateLocaleConfig = true
    }

    testOptions {
        unitTests.isIncludeAndroidResources = true
    }

    lint {
        error += "MissingTranslation"
        warningsAsErrors = false
        abortOnError = true
    }
}

kotlin { jvmToolchain(17) }

// Goldens are committed next to the tests, not left in build/.
roborazzi {
    outputDir.set(file("src/test/snapshots"))
}

dependencies {
    implementation(libs.core.ktx)
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.material3)
    implementation(libs.compose.ui.tooling.preview)
    implementation(libs.activity.compose)
    implementation(libs.lifecycle.viewmodel.compose)
    implementation(libs.lifecycle.runtime.compose)
    implementation(libs.coroutines.android)
    implementation(libs.serialization.json)
    implementation(libs.okhttp)
    debugImplementation(libs.compose.ui.tooling)
    debugImplementation(libs.compose.ui.test.manifest)

    testImplementation(libs.junit)
    testImplementation(libs.coroutines.test)
    testImplementation(libs.mockwebserver)
    testImplementation(libs.robolectric)
    testImplementation(platform(libs.compose.bom))
    testImplementation(libs.compose.ui.test.junit4)
    testImplementation(libs.roborazzi)
    testImplementation(libs.roborazzi.compose)
    testImplementation(libs.roborazzi.junit.rule)
}
