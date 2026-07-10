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

// Workaround: plugin lama (prepaid_lib_flutter_null_safety) tidak menyetel
// `namespace` yang diwajibkan AGP 8+. Suntikkan namespace saat plugin
// com.android.library diterapkan (via refleksi, tanpa butuh tipe AGP di root).
subprojects {
    if (project.name == "prepaid_lib_flutter_null_safety") {
        project.plugins.withId("com.android.library") {
            val ext = project.extensions.findByName("android")
            if (ext != null) {
                try {
                    val current = ext.javaClass.getMethod("getNamespace").invoke(ext)
                    if (current == null) {
                        ext.javaClass
                            .getMethod("setNamespace", String::class.java)
                            .invoke(ext, "com.mdd.prepaid_lib_flutter_null_safety")
                    }
                } catch (_: Exception) {
                }
            }
        }
        // Samakan JVM target Kotlin dengan Java (1.8) agar tidak mismatch.
        project.tasks.withType(org.gradle.api.tasks.compile.JavaCompile::class.java)
            .configureEach {
                sourceCompatibility = "1.8"
                targetCompatibility = "1.8"
            }
        project.tasks.configureEach {
            if (javaClass.name.contains("KotlinCompile")) {
                try {
                    val opts = javaClass.getMethod("getKotlinOptions").invoke(this)
                    opts.javaClass
                        .getMethod("setJvmTarget", String::class.java)
                        .invoke(opts, "1.8")
                } catch (_: Exception) {
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
