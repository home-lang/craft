/**
 * Craft iOS Builder
 *
 * Generates native iOS apps from web content using WKWebView.
 */

import { readFileSync, writeFileSync, mkdirSync, existsSync, cpSync, readdirSync } from 'node:fs'
import { join, dirname, basename } from 'node:path'
import { $ } from 'bun'

const TEMPLATES_DIR = join(dirname(import.meta.dir), 'templates')

export interface CraftConfig {
  appName: string
  bundleId: string
  version?: string
  buildNumber?: string
  darkMode?: boolean
  backgroundColor?: string
  enableSpeechRecognition?: boolean
  enableHaptics?: boolean
  enableShare?: boolean
  devServerURL?: string
  iosVersion?: string
  teamId?: string
}

export interface InitOptions {
  name: string
  bundleId?: string
  teamId?: string
  output: string
}

export interface BuildOptions {
  htmlPath?: string
  devServer?: string
  output: string
}

export interface OpenOptions {
  output: string
}

export interface RunOptions {
  simulator: boolean
  output: string
}

/**
 * Initialize a new iOS project
 */
export async function init(options: InitOptions): Promise<void> {
  const { name, bundleId, teamId, output } = options

  console.log(`\n⚡ Initializing Craft iOS project: ${name}`)
  console.log(`   Output: ${output}\n`)

  // Create directory structure
  const dirs = [output, join(output, 'Sources'), join(output, 'dist')]
  for (const dir of dirs) {
    if (!existsSync(dir)) {
      mkdirSync(dir, { recursive: true })
    }
  }

  // Generate bundle ID from name if not provided
  const finalBundleId = bundleId || `com.craft.${name.toLowerCase().replace(/[^a-z0-9]/g, '')}`
  const bundleIdPrefix = finalBundleId.split('.').slice(0, -1).join('.')

  // Create craft.config.json
  const config: CraftConfig = {
    appName: name,
    bundleId: finalBundleId,
    version: '1.0.0',
    buildNumber: '1',
    darkMode: true,
    backgroundColor: '#1a1a2e',
    enableSpeechRecognition: true,
    enableHaptics: true,
    enableShare: true,
    iosVersion: '15.0',
    teamId: teamId || '',
  }

  writeFileSync(join(output, 'craft.config.json'), JSON.stringify(config, null, 2))

  // Copy and customize Swift template
  const swiftTemplate = readFileSync(join(TEMPLATES_DIR, 'CraftApp.swift'), 'utf-8')
  writeFileSync(join(output, 'Sources', `${name}App.swift`), swiftTemplate.replace(/CraftApp/g, `${name}App`))

  // Generate Info.plist
  const infoPlistTemplate = readFileSync(join(TEMPLATES_DIR, 'Info.plist.template'), 'utf-8')
  const infoPlist = infoPlistTemplate
    .replace(/\{\{APP_NAME\}\}/g, name)
    .replace(/\{\{BUNDLE_ID\}\}/g, finalBundleId)
    .replace(/\{\{VERSION\}\}/g, config.version || '1.0.0')
    .replace(/\{\{BUILD_NUMBER\}\}/g, config.buildNumber || '1')
    .replace(/\{\{UI_STYLE\}\}/g, config.darkMode ? 'Dark' : 'Light')

  writeFileSync(join(output, 'Info.plist'), infoPlist)

  // Generate project.yml for xcodegen
  const projectYmlTemplate = readFileSync(join(TEMPLATES_DIR, 'project.yml.template'), 'utf-8')
  const projectYml = projectYmlTemplate
    .replace(/\{\{APP_NAME\}\}/g, name)
    .replace(/\{\{BUNDLE_ID\}\}/g, finalBundleId)
    .replace(/\{\{BUNDLE_ID_PREFIX\}\}/g, bundleIdPrefix)
    .replace(/\{\{VERSION\}\}/g, config.version || '1.0.0')
    .replace(/\{\{BUILD_NUMBER\}\}/g, config.buildNumber || '1')
    .replace(/\{\{IOS_VERSION\}\}/g, config.iosVersion || '15.0')
    .replace(/\{\{TEAM_ID\}\}/g, teamId || '')

  writeFileSync(join(output, 'project.yml'), projectYml)

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
      font-family: -apple-system, system-ui, sans-serif;
      background: ${config.backgroundColor};
      color: white;
      min-height: 100vh;
      display: flex;
      justify-content: center;
      align-items: center;
      padding: env(safe-area-inset-top) env(safe-area-inset-right) env(safe-area-inset-bottom) env(safe-area-inset-left);
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
    <p>Built with Craft iOS</p>
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

  writeFileSync(join(output, 'dist', 'index.html'), placeholderHtml)

  console.log('✅ Project initialized')
  console.log('')
  console.log('Next steps:')
  console.log(`  1. cd ${output}`)
  console.log('  2. Add your web content to dist/index.html')
  console.log('  3. Run: craft ios build')
  console.log('  4. Run: craft ios open')
  console.log('')
}

