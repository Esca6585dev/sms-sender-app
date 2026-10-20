import org.gradle.api.tasks.Delete
import org.gradle.api.tasks.compile.JavaCompile
import org.gradle.api.file.Directory
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}


buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.0")
    }
}

// 📁 Перенос build папки (как у тебя было)
val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()

rootProject.layout.buildDirectory.value(newBuildDir)

// 🔥 ГЛАВНЫЙ блок
subprojects {

    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // ✅ Java 17 для всех модулей
    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = "17"
        targetCompatibility = "17"
    }

    // ✅ Kotlin 17 (НОВЫЙ API, БЕЗ kotlinOptions)
    tasks.withType<KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(JvmTarget.JVM_17)
        }
    }
}

// зависимость app
subprojects {
    project.evaluationDependsOn(":app")
}

// 🧹 clean
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
// Some plugin versions in pubspec.yaml (file_picker 8.x, ...) still compile
// against android-34, while newer transitive AARs such as
// flutter_plugin_android_lifecycle require compileSdk 36. Raise compileSdk for
// every plugin subproject; the long-term fix is upgrading those plugins.
// evaluationDependsOn(":app") above may already have evaluated a project, so
// apply directly in that case instead of registering afterEvaluate.
subprojects {
    if (name != "app") {
        val raiseCompileSdk: Project.() -> Unit = {
            extensions.findByType<com.android.build.gradle.BaseExtension>()
                ?.compileSdkVersion(36)
        }
        if (state.executed) raiseCompileSdk() else afterEvaluate { raiseCompileSdk() }
    }
}
