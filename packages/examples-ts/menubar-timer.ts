/**
 * Menubar Timer Example
 * A Pomodoro-style timer that lives in the menubar
 *
 * Features:
 * - Menubar-only app (no dock icon)
 * - Real-time title updates
 * - Context menu with controls
 * - Optional popup window
 */

import { createApp } from '@stacksjs/ts-craft'

// Timer state
let seconds = 25 * 60 // 25 minutes
let isRunning = false
let intervalId: ReturnType<typeof setInterval> | null = null

// Format time as MM:SS
function formatTime(secs: number): string {
  const m = Math.floor(secs / 60)
  const s = secs % 60
  return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`
}

// The popup window HTML
const popupHtml = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }

    body {
      font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif;
      background: rgba(30, 30, 30, 0.95);
      color: white;
      height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      -webkit-app-region: drag;
      user-select: none;
    }

    .timer {
      font-size: 4rem;
      font-weight: 200;
      font-variant-numeric: tabular-nums;
      letter-spacing: -2px;
      margin-bottom: 2rem;
    }

    .controls {
      display: flex;
      gap: 1rem;
      -webkit-app-region: no-drag;
    }

    button {
      padding: 0.75rem 2rem;
      font-size: 1rem;
      font-weight: 500;
      border: none;
      border-radius: 8px;
      cursor: pointer;
      transition: all 0.2s;
    }

    .primary {
      background: #ef4444;
      color: white;
    }
    .primary:hover { background: #dc2626; }
    .primary.running { background: #22c55e; }
    .primary.running:hover { background: #16a34a; }

    .secondary {
      background: rgba(255, 255, 255, 0.1);
      color: white;
    }
    .secondary:hover { background: rgba(255, 255, 255, 0.2); }

    .presets {
      margin-top: 2rem;
      display: flex;
      gap: 0.5rem;
      -webkit-app-region: no-drag;
    }

    .preset {
      padding: 0.5rem 1rem;
      font-size: 0.875rem;
      background: rgba(255, 255, 255, 0.05);
      color: rgba(255, 255, 255, 0.6);
      border: 1px solid rgba(255, 255, 255, 0.1);
      border-radius: 6px;
      cursor: pointer;
      transition: all 0.2s;
    }
    .preset:hover {
      background: rgba(255, 255, 255, 0.1);
      color: white;
    }

    .status {
      margin-top: 1.5rem;
      font-size: 0.875rem;
      color: rgba(255, 255, 255, 0.5);
    }
  </style>
</head>
<body>
  <div class="timer" id="timer">25:00</div>

  <div class="controls">
    <button class="primary" id="toggle">Start</button>
    <button class="secondary" id="reset">Reset</button>
  </div>

  <div class="presets">
    <button class="preset" data-time="1500">25 min</button>
    <button class="preset" data-time="300">5 min</button>
    <button class="preset" data-time="900">15 min</button>
    <button class="preset" data-time="3600">60 min</button>
  </div>

  <div class="status" id="status">Focus time</div>

  <script>
    const timerEl = document.getElementById('timer');
    const toggleBtn = document.getElementById('toggle');
    const resetBtn = document.getElementById('reset');
    const statusEl = document.getElementById('status');
    const presets = document.querySelectorAll('.preset');

    let seconds = 25 * 60;
    let isRunning = false;
    let intervalId = null;

    function formatTime(secs) {
      const m = Math.floor(secs / 60);
      const s = secs % 60;
      return m.toString().padStart(2, '0') + ':' + s.toString().padStart(2, '0');
    }

    function updateDisplay() {
      timerEl.textContent = formatTime(seconds);

      // Update menubar title via Craft API
      if (window.craft?.tray?.setTitle) {
        const emoji = isRunning ? '🍅' : '⏸️';
        window.craft.tray.setTitle(emoji + ' ' + formatTime(seconds));
      }
    }

    function tick() {
      if (seconds > 0) {
        seconds--;
        updateDisplay();
      } else {
        stop();
        statusEl.textContent = 'Time\\'s up!';
        // Send notification
        if (window.craft?.app?.notify) {
          window.craft.app.notify({
            title: 'Timer Complete',
            body: 'Your focus session is complete!',
            sound: 'default'
          });
        }
      }
    }

    function start() {
      isRunning = true;
      toggleBtn.textContent = 'Pause';
      toggleBtn.classList.add('running');
      statusEl.textContent = 'Focusing...';
      intervalId = setInterval(tick, 1000);
      updateDisplay();
    }

    function stop() {
      isRunning = false;
      toggleBtn.textContent = 'Start';
      toggleBtn.classList.remove('running');
      statusEl.textContent = 'Paused';
      if (intervalId) {
        clearInterval(intervalId);
        intervalId = null;
      }
      updateDisplay();
    }

    function reset() {
      stop();
      seconds = 25 * 60;
      statusEl.textContent = 'Focus time';
      updateDisplay();
    }

    toggleBtn.addEventListener('click', () => {
      if (isRunning) stop();
      else start();
    });

    resetBtn.addEventListener('click', reset);

    presets.forEach(btn => {
      btn.addEventListener('click', () => {
        stop();
        seconds = parseInt(btn.dataset.time);
        statusEl.textContent = 'Focus time';
        updateDisplay();
      });
    });

    // Initial display
    updateDisplay();

    // Listen for menu actions
    window.addEventListener('craft:tray:menu', (e) => {
      switch (e.detail.action) {
        case 'start': start(); break;
        case 'pause': stop(); break;
        case 'reset': reset(); break;
      }
    });
  </script>
</body>
</html>
`

const app = createApp({
  html: popupHtml,
  window: {
    title: 'Pomodoro Timer',
    width: 320,
    height: 380,
    resizable: false,
    frameless: true,
    transparent: true,
    alwaysOnTop: true,
    // Menubar-specific options
    systemTray: true,
    hideDockIcon: true,
    titlebarHidden: true,
  },
})

await app.show()
