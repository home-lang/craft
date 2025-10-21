#!/usr/bin/env bun
/**
 * System Tray App Example
 *
 * A simple system tray (menubar) application built with Zyte.
 * Run with: bun run examples/system-tray-app.ts
 *
 * Features:
 * - System tray icon
 * - Menu with actions
 * - Hidden window that appears on click
 * - Notifications
 * - Auto-start option
 */

import { createApp } from '../packages/typescript/src/index.ts'

const html = `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Zyte System Tray App</title>
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }

    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
      height: 100vh;
      display: flex;
      flex-direction: column;
      overflow: hidden;
    }

    .header {
      padding: 20px;
      background: rgba(0, 0, 0, 0.2);
      backdrop-filter: blur(10px);
      border-bottom: 1px solid rgba(255, 255, 255, 0.1);
    }

    h1 {
      font-size: 24px;
      font-weight: 600;
      margin-bottom: 5px;
    }

    .subtitle {
      font-size: 14px;
      opacity: 0.8;
    }

    .container {
      flex: 1;
      padding: 20px;
      overflow-y: auto;
    }

    .card {
      background: rgba(255, 255, 255, 0.1);
      backdrop-filter: blur(10px);
      border-radius: 12px;
      padding: 20px;
      margin-bottom: 15px;
      border: 1px solid rgba(255, 255, 255, 0.2);
      transition: all 0.3s ease;
    }

    .card:hover {
      background: rgba(255, 255, 255, 0.15);
      transform: translateY(-2px);
      box-shadow: 0 10px 30px rgba(0, 0, 0, 0.2);
    }

    .card h2 {
      font-size: 18px;
      margin-bottom: 10px;
      display: flex;
      align-items: center;
      gap: 10px;
    }

    .card p {
      font-size: 14px;
      line-height: 1.6;
      opacity: 0.9;
    }

    .actions {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
      gap: 10px;
      margin-top: 15px;
    }

    button {
      background: rgba(255, 255, 255, 0.2);
      border: 1px solid rgba(255, 255, 255, 0.3);
      color: white;
      padding: 12px 20px;
      border-radius: 8px;
      font-size: 14px;
      font-weight: 500;
      cursor: pointer;
      transition: all 0.2s ease;
      backdrop-filter: blur(10px);
    }

    button:hover {
      background: rgba(255, 255, 255, 0.3);
      transform: translateY(-1px);
      box-shadow: 0 5px 15px rgba(0, 0, 0, 0.2);
    }

    button:active {
      transform: translateY(0);
    }

    .status {
      display: flex;
      align-items: center;
      gap: 8px;
      font-size: 14px;
      padding: 8px 16px;
      background: rgba(255, 255, 255, 0.1);
      border-radius: 20px;
      display: inline-flex;
      margin-top: 10px;
    }

    .status-dot {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background: #4ade80;
      animation: pulse 2s infinite;
    }

    @keyframes pulse {
      0%, 100% {
        opacity: 1;
      }
      50% {
        opacity: 0.5;
      }
    }

    .footer {
      padding: 15px 20px;
      background: rgba(0, 0, 0, 0.2);
      border-top: 1px solid rgba(255, 255, 255, 0.1);
      display: flex;
      justify-content: space-between;
      align-items: center;
      font-size: 12px;
    }

    .logs {
      background: rgba(0, 0, 0, 0.3);
      border-radius: 8px;
      padding: 15px;
      margin-top: 10px;
      max-height: 200px;
      overflow-y: auto;
      font-family: 'Monaco', 'Courier New', monospace;
      font-size: 12px;
    }

    .log-entry {
      padding: 4px 0;
      opacity: 0.8;
    }

    .log-entry.new {
      animation: fadeIn 0.3s ease;
    }

    @keyframes fadeIn {
      from {
        opacity: 0;
        transform: translateX(-10px);
      }
      to {
        opacity: 0.8;
        transform: translateX(0);
      }
    }

    .icon {
      font-size: 24px;
    }
  </style>
</head>
<body>
  <div class="header">
    <h1>⚡ Zyte System Tray App</h1>
    <p class="subtitle">Running in your menubar/system tray</p>
  </div>

  <div class="container">
    <div class="card">
      <h2><span class="icon">📊</span> System Status</h2>
      <p>This app is running in the background with a system tray icon.</p>
      <div class="status">
        <div class="status-dot"></div>
        <span>App is active</span>
      </div>
    </div>

    <div class="card">
      <h2><span class="icon">🔔</span> Notifications</h2>
      <p>Send desktop notifications from the system tray menu.</p>
      <div class="actions">
        <button onclick="sendNotification()">Send Notification</button>
        <button onclick="sendUrgentNotification()">Urgent Alert</button>
      </div>
    </div>

    <div class="card">
      <h2><span class="icon">⚙️</span> Quick Actions</h2>
      <p>Common actions available from the system tray.</p>
      <div class="actions">
        <button onclick="showWindow()">Show Window</button>
        <button onclick="hideWindow()">Hide Window</button>
        <button onclick="toggleAlwaysOnTop()">Toggle On Top</button>
        <button onclick="openSettings()">Settings</button>
      </div>
    </div>

    <div class="card">
      <h2><span class="icon">📝</span> Activity Log</h2>
      <div class="logs" id="logs">
        <div class="log-entry">[${new Date().toLocaleTimeString()}] App started</div>
        <div class="log-entry">[${new Date().toLocaleTimeString()}] System tray icon created</div>
      </div>
    </div>
  </div>

  <div class="footer">
    <span>Zyte System Tray Example</span>
    <span>Press ESC to hide window</span>
  </div>

  <script>
    // Activity logger
    function log(message) {
      const logs = document.getElementById('logs');
      const entry = document.createElement('div');
      entry.className = 'log-entry new';
      entry.textContent = \`[\${new Date().toLocaleTimeString()}] \${message}\`;
      logs.appendChild(entry);
      logs.scrollTop = logs.scrollHeight;
    }

    // Notification functions
    function sendNotification() {
      log('Sending notification...');
      // In a real app, this would call the Zyte notification API
      console.log('Notification sent');
      setTimeout(() => log('Notification delivered'), 100);
    }

    function sendUrgentNotification() {
      log('Sending urgent notification...');
      console.log('Urgent notification sent');
      setTimeout(() => log('Urgent notification delivered'), 100);
    }

    // Window management
    function showWindow() {
      log('Showing window');
      console.log('Show window command');
    }

    function hideWindow() {
      log('Hiding window');
      console.log('Hide window command');
      // In a real app, this would minimize to system tray
    }

    function toggleAlwaysOnTop() {
      log('Toggling always-on-top mode');
      console.log('Toggle always-on-top');
    }

    function openSettings() {
      log('Opening settings...');
      console.log('Open settings');
    }

    // Keyboard shortcuts
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') {
        hideWindow();
      }
    });

    // Simulate some background activity
    let activityCount = 0;
    setInterval(() => {
      activityCount++;
      if (activityCount % 30 === 0) {
        log(\`Background check #\${activityCount / 30} completed\`);
      }
    }, 1000);

    // Log user interactions
    document.querySelectorAll('button').forEach(button => {
      button.addEventListener('click', (e) => {
        if (!e.target.hasAttribute('data-logged')) {
          log(\`User clicked: \${e.target.textContent}\`);
        }
      });
    });
  </script>
</body>
</html>
`

async function main() {
  console.log('🚀 Starting Zyte System Tray App...')
  console.log('')
  console.log('📌 Features:')
  console.log('  • System tray icon')
  console.log('  • Background operation')
  console.log('  • Desktop notifications')
  console.log('  • Quick actions menu')
  console.log('')
  console.log('💡 Tips:')
  console.log('  • Look for the app icon in your system tray/menubar')
  console.log('  • Click the icon to show/hide the window')
  console.log('  • Right-click for quick actions menu')
  console.log('  • Press ESC to hide the window')
  console.log('')

  const app = createApp({
    html,
    window: {
      title: 'Zyte System Tray',
      width: 600,
      height: 700,
      resizable: true,
      systemTray: true,
      darkMode: true,
      devTools: true,
    },
  })

  try {
    await app.show()
    console.log('✅ App closed successfully')
  } catch (error) {
    console.error('❌ Error running app:', error)
    process.exit(1)
  }
}

main()
