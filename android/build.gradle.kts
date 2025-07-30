allprojects {
    repositories {
        // 1. 阿里云 Google 镜像（优先下载 Google 系依赖）
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        // 2. 阿里云 Maven Central 镜像（优先下载 Maven 系依赖）
        maven { url = uri("https://maven.aliyun.com/repository/central") }
        // 3. 保留官方源（防止镜像遗漏时兜底）
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}