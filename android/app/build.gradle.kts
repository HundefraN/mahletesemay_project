plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.hundefra.mahlete_semay"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.hundefra.mahlete_semay"
        minSdkVersion flutter.minSdkVersion
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
    }
}
