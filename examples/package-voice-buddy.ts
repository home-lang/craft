#!/usr/bin/env bun

/**
 * Package Voice Buddy as a macOS .app and .dmg
 *
 * This creates a proper macOS application bundle with:
 * - The Craft native binary
 * - The voice-buddy.stx content embedded
 * - A launcher script to tie them together
 *
 * Run with: bun examples/package-voice-buddy.ts
 */

import { existsSync, mkdirSync, writeFileSync, copyFileSync, chmodSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { spawn } from 'node:child_process'

const APP_NAME = 'Buddy'
const APP_VERSION = '1.0.0'
const BUNDLE_ID = 'com.stacks.buddy'

// Paths
const CRAFT_BINARY = join(import.meta.dir, '../packages/zig/zig-out/bin/craft')
const STX_FILE = '/Users/glennmichaeltorregosa/Documents/Projects/stx/examples/voice-buddy.stx'
const OUT_DIR = join(import.meta.dir, '../dist')
const APP_BUNDLE = join(OUT_DIR, `${APP_NAME}.app`)

async function main() {
  console.log(`📦 Packaging ${APP_NAME} v${APP_VERSION}`)
  console.log('')

  // Validate inputs
  if (!existsSync(CRAFT_BINARY)) {
    console.error(`❌ Craft binary not found: ${CRAFT_BINARY}`)
    console.error('   Run: cd packages/zig && zig build')
    process.exit(1)
  }

  if (!existsSync(STX_FILE)) {
    console.error(`❌ STX file not found: ${STX_FILE}`)
    process.exit(1)
  }

  // Read the STX/HTML content
  const htmlContent = readFileSync(STX_FILE, 'utf-8')
  console.log(`✅ Loaded STX file (${Math.round(htmlContent.length / 1024)}KB)`)

  // Create output directory
  mkdirSync(OUT_DIR, { recursive: true })

  // Create app bundle structure
  const contentsDir = join(APP_BUNDLE, 'Contents')
  const macosDir = join(contentsDir, 'MacOS')
  const resourcesDir = join(contentsDir, 'Resources')

  mkdirSync(macosDir, { recursive: true })
  mkdirSync(resourcesDir, { recursive: true })
  console.log(`✅ Created app bundle structure`)

  // Copy the Craft binary AS the main executable (not a shell script wrapper)
  // This is the key - macOS GUI apps need a real binary, not a shell script
  const binaryDest = join(macosDir, APP_NAME)
  copyFileSync(CRAFT_BINARY, binaryDest)
  chmodSync(binaryDest, 0o755)
  console.log(`✅ Copied Craft binary as main executable`)

  // Write the HTML content to Resources
  const htmlDest = join(resourcesDir, 'app.html')
  writeFileSync(htmlDest, htmlContent)
  console.log(`✅ Embedded app content`)

  // Create a simple wrapper script that users can run from terminal if needed
  // But the main app uses the binary directly
  const terminalScript = `#!/bin/bash
# Terminal launcher for ${APP_NAME}
# The .app bundle runs the binary directly, this is just for debugging
APP_DIR="$(dirname "$(dirname "$(dirname "$0")")")"
exec "$APP_DIR/Contents/MacOS/${APP_NAME}" --url "file://$APP_DIR/Contents/Resources/app.html" --title "${APP_NAME}" --width 1000 --height 800 "$@"
`
  writeFileSync(join(resourcesDir, 'run-from-terminal.sh'), terminalScript)
  chmodSync(join(resourcesDir, 'run-from-terminal.sh'), 0o755)
  console.log(`✅ Created terminal helper script`)

  // Create Info.plist
  const infoPlist = `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME} - Voice AI Code Assistant</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${APP_VERSION}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>10.13</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>${APP_NAME} needs microphone access for voice commands.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>${APP_NAME} needs automation access to interact with other applications.</string>
</dict>
</plist>`

  writeFileSync(join(contentsDir, 'Info.plist'), infoPlist)
  console.log(`✅ Created Info.plist`)

  // Create PkgInfo
  writeFileSync(join(contentsDir, 'PkgInfo'), 'APPL????')
  console.log(`✅ Created PkgInfo`)

  console.log('')
  console.log(`✅ App bundle created: ${APP_BUNDLE}`)
  console.log('')

  // Try to create DMG
  console.log('📀 Creating DMG installer...')
  const dmgPath = join(OUT_DIR, `${APP_NAME}-${APP_VERSION}.dmg`)

  const dmgResult = await createDMG(APP_BUNDLE, dmgPath, APP_NAME)

  if (dmgResult.success) {
    console.log(`✅ DMG created: ${dmgPath}`)
  } else {
    console.log(`⚠️  DMG creation failed: ${dmgResult.error}`)
    console.log('   You can still use the .app bundle directly.')
  }

  console.log('')
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
  console.log('📊 Summary:')
  console.log('')
  console.log(`  📁 App Bundle: ${APP_BUNDLE}`)
  if (dmgResult.success) {
    console.log(`  📀 DMG:        ${dmgPath}`)
  }
  console.log('')
  console.log('🚀 To run the app:')
  console.log(`   open "${APP_BUNDLE}"`)
  console.log('')
  console.log('📝 Note: The app will ask for microphone permission on first use.')
  console.log('   This is expected - even Tauri apps require this for WebView audio access.')
}

async function createDMG(
  appBundlePath: string,
  outputPath: string,
  volumeName: string
): Promise<{ success: boolean; error?: string }> {
  return new Promise((resolve) => {
    // Remove existing DMG if present
    if (existsSync(outputPath)) {
      const { unlinkSync } = require('fs')
      unlinkSync(outputPath)
    }

    const proc = spawn('hdiutil', [
      'create',
      '-volname', volumeName,
      '-srcfolder', appBundlePath,
      '-ov',
      '-format', 'UDZO',
      outputPath,
    ])

    let stderr = ''
    proc.stderr.on('data', (data) => {
      stderr += data.toString()
    })

    proc.on('close', (code) => {
      if (code === 0) {
        resolve({ success: true })
      } else {
        resolve({ success: false, error: stderr || `hdiutil exited with code ${code}` })
      }
    })

    proc.on('error', (err) => {
      resolve({ success: false, error: err.message })
    })
  })
}

main().catch(console.error)
