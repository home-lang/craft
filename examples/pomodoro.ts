#!/usr/bin/env bun
/**
 * Minimal Pomodoro Timer for Menubar
 *
 * A clean, functional Pomodoro timer that lives in your menubar.
 * The timer is shown in the window title (which appears in the menubar).
 *
 * Run with: bun examples/pomodoro.ts
 *
 * Features:
 * - Timer display in menubar (via window title + system tray API)
 * - 25-minute work sessions
 * - 5-minute breaks
 * - Desktop notifications
 * - Keyboard shortcuts
 * - Session statistics
 * - Persistent state
 */

import { createApp } from '../packages/typescript/src/index.ts'
import type { ZyteBridgeAPI } from '../packages/typescript/src/types.ts'

// Extend window interface for TypeScript
declare global {
  interface Window {
    zyte: ZyteBridgeAPI
  }
}

const html = `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>🍅 25:00</title>

  <script>
    // Initialize the Pomodoro menu when the Zyte bridge is ready
    // This is defined in <head> to ensure it runs (WKWebView body scripts can be unreliable)
    window.initializeZyteApp = function() {
      if (window.zyte?.tray) {
        window.zyte.tray.setMenu([
          { label: 'Start Timer', action: 'toggle-timer' },
          { label: 'Reset Timer', action: 'reset-timer' },
          { label: 'Skip Session', action: 'skip-session' },
          { type: 'separator' },
          { label: 'Show Window', action: 'show' },
          { label: 'Quit', action: 'quit' }
        ]);
      }
    };
  </script>

  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
      -webkit-user-select: none;
      user-select: none;
    }

    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: #ffffff;
      height: 100vh;
      display: flex;
      flex-direction: column;
      overflow: hidden;
    }

    .container {
      flex: 1;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 20px;
    }

    .mode-indicator {
      font-size: 13px;
      text-transform: uppercase;
      letter-spacing: 2px;
      opacity: 0.8;
      margin-bottom: 15px;
      font-weight: 600;
      transition: all 0.3s ease;
    }

    .mode-indicator.work {
      color: #fef3c7;
    }

    .mode-indicator.break {
      color: #d1fae5;
    }

    .timer-display {
      font-size: 72px;
      font-weight: 200;
      margin: 20px 0;
      font-variant-numeric: tabular-nums;
      letter-spacing: -3px;
      text-shadow: 0 4px 20px rgba(0, 0, 0, 0.2);
    }

    .controls {
      display: flex;
      gap: 12px;
      margin: 25px 0;
    }

    button {
      background: rgba(255, 255, 255, 0.15);
      border: 2px solid rgba(255, 255, 255, 0.3);
      color: white;
      padding: 12px 28px;
      border-radius: 10px;
      font-size: 15px;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.2s ease;
      backdrop-filter: blur(10px);
    }

    button:hover {
      background: rgba(255, 255, 255, 0.25);
      border-color: rgba(255, 255, 255, 0.5);
      transform: translateY(-1px);
    }

    button:active {
      transform: translateY(0);
    }

    button.primary {
      background: rgba(239, 68, 68, 0.9);
      border-color: rgba(239, 68, 68, 1);
    }

    button.primary:hover {
      background: rgba(220, 38, 38, 0.95);
    }

    button:disabled {
      opacity: 0.5;
      cursor: not-allowed;
    }

    .stats {
      display: flex;
      gap: 30px;
      margin-top: 30px;
    }

    .stat {
      text-align: center;
    }

    .stat-value {
      font-size: 28px;
      font-weight: 700;
      margin-bottom: 3px;
    }

    .stat-label {
      font-size: 11px;
      text-transform: uppercase;
      letter-spacing: 1px;
      opacity: 0.7;
    }

    .footer {
      padding: 15px;
      text-align: center;
      font-size: 11px;
      opacity: 0.6;
      background: rgba(0, 0, 0, 0.1);
    }

    .shortcut {
      display: inline-block;
      background: rgba(255, 255, 255, 0.2);
      padding: 2px 6px;
      border-radius: 3px;
      margin: 0 2px;
      font-weight: 600;
    }

    @keyframes pulse {
      0%, 100% { opacity: 1; }
      50% { opacity: 0.6; }
    }

    .timer-display.running {
      animation: pulse 2s infinite;
    }

    .notification {
      position: fixed;
      top: 20px;
      left: 50%;
      transform: translateX(-50%) translateY(-100px);
      background: rgba(0, 0, 0, 0.9);
      color: white;
      padding: 15px 25px;
      border-radius: 8px;
      font-size: 14px;
      font-weight: 500;
      opacity: 0;
      transition: all 0.3s ease;
      pointer-events: none;
      z-index: 1000;
    }

    .notification.show {
      transform: translateX(-50%) translateY(0);
      opacity: 1;
    }
  </style>
</head>
<body>
  <div class="notification" id="notification"></div>

  <div class="container">
    <div class="mode-indicator work" id="mode">Work Session</div>

    <div class="timer-display" id="timer">25:00</div>

    <div class="controls">
      <button class="primary" id="toggleBtn" onclick="toggleTimer()">Start</button>
      <button onclick="resetTimer()">Reset</button>
      <button onclick="skipSession()">Skip</button>
    </div>

    <div class="stats">
      <div class="stat">
        <div class="stat-value" id="completedToday">0</div>
        <div class="stat-label">Today</div>
      </div>
      <div class="stat">
        <div class="stat-value" id="currentStreak">0</div>
        <div class="stat-label">Streak</div>
      </div>
      <div class="stat">
        <div class="stat-value" id="totalCompleted">0</div>
        <div class="stat-label">Total</div>
      </div>
    </div>
  </div>

  <div class="footer">
    <span class="shortcut">Space</span> Start/Pause
    <span class="shortcut">R</span> Reset
    <span class="shortcut">S</span> Skip
    <span class="shortcut">⌘H</span> Hide
  </div>

  <script>
    // Debug: Verify script is loading
    if (window.webkit?.messageHandlers?.zyteBridge) {
      window.webkit.messageHandlers.zyteBridge.postMessage({
        type: 'debug',
        message: 'Pomodoro script started loading'
      });
    }

    // Configuration
    const WORK_DURATION = 25 * 60; // 25 minutes
    const BREAK_DURATION = 5 * 60; // 5 minutes
    const STORAGE_KEY = 'zyte_pomodoro';

    // State
    let timeRemaining = WORK_DURATION;
    let isRunning = false;
    let isWorkSession = true;
    let timerInterval = null;

    // Stats
    let stats = {
      completedToday: 0,
      currentStreak: 0,
      totalCompleted: 0,
      lastSessionDate: null
    };

    // Load saved stats
    function loadStats() {
      try {
        const saved = localStorage.getItem(STORAGE_KEY);
        if (saved) {
          const data = JSON.parse(saved);
          stats = data;

          // Reset daily count if it's a new day
          const lastDate = new Date(stats.lastSessionDate);
          const today = new Date();
          if (lastDate.toDateString() !== today.toDateString()) {
            stats.completedToday = 0;
          }

          updateStatsDisplay();
        }
      } catch (e) {
        console.error('Failed to load stats:', e);
      }
    }

    // Save stats
    function saveStats() {
      try {
        localStorage.setItem(STORAGE_KEY, JSON.stringify(stats));
      } catch (e) {
        console.error('Failed to save stats:', e);
      }
    }

    // Update stats display
    function updateStatsDisplay() {
      document.getElementById('completedToday').textContent = stats.completedToday;
      document.getElementById('currentStreak').textContent = stats.currentStreak;
      document.getElementById('totalCompleted').textContent = stats.totalCompleted;
    }

    // Format time
    function formatTime(seconds) {
      const mins = Math.floor(seconds / 60);
      const secs = seconds % 60;
      return \`\${mins}:\${secs.toString().padStart(2, '0')}\`;
    }

    // Update window title (appears in menubar)
    function updateTitle() {
      const emoji = isWorkSession ? '🍅' : '☕';
      const time = formatTime(timeRemaining);
      const title = \`\${emoji} \${time}\`;

      // Update both window title and menubar (if system tray is enabled)
      document.title = title;

      // Update menubar via Zyte API if available
      if (window.zyte?.tray) {
        window.zyte.tray.setTitle(title);

        // Also update tooltip with session info
        const sessionType = isWorkSession ? 'Work Session' : 'Break Time';
        const statusText = isRunning ? 'Running' : 'Paused';
        window.zyte.tray.setTooltip(\`Pomodoro Timer - \${sessionType} (\${statusText})\`);
      }
    }

    // Update display
    function updateDisplay() {
      const timerEl = document.getElementById('timer');
      const modeEl = document.getElementById('mode');
      const toggleBtn = document.getElementById('toggleBtn');

      // Update timer text
      timerEl.textContent = formatTime(timeRemaining);

      // Update running animation
      if (isRunning) {
        timerEl.classList.add('running');
      } else {
        timerEl.classList.remove('running');
      }

      // Update mode indicator
      if (isWorkSession) {
        modeEl.textContent = 'Work Session';
        modeEl.className = 'mode-indicator work';
      } else {
        modeEl.textContent = 'Break Time';
        modeEl.className = 'mode-indicator break';
      }

      // Update button text
      toggleBtn.textContent = isRunning ? 'Pause' : 'Start';

      // Update window title
      updateTitle();
    }

    // Show notification
    function showNotification(message) {
      const notif = document.getElementById('notification');
      notif.textContent = message;
      notif.classList.add('show');

      setTimeout(() => {
        notif.classList.remove('show');
      }, 3000);

      console.log(\`[Notification] \${message}\`);
    }

    // Toggle timer
    function toggleTimer() {
      if (isRunning) {
        // Pause
        clearInterval(timerInterval);
        isRunning = false;
        console.log('Timer paused');
      } else {
        // Start
        isRunning = true;
        console.log('Timer started');

        timerInterval = setInterval(() => {
          timeRemaining--;
          updateDisplay();

          if (timeRemaining <= 0) {
            completeSession();
          } else if (timeRemaining <= 10 && timeRemaining > 0) {
            // Optional: beep in last 10 seconds
            console.log(\`⏰ \${timeRemaining} seconds remaining\`);
          }
        }, 1000);
      }

      updateDisplay();
      updateMenuLabels(); // Update menu to show correct label
    }

    // Complete session
    function completeSession() {
      clearInterval(timerInterval);
      isRunning = false;

      if (isWorkSession) {
        // Completed work session
        stats.completedToday++;
        stats.currentStreak++;
        stats.totalCompleted++;
        stats.lastSessionDate = new Date().toISOString();
        saveStats();
        updateStatsDisplay();

        showNotification('🎉 Work session complete! Time for a break.');
        console.log(\`✅ Session #\${stats.totalCompleted} completed!\`);

        // Switch to break
        isWorkSession = false;
        timeRemaining = BREAK_DURATION;
      } else {
        // Completed break
        showNotification('✨ Break over! Ready for another session?');
        console.log('Break completed');

        // Switch to work
        isWorkSession = true;
        timeRemaining = WORK_DURATION;
      }

      updateDisplay();
      updateMenuLabels(); // Update menu after session completes
    }

    // Reset timer
    function resetTimer() {
      clearInterval(timerInterval);
      isRunning = false;
      timeRemaining = isWorkSession ? WORK_DURATION : BREAK_DURATION;
      updateDisplay();
      updateMenuLabels(); // Update menu after reset
      console.log('Timer reset');
    }

    // Skip session
    function skipSession() {
      clearInterval(timerInterval);
      isRunning = false;

      // Penalty: reset streak
      if (isWorkSession) {
        stats.currentStreak = 0;
        saveStats();
        updateStatsDisplay();
        console.log('Work session skipped - streak reset');
      }

      // Toggle session type
      isWorkSession = !isWorkSession;
      timeRemaining = isWorkSession ? WORK_DURATION : BREAK_DURATION;
      updateDisplay();
      updateMenuLabels(); // Update menu after skip

      showNotification('⏭️ Session skipped');
    }

    // Keyboard shortcuts
    document.addEventListener('keydown', (e) => {
      // Prevent default for our shortcuts
      if (e.code === 'Space' || e.code === 'KeyR' || e.code === 'KeyS') {
        e.preventDefault();
      }

      if (e.code === 'Space') {
        toggleTimer();
      } else if (e.code === 'KeyR' && !isRunning) {
        resetTimer();
      } else if (e.code === 'KeyS') {
        skipSession();
      } else if ((e.metaKey || e.ctrlKey) && e.code === 'KeyH') {
        e.preventDefault();
        console.log('Hide window (minimize to menubar)');
        if (window.zyte?.window) {
          window.zyte.window.hide();
          isWindowVisible = false;
          updateMenuLabels();
        }
      }
    });

    // Prevent accidental refresh
    window.addEventListener('beforeunload', (e) => {
      if (isRunning) {
        e.preventDefault();
        e.returnValue = '';
        return 'Timer is running. Are you sure you want to close?';
      }
    });

    // Visibility change (when window is hidden/shown)
    document.addEventListener('visibilitychange', () => {
      if (document.hidden) {
        console.log('Window hidden - timer continues in background');
      } else {
        console.log('Window visible');
        updateDisplay(); // Refresh display
      }
    });

    // Set a global flag that the listener is ready
    window.zyte_menu_listener_ready = true;
    console.log('[Pomodoro] Menu listener registered');

    // Create a global handler function that can be called directly
    window.handleMenuAction = function(action) {
      console.log('[Pomodoro] handleMenuAction called with:', action);

      switch (action) {
        case 'toggle-timer':
          console.log('[Pomodoro] Toggling timer from menu');
          toggleTimer();
          updateMenuLabels();
          break;
        case 'reset-timer':
          console.log('[Pomodoro] Resetting timer from menu');
          resetTimer();
          break;
        case 'skip-session':
          console.log('[Pomodoro] Skipping session from menu');
          skipSession();
          break;
        case 'hide':
          console.log('[Pomodoro] Hiding window from menu');
          isWindowVisible = false;
          updateMenuLabels();
          break;
        case 'show':
          console.log('[Pomodoro] Showing window from menu');
          isWindowVisible = true;
          updateMenuLabels();
          break;
        case 'about':
          console.log('[Pomodoro] Showing about dialog');
          showAbout();
          break;
      }
    };

    // Handle custom menu actions via event
    window.addEventListener('zyte:tray:menuAction', (event) => {
      const action = event.detail.action;
      console.log('[Pomodoro] Received menu action event:', action);
      window.handleMenuAction(action);
    });

    // Also listen for postMessage from native code
    window.addEventListener('message', (event) => {
      if (event.data && event.data.type === 'menuAction') {
        console.log('[Pomodoro] Received postMessage menu action:', event.data.action);
        window.handleMenuAction(event.data.action);
      }
    });

    // FINAL WORKAROUND: Poll for tooltip changes to detect menu actions
    // evaluateJavaScript doesn't work, so we use tooltip as a communication channel
    let lastTooltipCheck = '';
    setInterval(() => {
      if (window.zyte?.tray) {
        // We can't READ the tooltip, so this won't work either...
        // Actually, let's try a different approach - just poll document.title
        const currentTitle = document.title;
        if (currentTitle.startsWith('__MENU_ACTION__:')) {
          const action = currentTitle.substring('__MENU_ACTION__:'.length);
          if (action !== lastTooltipCheck) {
            console.log('[Pomodoro] Detected menu action via polling:', action);
            window.handleMenuAction(action);
            lastTooltipCheck = action;
          }
        }
      }
    }, 100); // Poll every 100ms

    // Initialize
    loadStats();
    updateDisplay();

    console.log('🍅 Pomodoro Timer Ready!');
    console.log('Controls:');
    console.log('  Space: Start/Pause');
    console.log('  R: Reset');
    console.log('  S: Skip');
    console.log('  ⌘H: Hide window');
    console.log('');
    console.log('The timer is displayed in the menubar (window title)');

    // Track window visibility state
    let isWindowVisible = true;

    // Show About dialog
    function showAbout() {
      const aboutMessage = \`Pomodoro Timer for Menubar

A clean, functional Pomodoro timer built with Zyte.

Version: 1.0.0
Work Session: 25 minutes
Break Duration: 5 minutes

Built with ❤️ using Zyte Framework
https://github.com/stacksjs/zyte\`;

      if (window.zyte?.window) {
        // Show alert dialog
        window.zyte.window.alert(aboutMessage);
      } else {
        alert(aboutMessage);
      }
    }

    // Function to update menu labels dynamically
    function updateMenuLabels() {
      if (window.zyte?.tray) {
        const menuItems = [
          {
            label: isRunning ? 'Pause Timer' : 'Start Timer',
            id: 'toggle',
            action: 'toggle-timer'
          },
          {
            label: 'Reset Timer',
            id: 'reset',
            action: 'reset-timer'
          },
          {
            label: 'Skip Session',
            id: 'skip',
            action: 'skip-session'
          },
          { type: 'separator' }
        ];

        // Add either Show or Hide based on current visibility
        if (isWindowVisible) {
          menuItems.push({
            label: 'Hide Window',
            action: 'hide'
          });
        } else {
          menuItems.push({
            label: 'Show Window',
            action: 'show'
          });
        }

        menuItems.push(
          { type: 'separator' },
          {
            label: 'About',
            action: 'about'
          },
          { type: 'separator' },
          {
            label: 'Quit',
            action: 'quit',
            shortcut: 'Cmd+Q'
          }
        );

        window.zyte.tray.setMenu(menuItems);
      }
    }

    // Setup menubar menu - called after bridge is ready
    function setupPomodoroMenu() {
      console.log('[Pomodoro] setupPomodoroMenu() called');
      console.log('[Pomodoro] window.zyte:', !!window.zyte);
      console.log('[Pomodoro] window.zyte.tray:', !!window.zyte?.tray);

      if (window.zyte?.tray) {
        console.log('[Pomodoro] Setting up menu via window.zyte.tray');
        updateMenuLabels();
      } else {
        console.error('[Pomodoro] ERROR: window.zyte.tray is not available!');
      }
    }

    // Wait for the Zyte bridge to be ready (normal case when body scripts execute)
    window.addEventListener('zyte:ready', () => {
      console.log('[Pomodoro] Zyte bridge ready - initializing menu');
      setupPomodoroMenu();
    });
  </script>
</body>
</html>
`

async function main() {
  console.log('🍅 Starting Pomodoro Timer...')
  console.log('')
  console.log('⏱️  Timer Configuration:')
  console.log('  • Work: 25 minutes')
  console.log('  • Break: 5 minutes')
  console.log('  • Timer shown in menubar (window title)')
  console.log('')
  console.log('⌨️  Keyboard Shortcuts:')
  console.log('  • Space: Start/Pause')
  console.log('  • R: Reset')
  console.log('  • S: Skip session')
  console.log('  • ⌘H: Hide window')
  console.log('')
  console.log('💡 The timer will appear in your menubar!')
  console.log('   Look for: 🍅 25:00 (work) or ☕ 5:00 (break)')
  console.log('')

  const app = createApp({
    html,
    window: {
      title: '🍅 25:00',
      width: 380,
      height: 480,
      resizable: false,
      systemTray: true,
      hideDockIcon: true,  // Run as menubar-only app
      alwaysOnTop: true,
      darkMode: true,
    },
  })

  try {
    await app.show()
    console.log('\n✅ Pomodoro timer closed')
  } catch (error) {
    console.error('\n❌ Error:', error)
    process.exit(1)
  }
}

main()
