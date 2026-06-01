allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Fix for flutter_inappwebview incompatibility with AGP 8+
subprojects {
    afterEvaluate { project ->
        if (project.hasProperty('android')) {
            project.android {
                if (buildTypes?.release?.hasProperty('proguardFiles')) {
                    buildTypes {
                        release {
                            proguardFiles.removeIf {
                                it.name == 'proguard-android.txt'
                            }
                            proguardFile getDefaultProguardFile('proguard-android-optimize.txt')
                        }
                    }
                }
            }
        }
    }
}

rootProject.buildDir = "../build"
subprojects {
    project.buildDir = "${rootProject.buildDir}/${project.name}"
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register("clean", Delete) {
    delete rootProject.buildDir
}
