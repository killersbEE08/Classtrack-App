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
// Some plugins (e.g. file_picker 8.x) hardcode an older `compileSdk` in their
// own Gradle, which fails AAR metadata checks when a transitive dependency
// requires a newer one. Bump any plugin compiling below the app's level up to
// 36. Reflection keeps this compatible across AGP 8/9 (where the old
// `compileSdkVersion(int)` DSL method was removed in favour of the `compileSdk`
// property).
fun bumpCompileSdk(project: Project) {
    val android = project.extensions.findByName("android") ?: return
    val current = try {
        android.javaClass.getMethod("getCompileSdk").invoke(android) as? Int
    } catch (e: Exception) {
        null
    }
    if (current == null || current < 36) {
        try {
            android.javaClass.methods
                .firstOrNull { it.name == "setCompileSdk" && it.parameterCount == 1 }
                ?.invoke(android, 36)
        } catch (e: Exception) {
            // Leave the plugin's own compileSdk untouched if the reflective
            // setter isn't available; the build will surface any issue.
        }
    }
}

subprojects {
    // Register the compileSdk bump before evaluationDependsOn forces `:app`
    // (and its dependents) to evaluate. Projects that are already evaluated by
    // the time this block reaches them are configured directly.
    if (project.state.executed) {
        bumpCompileSdk(project)
    } else {
        afterEvaluate { bumpCompileSdk(project) }
    }
    project.evaluationDependsOn(":app")
}

// Third-party plugin modules still compile their Java against version 8, which
// the JDK reports as "obsolete". The app module is already on 17; this forces
// every subproject's Java compilation to 17 too, silencing those warnings.
// (Java 17 compiles 8-level source fine, so this is safe.)
subprojects {
    tasks.withType<org.gradle.api.tasks.compile.JavaCompile>().configureEach {
        sourceCompatibility = JavaVersion.VERSION_17.toString()
        targetCompatibility = JavaVersion.VERSION_17.toString()
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
