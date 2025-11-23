/**
 * Craft Android Builder
 *
 * Generates native Android apps from web content using WebView.
 */

import { readFileSync, writeFileSync, mkdirSync, existsSync, readdirSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { $ } from 'bun'

const TEMPLATES_DIR = join(dirname(import.meta.dir), 'templates')

export interface CraftAndroidConfig {
  appName: string
  packageName: string
  version?: string
  versionCode?: number
  darkMode?: boolean
  backgroundColor?: string
  enableSpeechRecognition?: boolean
  enableHaptics?: boolean
  enableShare?: boolean
  enableCamera?: boolean
  enableBiometric?: boolean
  enablePushNotifications?: boolean
  devServerURL?: string
  minSdk?: number
  targetSdk?: number
}

export interface InitOptions {
  name: string
  packageName?: string
  output: string
}

export interface BuildOptions {
  htmlPath?: string
  devServer?: string
  output: string
  release?: boolean
}

export interface OpenOptions {
  output: string
}

export interface RunOptions {
  device?: string
  output: string
}

/**
 * Initialize a new Android project
 */
export async function init(options: InitOptions): Promise<void> {
  const { name, packageName, output } = options

  console.log(`\n⚡ Initializing Craft Android project: ${name}`)
  console.log(`   Output: ${output}\n`)

  // Generate package name from app name if not provided
  const finalPackageName = packageName || `com.craft.${name.toLowerCase().replace(/[^a-z0-9]/g, '')}`
  const packagePath = finalPackageName.replace(/\./g, '/')

  // Create directory structure
  const dirs = [
    output,
    join(output, 'app/src/main/java', packagePath),
    join(output, 'app/src/main/res/layout'),
    join(output, 'app/src/main/res/values'),
    join(output, 'app/src/main/res/drawable'),
    join(output, 'app/src/main/assets'),
    join(output, 'gradle/wrapper'),
  ]

  for (const dir of dirs) {
    if (!existsSync(dir)) {
      mkdirSync(dir, { recursive: true })
    }
  }

  // Create craft.config.json
  const config: CraftAndroidConfig = {
    appName: name,
    packageName: finalPackageName,
    version: '1.0.0',
    versionCode: 1,
    darkMode: true,
    backgroundColor: '#1a1a2e',
    enableSpeechRecognition: true,
    enableHaptics: true,
    enableShare: true,
    enableCamera: true,
    enableBiometric: true,
    enablePushNotifications: false,
    minSdk: 24,
    targetSdk: 34,
  }

  writeFileSync(join(output, 'craft.config.json'), JSON.stringify(config, null, 2))

  // Copy templates
  const mainActivityTemplate = readFileSync(join(TEMPLATES_DIR, 'MainActivity.kt.template'), 'utf-8')
  const mainActivity = mainActivityTemplate
    .replace(/\{\{PACKAGE_NAME\}\}/g, finalPackageName)
    .replace(/\{\{APP_NAME\}\}/g, name)

  writeFileSync(join(output, 'app/src/main/java', packagePath, 'MainActivity.kt'), mainActivity)

  // Create CraftBridge.kt
  const craftBridgeTemplate = readFileSync(join(TEMPLATES_DIR, 'CraftBridge.kt.template'), 'utf-8')
  const craftBridge = craftBridgeTemplate.replace(/\{\{PACKAGE_NAME\}\}/g, finalPackageName)
  writeFileSync(join(output, 'app/src/main/java', packagePath, 'CraftBridge.kt'), craftBridge)

  // Create AndroidManifest.xml
  const manifestTemplate = readFileSync(join(TEMPLATES_DIR, 'AndroidManifest.xml.template'), 'utf-8')
  const manifest = manifestTemplate
    .replace(/\{\{PACKAGE_NAME\}\}/g, finalPackageName)
    .replace(/\{\{APP_NAME\}\}/g, name)

  writeFileSync(join(output, 'app/src/main/AndroidManifest.xml'), manifest)

  // Create build.gradle.kts (project level)
  const projectGradleTemplate = readFileSync(join(TEMPLATES_DIR, 'build.gradle.kts.project.template'), 'utf-8')
  writeFileSync(join(output, 'build.gradle.kts'), projectGradleTemplate)

  // Create build.gradle.kts (app level)
  const appGradleTemplate = readFileSync(join(TEMPLATES_DIR, 'build.gradle.kts.app.template'), 'utf-8')
  const appGradle = appGradleTemplate
    .replace(/\{\{PACKAGE_NAME\}\}/g, finalPackageName)
    .replace(/\{\{VERSION_NAME\}\}/g, config.version || '1.0.0')
    .replace(/\{\{VERSION_CODE\}\}/g, String(config.versionCode || 1))
    .replace(/\{\{MIN_SDK\}\}/g, String(config.minSdk || 24))
    .replace(/\{\{TARGET_SDK\}\}/g, String(config.targetSdk || 34))

  writeFileSync(join(output, 'app/build.gradle.kts'), appGradle)

  // Create settings.gradle.kts
  const settingsTemplate = readFileSync(join(TEMPLATES_DIR, 'settings.gradle.kts.template'), 'utf-8')
  const settings = settingsTemplate.replace(/\{\{APP_NAME\}\}/g, name)
  writeFileSync(join(output, 'settings.gradle.kts'), settings)

  // Create gradle.properties
  const gradleProperties = `org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8
android.useAndroidX=true
kotlin.code.style=official
android.nonTransitiveRClass=true
`
  writeFileSync(join(output, 'gradle.properties'), gradleProperties)

  // Create local.properties placeholder
  writeFileSync(join(output, 'local.properties'), '# SDK location will be set by Android Studio\n')

  // Create gradle wrapper properties
  const gradleWrapperProps = `distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https\\://services.gradle.org/distributions/gradle-8.4-bin.zip
networkTimeout=10000
validateDistributionUrl=true
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
`
  writeFileSync(join(output, 'gradle/wrapper/gradle-wrapper.properties'), gradleWrapperProps)

  // Create res/values files
  const stringsXml = `<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">${name}</string>
</resources>
`
  writeFileSync(join(output, 'app/src/main/res/values/strings.xml'), stringsXml)

  const colorsXml = `<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="primary">#1a1a2e</color>
    <color name="primary_dark">#16162b</color>
    <color name="accent">#4ade80</color>
    <color name="background">${config.backgroundColor}</color>
</resources>
`
  writeFileSync(join(output, 'app/src/main/res/values/colors.xml'), colorsXml)

  const themesXml = `<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="Theme.CraftApp" parent="Theme.Material3.DayNight.NoActionBar">
        <item name="android:statusBarColor">@color/primary_dark</item>
        <item name="android:navigationBarColor">@color/primary</item>
        <item name="android:windowBackground">@color/background</item>
    </style>
</resources>
`
  writeFileSync(join(output, 'app/src/main/res/values/themes.xml'), themesXml)

  // Create activity_main.xml
  const activityMainXml = `<?xml version="1.0" encoding="utf-8"?>
<androidx.coordinatorlayout.widget.CoordinatorLayout
    xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:fitsSystemWindows="true">

    <WebView
        android:id="@+id/webview"
        android:layout_width="match_parent"
        android:layout_height="match_parent" />

</androidx.coordinatorlayout.widget.CoordinatorLayout>
`
  writeFileSync(join(output, 'app/src/main/res/layout/activity_main.xml'), activityMainXml)

  // Create placeholder index.html
  const placeholderHtml = `<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="viewport-fit=cover, width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>${name}</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: 'Roboto', sans-serif;
      background: ${config.backgroundColor};
      color: white;
      min-height: 100vh;
      display: flex;
      justify-content: center;
      align-items: center;
    }
    .container { text-align: center; padding: 2rem; }
    h1 { font-size: 2.5rem; margin-bottom: 1rem; }
    p { opacity: 0.7; }
    .ready { color: #4ade80; font-size: 0.9rem; margin-top: 2rem; }
  </style>
</head>
<body>
  <div class="container">
    <h1>⚡ ${name}</h1>
    <p>Built with Craft Android</p>
    <p class="ready" id="status">Waiting for Craft bridge...</p>
  </div>
  <script>
    window.addEventListener('craftReady', (e) => {
      document.getElementById('status').textContent = '✓ Craft bridge ready (platform: ' + e.detail.platform + ')';
      console.log('Craft capabilities:', e.detail.capabilities);
    });
  </script>
</body>
</html>`

  writeFileSync(join(output, 'app/src/main/assets/index.html'), placeholderHtml)

  console.log('✅ Project initialized')
  console.log('')
  console.log('Next steps:')
  console.log(`  1. cd ${output}`)
  console.log('  2. Add your web content to app/src/main/assets/index.html')
  console.log('  3. Run: craft android build')
  console.log('  4. Run: craft android open')
  console.log('')
}

/**
 * Build Android project
 */
export async function build(options: BuildOptions): Promise<void> {
  const { htmlPath, devServer, output, release } = options

  console.log('\n📦 Building Craft Android project...')

  // Load config
  const configPath = join(output, 'craft.config.json')
  if (!existsSync(configPath)) {
    throw new Error(`No craft.config.json found in ${output}. Run 'craft android init' first.`)
  }

  const config: CraftAndroidConfig = JSON.parse(readFileSync(configPath, 'utf-8'))

  // Update dev server URL if provided
  if (devServer) {
    config.devServerURL = devServer
    writeFileSync(configPath, JSON.stringify(config, null, 2))
    console.log(`   Dev server: ${devServer}`)
  }

  // Copy HTML if provided
  if (htmlPath) {
    const assetsDir = join(output, 'app/src/main/assets')
    if (!existsSync(assetsDir)) {
      mkdirSync(assetsDir, { recursive: true })
    }

    if (existsSync(htmlPath)) {
      const html = readFileSync(htmlPath, 'utf-8')
      writeFileSync(join(assetsDir, 'index.html'), html)
      console.log(`   Copied: ${htmlPath} → assets/index.html`)
    } else {
      throw new Error(`HTML path not found: ${htmlPath}`)
    }
  }

  // Check if gradlew exists
  const gradlewPath = join(output, 'gradlew')
  if (!existsSync(gradlewPath)) {
    console.log('   Generating Gradle wrapper...')
    try {
      await $`cd ${output} && gradle wrapper`.quiet()
    } catch {
      console.log('⚠️  Gradle not found. Please install Android Studio or Gradle.')
      console.log('   Download: https://developer.android.com/studio')
      return
    }
  }

  // Build the project
  const buildType = release ? 'assembleRelease' : 'assembleDebug'
  console.log(`   Building ${release ? 'release' : 'debug'} APK...`)

  try {
    await $`cd ${output} && ./gradlew ${buildType}`
    const apkPath = release
      ? 'app/build/outputs/apk/release/app-release.apk'
      : 'app/build/outputs/apk/debug/app-debug.apk'
    console.log(`✅ APK built: ${apkPath}`)
  } catch (error) {
    console.error('Build failed. Open in Android Studio for details.')
    throw error
  }

  console.log('')
}

/**
 * Open Android project in Android Studio
 */
export async function open(options: OpenOptions): Promise<void> {
  const { output } = options

  if (!existsSync(output)) {
    throw new Error(`No Android project found in ${output}. Run 'craft android init' first.`)
  }

  console.log(`🚀 Opening Android project in Android Studio...`)

  // Try to open with Android Studio
  try {
    // macOS
    await $`open -a "Android Studio" ${output}`.quiet()
  } catch {
    try {
      // Linux
      await $`studio ${output}`.quiet()
    } catch {
      console.log('⚠️  Android Studio not found.')
      console.log('   Please open the project manually in Android Studio:')
      console.log(`   ${output}`)
    }
  }
}

/**
 * Run on Android device or emulator
 */
export async function run(options: RunOptions): Promise<void> {
  const { device, output } = options

  // First build
  await build({ output })

  // Install and run
  console.log('📱 Installing and running on device...')

  try {
    const apkPath = join(output, 'app/build/outputs/apk/debug/app-debug.apk')

    if (device) {
      await $`adb -s ${device} install -r ${apkPath}`
    } else {
      await $`adb install -r ${apkPath}`
    }

    // Get package name from config
    const config: CraftAndroidConfig = JSON.parse(
      readFileSync(join(output, 'craft.config.json'), 'utf-8')
    )

    // Launch the app
    const launchCmd = `${config.packageName}/.MainActivity`
    if (device) {
      await $`adb -s ${device} shell am start -n ${launchCmd}`
    } else {
      await $`adb shell am start -n ${launchCmd}`
    }

    console.log('✅ App launched')
  } catch (error) {
    console.error('Failed to install/run. Make sure:')
    console.error('  1. ADB is installed and in PATH')
    console.error('  2. A device/emulator is connected (run: adb devices)')
    throw error
  }
}

export type { CraftAndroidConfig }
