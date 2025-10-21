/**
 * Example: Menubar App with System Tray
 *
 * This example demonstrates how to create a menubar-only app (no dock icon)
 * with a system tray icon and context menu.
 *
 * Run with:
 *   bun examples/menubar-app.ts
 */

import { createApp } from '../src/index'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'

// Create the app with system tray enabled
const app = createApp({
  window: {
    title: 'Menubar App',
    width: 400,
    height: 500,
    systemTray: true,
    hideDockIcon: true, // macOS only: hide from dock
    alwaysOnTop: true,
    frameless: true,
  }
})

// Load the example HTML
const htmlPath = join(__dirname, 'system-tray-example.html')
const html = readFileSync(htmlPath, 'utf-8')

// Show the app
app.show(html)
  .then(() => {
    console.log('✅ Menubar app started')
    console.log('   Look for the tray icon in your menubar')
    console.log('   Click it to toggle the window')
  })
  .catch((error) => {
    console.error('❌ Failed to start app:', error)
    process.exit(1)
  })