/**
 * Build web assets and generate Xcode project
 */
export async function build(options: BuildOptions): Promise<void> {
  const { htmlPath, devServer, output } = options

  console.log('\n📦 Building Craft iOS project...')

  // Load config
  const configPath = join(output, 'craft.config.json')
  if (!existsSync(configPath)) {
    throw new Error(`No craft.config.json found in ${output}. Run 'craft ios init' first.`)
  }

  const config: CraftConfig = JSON.parse(readFileSync(configPath, 'utf-8'))

  // Update dev server URL if provided
  if (devServer) {
    config.devServerURL = devServer
    writeFileSync(configPath, JSON.stringify(config, null, 2))
    console.log(`   Dev server: ${devServer}`)
  }

  // Copy HTML if provided
  if (htmlPath) {
    const distDir = join(output, 'dist')
    if (!existsSync(distDir)) {
      mkdirSync(distDir, { recursive: true })
    }

    if (existsSync(htmlPath)) {
      const stat = await Bun.file(htmlPath).exists()
      if (stat) {
        // Single file
        const html = readFileSync(htmlPath, 'utf-8')
        writeFileSync(join(distDir, 'index.html'), html)
        console.log(`   Copied: ${htmlPath} → dist/index.html`)
      }
    } else {
      throw new Error(`HTML path not found: ${htmlPath}`)
    }
  }

  // Generate Xcode project using xcodegen
  try {
    const result = await $`which xcodegen`.quiet()
    if (result.exitCode === 0) {
      console.log('   Running xcodegen...')
      await $`cd ${output} && xcodegen generate`.quiet()
      console.log(`✅ Xcode project created: ${config.appName}.xcodeproj`)
    } else {
      throw new Error('xcodegen not found')
    }
  } catch {
    console.log('⚠️  xcodegen not found. Install with: brew install xcodegen')
    console.log('   Then run: craft ios build')
    return
  }

  console.log('')
}

/**
 * Open Xcode project
 */
export async function open(options: OpenOptions): Promise<void> {
  const { output } = options

  // Find .xcodeproj
  const files = readdirSync(output)
  const xcodeproj = files.find(f => f.endsWith('.xcodeproj'))

  if (!xcodeproj) {
    throw new Error(`No Xcode project found in ${output}. Run 'craft ios build' first.`)
  }

  const projectPath = join(output, xcodeproj)
  console.log(`🚀 Opening ${xcodeproj}...`)
  await $`open ${projectPath}`
}

/**
 * Build and run on simulator or device
 */
export async function run(options: RunOptions): Promise<void> {
  const { simulator, output } = options

  // First build
  await build({ output })

  // Find .xcodeproj
  const files = readdirSync(output)
  const xcodeproj = files.find(f => f.endsWith('.xcodeproj'))

  if (!xcodeproj) {
    throw new Error(`No Xcode project found in ${output}`)
  }

  const projectPath = join(output, xcodeproj)
  const appName = xcodeproj.replace('.xcodeproj', '')

  if (simulator) {
    console.log('📱 Building and running on simulator...')
    try {
      // Build for simulator
      await $`xcodebuild -project ${projectPath} -scheme ${appName} -destination 'platform=iOS Simulator,name=iPhone 15' build`

      // Boot simulator if needed
      await $`xcrun simctl boot "iPhone 15"`.quiet().nothrow()

      // Open simulator
      await $`open -a Simulator`

      console.log('✅ App deployed to simulator')
    } catch (error) {
      console.error('Build failed. Open in Xcode for details:', projectPath)
    }
  } else {
    // Open in Xcode for device deployment
    console.log('📱 Opening Xcode for device deployment...')
    await $`open ${projectPath}`
    console.log('')
    console.log('In Xcode:')
    console.log('  1. Select your Team in Signing & Capabilities')
    console.log('  2. Connect your iPhone')
    console.log('  3. Select your device')
    console.log('  4. Click Run (▶️)')
  }
}

// Re-export types
export type { CraftConfig }
