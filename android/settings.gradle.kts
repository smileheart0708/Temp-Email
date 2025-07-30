pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        // 1. 阿里云 Google 镜像（优先下载 Google 系依赖）
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        // 2. 阿里云 Maven Central 镜像（优先下载 Maven 系依赖）
        maven { url = uri("https://maven.aliyun.com/repository/central") }
        // 3. 保留官方源（防止镜像遗漏时兜底）
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.7.3" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

include(":app")
