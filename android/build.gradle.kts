allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

// 核心修复逻辑：统一 Namespace 并强制锁定 JVM 17
subprojects {
    // 1. 修复旧插件（如 flutter_libserialport）缺失 namespace 的问题
    plugins.withId("com.android.library") {
        configure<com.android.build.gradle.LibraryExtension> {
            if (namespace == null || namespace!!.isEmpty()) {
                val manifestFile = file("src/main/AndroidManifest.xml")
                if (manifestFile.exists()) {
                    val builder = javax.xml.parsers.DocumentBuilderFactory.newInstance().newDocumentBuilder()
                    val doc = builder.parse(manifestFile)
                    val pkg = doc.documentElement.getAttribute("package")
                    namespace = if (pkg.isNotEmpty()) pkg else "dev.flutter.${project.name.replace("-", "_")}"
                } else {
                    namespace = "dev.flutter.${project.name.replace("-", "_")}"
                }
            }
        }
    }

    // 2. 保持各模块自行定义编译目标，避免覆盖第三方插件配置
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}