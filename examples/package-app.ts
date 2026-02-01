#!/usr/bin/env bun

/**
 * Example: Package a Craft Application
 *
 * This example shows how to use the Craft packaging API
 * to create installers for your application.
 */

import { packageApp } from '../packages/typescript/src/package'
import { join } from 'path'

async function main() {
  console.log('📦 Packaging Example Craft App\n')

  // Package the Pomodoro timer app
  const results = await packageApp({
    name: 'Pomodoro Timer',
    version: '1.0.0',
    description: 'A beautiful Pomodoro timer with system tray integration',
    author: 'Your Name <you@example.com>',
    homepage: 'https://github.com/yourname/pomodoro',

    // Path to your built binary
    binaryPath: join(__dirname, '../packages/zig/zig-out/bin/craft'),

    // Bundle identifier (macOS/iOS)
    bundleId: 'com.example.pomodoro',

    // Output directory
    outDir: join(__dirname, '../dist'),

    // Build for all platforms
    platforms: ['macos', 'windows', 'linux'],

    // macOS options
    macos: {
      dmg: true,  // Create DMG
      pkg: true,  // Create PKG
    },

    // Windows options
    windows: {
      msi: true,  // Create MSI (requires WiX)
      zip: true,  // Create ZIP (fallback)
    },

    // Linux options
    linux: {
      deb: true,      // Create DEB
      rpm: true,      // Create RPM
      appImage: true, // Create AppImage
      categories: ['Utility', 'Development'],
      debDependencies: ['libgtk-3-0', 'libwebkit2gtk-4.0-37'],
      rpmDependencies: ['gtk3', 'webkit2gtk3'],
    },
  })

  console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
  console.log('📊 Results:\n')

  for (const result of results) {
    const status = result.success ? '✅' : '❌'
    console.log(`${status} ${result.platform}/${result.format}`)

    if (result.success && result.outputPath) {
      console.log(`   📁 ${result.outputPath}`)
    } else if (result.error) {
      console.log(`   ⚠️  ${result.error}`)
    }
  }

  const successCount = results.filter(r => r.success).length
  console.log(`\n✨ ${successCount}/${results.length} packages created successfully!`)
}

main().catch(console.error)
