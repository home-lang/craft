#!/usr/bin/env bun
/**
 * Simple System Tray Example
 *
 * The absolute simplest system tray app possible.
 * Run with: bun run examples/simple-tray.ts
 */

import { createApp } from '../packages/typescript/src/index.ts'

const html = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Simple Tray App</title>
  <style>
    body {
      margin: 0;
      height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      text-align: center;
      padding: 20px;
    }

    h1 {
      font-size: 48px;
      margin: 0 0 10px 0;
    }

    p {
      font-size: 18px;
      opacity: 0.9;
      max-width: 400px;
      line-height: 1.6;
    }

    .status {
      margin-top: 30px;
      padding: 15px 30px;
      background: rgba(255, 255, 255, 0.2);
      border-radius: 30px;
      display: inline-flex;
      align-items: center;
      gap: 10px;
    }

    .dot {
      width: 10px;
      height: 10px;
      background: #4ade80;
      border-radius: 50%;
      animation: pulse 2s infinite;
    }

    @keyframes pulse {
      0%, 100% { opacity: 1; }
      50% { opacity: 0.5; }
    }

    button {
      margin-top: 30px;
      padding: 15px 40px;
      font-size: 16px;
      background: white;
      color: #667eea;
      border: none;
      border-radius: 10px;
      cursor: pointer;
      font-weight: 600;
      transition: all 0.3s ease;
    }

    button:hover {
      transform: translateY(-2px);
      box-shadow: 0 10px 30px rgba(0, 0, 0, 0.2);
    }

    .hint {
      margin-top: 40px;
      font-size: 14px;
      opacity: 0.6;
    }
  </style>
</head>
<body>
  <h1>⚡ System Tray App</h1>
  <p>Look for the app icon in your menubar or system tray!</p>

  <div class="status">
    <div class="dot"></div>
    <span>Running in background</span>
  </div>

  <button onclick="alert('👋 Hello from the system tray!')">
    Click Me!
  </button>

  <div class="hint">
    Press ESC to hide this window<br>
    The app will keep running in your tray
  </div>

  <script>
    console.log('✅ System tray app is running!');
    console.log('💡 Click the tray icon to show/hide this window');

    // Hide window on ESC
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') {
        console.log('Hiding window (app stays in tray)');
        // In production, this would minimize to tray
      }
    });
  </script>
</body>
</html>
`

console.log('🚀 Starting Simple System Tray App...\n')

const app = createApp({
  html,
  window: {
    title: 'Simple Tray App',
    width: 500,
    height: 400,
    systemTray: true,
    darkMode: true,
  },
})

await app.show()
