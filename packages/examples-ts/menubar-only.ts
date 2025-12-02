/**
 * Menubar-Only Example
 * A minimal menubar app with no window - just a tray icon and menu
 *
 * Use cases:
 * - System utilities
 * - Status monitors
 * - Quick launchers
 * - Background services
 */

import { createApp } from 'ts-craft'

// Minimal HTML just for the JavaScript runtime
// The actual UI is the native menu
const html = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Menubar App</title>
</head>
<body>
  <script>
    // App state
    let cpuUsage = 0;
    let memUsage = 0;
    let isMonitoring = true;

    // Simulated system stats (in real app, use native APIs)
    function updateStats() {
      cpuUsage = Math.floor(Math.random() * 30 + 10);
      memUsage = Math.floor(Math.random() * 20 + 40);

      // Update menubar title
      if (window.craft?.tray?.setTitle) {
        window.craft.tray.setTitle('CPU ' + cpuUsage + '% | RAM ' + memUsage + '%');
      }
    }

    // Update menu with current stats
    function updateMenu() {
      if (window.craft?.tray?.setMenu) {
        window.craft.tray.setMenu([
          { label: 'System Monitor', enabled: false },
          { type: 'separator' },
          { label: 'CPU: ' + cpuUsage + '%', enabled: false },
          { label: 'Memory: ' + memUsage + '%', enabled: false },
          { type: 'separator' },
          {
            label: isMonitoring ? '⏸ Pause Monitoring' : '▶ Resume Monitoring',
            action: 'toggle-monitoring'
          },
          { label: '🔄 Refresh Now', action: 'refresh' },
          { type: 'separator' },
          {
            label: 'Update Interval',
            submenu: [
              { label: '1 second', action: 'interval-1' },
              { label: '5 seconds', action: 'interval-5', checked: true },
              { label: '10 seconds', action: 'interval-10' },
            ]
          },
          { type: 'separator' },
          { label: 'About System Monitor', action: 'about' },
          { label: 'Quit', action: 'quit' }
        ]);
      }
    }

    // Handle menu actions
    window.addEventListener('craft:tray:menu', (e) => {
      switch (e.detail.action) {
        case 'toggle-monitoring':
          isMonitoring = !isMonitoring;
          updateMenu();
          break;
        case 'refresh':
          updateStats();
          updateMenu();
          break;
        case 'about':
          if (window.craft?.app?.notify) {
            window.craft.app.notify({
              title: 'System Monitor',
              body: 'A simple menubar app built with Craft'
            });
          }
          break;
        case 'interval-1':
        case 'interval-5':
        case 'interval-10':
          // Would update interval here
          console.log('Interval changed:', e.detail.action);
          break;
      }
    });

    // Initial setup
    updateStats();
    updateMenu();

    // Update every 5 seconds
    setInterval(() => {
      if (isMonitoring) {
        updateStats();
        updateMenu();
      }
    }, 5000);

    console.log('[System Monitor] Started - running in menubar only');
  </script>
</body>
</html>
`

const app = createApp({
  html,
  window: {
    title: 'System Monitor',
    width: 1,
    height: 1,
    // Menubar-only mode
    menubarOnly: true,
    systemTray: true,
    hideDockIcon: true,
  },
})

await app.show()
