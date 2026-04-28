allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Provider<Directory> = layout.buildDirectory.dir("../../build")
layout.buildDirectory.set(newBuildDir.get())

subprojects {
    layout.buildDirectory.set(
        rootProject.layout.buildDirectory.dir(project.name)
    )
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
