#!/usr/bin/env bun
/**
 * Menubar Pomodoro Timer
 *
 * A menubar/system tray Pomodoro timer app built with Craft.
 * Run with: bun run examples/menubar-timer.ts
 *
 * Features:
 * - 25-minute work sessions
 * - 5-minute breaks
 * - Desktop notifications
 * - Minimal menubar UI
 * - Persistent across sessions
 */

import { createApp } from '../packages/typescript/src/index.ts'

const html = `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Pomodoro Timer</title>
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }

    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      background: #1a1a1a;
      color: #ffffff;
      height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 20px;
      overflow: hidden;
    }

    .timer-container {
      text-align: center;
      width: 100%;
      max-width: 400px;
    }

    .mode {
      font-size: 14px;
      text-transform: uppercase;
      letter-spacing: 2px;
      opacity: 0.7;
      margin-bottom: 20px;
      font-weight: 600;
    }

    .mode.work {
      color: #ef4444;
    }

    .mode.break {
      color: #22c55e;
    }

    .timer {
      font-size: 96px;
      font-weight: 300;
      margin: 30px 0;
      font-variant-numeric: tabular-nums;
      letter-spacing: -5px;
    }

    .controls {
      display: flex;
      gap: 15px;
      justify-content: center;
      margin: 30px 0;
    }

    button {
      background: rgba(255, 255, 255, 0.1);
      border: 2px solid rgba(255, 255, 255, 0.2);
      color: white;
      padding: 15px 30px;
      border-radius: 12px;
      font-size: 16px;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.3s ease;
      min-width: 120px;
    }

    button:hover {
      background: rgba(255, 255, 255, 0.2);
      border-color: rgba(255, 255, 255, 0.4);
      transform: translateY(-2px);
    }

    button:active {
      transform: translateY(0);
    }

    button.primary {
      background: #ef4444;
      border-color: #ef4444;
    }

    button.primary:hover {
      background: #dc2626;
      border-color: #dc2626;
    }

    button.secondary {
      background: #3b82f6;
      border-color: #3b82f6;
    }

    button.secondary:hover {
      background: #2563eb;
      border-color: #2563eb;
    }

    .stats {
      margin-top: 40px;
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 20px;
    }

    .stat {
      text-align: center;
      padding: 20px;
      background: rgba(255, 255, 255, 0.05);
      border-radius: 12px;
      border: 1px solid rgba(255, 255, 255, 0.1);
    }

    .stat-value {
      font-size: 32px;
      font-weight: 700;
      margin-bottom: 5px;
    }

    .stat-label {
      font-size: 12px;
      text-transform: uppercase;
      letter-spacing: 1px;
      opacity: 0.6;
    }

    .progress-ring {
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%) rotate(-90deg);
      opacity: 0.1;
    }

    .progress-ring-circle {
      stroke: #ef4444;
      fill: transparent;
      stroke-width: 4;
      stroke-dasharray: 565.48;
      stroke-dashoffset: 565.48;
      transition: stroke-dashoffset 1s linear;
    }

    .settings {
      position: absolute;
      bottom: 20px;
      right: 20px;
      opacity: 0.5;
      transition: opacity 0.3s ease;
    }

    .settings:hover {
      opacity: 1;
    }

    .settings button {
      min-width: auto;
      padding: 10px 15px;
      font-size: 14px;
    }
  </style>
</head>
<body>
  <div class="timer-container">
    <div class="mode work" id="mode">Work Session</div>

    <svg class="progress-ring" width="300" height="300">
      <circle
        class="progress-ring-circle"
        id="progress"
        stroke-width="4"
        fill="transparent"
        r="90"
        cx="150"
        cy="150"
      />
    </svg>

    <div class="timer" id="timer">25:00</div>

    <div class="controls">
      <button class="primary" id="startBtn" onclick="toggleTimer()">Start</button>
      <button class="secondary" onclick="resetTimer()">Reset</button>
      <button onclick="skipSession()">Skip</button>
    </div>

    <div class="stats">
      <div class="stat">
        <div class="stat-value" id="sessionsToday">0</div>
        <div class="stat-label">Today</div>
      </div>
      <div class="stat">
        <div class="stat-value" id="currentStreak">0</div>
        <div class="stat-label">Streak</div>
      </div>
      <div class="stat">
        <div class="stat-value" id="totalSessions">0</div>
        <div class="stat-label">Total</div>
      </div>
    </div>
  </div>

  <div class="settings">
    <button onclick="openSettings()">⚙️ Settings</button>
  </div>

  <script>
    // Timer state
    const WORK_TIME = 25 * 60; // 25 minutes
    const BREAK_TIME = 5 * 60; // 5 minutes

    let timeLeft = WORK_TIME;
    let isRunning = false;
    let isWorkSession = true;
    let interval = null;
    let sessionsToday = 0;
    let currentStreak = 0;
    let totalSessions = 0;

    // Load stats from localStorage
    function loadStats() {
      const saved = localStorage.getItem('pomodoroStats');
      if (saved) {
        const stats = JSON.parse(saved);
        sessionsToday = stats.sessionsToday || 0;
        currentStreak = stats.currentStreak || 0;
        totalSessions = stats.totalSessions || 0;
        updateStats();
      }
    }

    // Save stats to localStorage
    function saveStats() {
      localStorage.setItem('pomodoroStats', JSON.stringify({
        sessionsToday,
        currentStreak,
        totalSessions,
        lastSession: Date.now()
      }));
    }

    // Update stats display
    function updateStats() {
      document.getElementById('sessionsToday').textContent = sessionsToday;
      document.getElementById('currentStreak').textContent = currentStreak;
      document.getElementById('totalSessions').textContent = totalSessions;
    }

    // Format time display
    function formatTime(seconds) {
      const mins = Math.floor(seconds / 60);
      const secs = seconds % 60;
      return \`\${mins}:\${secs.toString().padStart(2, '0')}\`;
    }

    // Update progress ring
    function updateProgress() {
      const maxTime = isWorkSession ? WORK_TIME : BREAK_TIME;
      const progress = (timeLeft / maxTime) * 565.48;
      const circle = document.getElementById('progress');
      circle.style.strokeDashoffset = progress;
    }

    // Update timer display
    function updateDisplay() {
      const timeStr = formatTime(timeLeft);
      document.getElementById('timer').textContent = timeStr;
      updateProgress();

      // Update mode
      const modeEl = document.getElementById('mode');
      if (isWorkSession) {
        modeEl.textContent = 'Work Session';
        modeEl.className = 'mode work';
      } else {
        modeEl.textContent = 'Break Time';
        modeEl.className = 'mode break';
      }

      // Update system tray/menubar title
      const icon = isWorkSession ? '🍅' : '☕';
      if (window.craft && window.craft.tray) {
        window.craft.tray.setTitle(icon + ' ' + timeStr).catch(err => {
          console.log('Tray update error:', err);
        });
      }
    }

    // Start/pause timer
    function toggleTimer() {
      const btn = document.getElementById('startBtn');

      if (isRunning) {
        // Pause
        clearInterval(interval);
        isRunning = false;
        btn.textContent = 'Resume';
        console.log('Timer paused');
      } else {
        // Start/Resume
        isRunning = true;
        btn.textContent = 'Pause';
        console.log('Timer started');

        interval = setInterval(() => {
          timeLeft--;
          updateDisplay();

          if (timeLeft <= 0) {
            completeSession();
          }
        }, 1000);
      }
    }

    // Complete session
    function completeSession() {
      clearInterval(interval);
      isRunning = false;

      if (isWorkSession) {
        // Completed work session
        sessionsToday++;
        currentStreak++;
        totalSessions++;
        saveStats();
        updateStats();

        console.log('Work session completed!');
        showNotification('Great work!', 'Time for a break');

        // Switch to break
        isWorkSession = false;
        timeLeft = BREAK_TIME;
      } else {
        // Completed break
        console.log('Break completed!');
        showNotification('Break over!', 'Ready for another session?');

        // Switch to work
        isWorkSession = true;
        timeLeft = WORK_TIME;
      }

      updateDisplay();
      document.getElementById('startBtn').textContent = 'Start';
    }

    // Reset timer
    function resetTimer() {
      clearInterval(interval);
      isRunning = false;
      timeLeft = isWorkSession ? WORK_TIME : BREAK_TIME;
      updateDisplay();
      document.getElementById('startBtn').textContent = 'Start';
      console.log('Timer reset');
    }

    // Skip session
    function skipSession() {
      clearInterval(interval);
      isRunning = false;

      // Reset streak on skip
      currentStreak = 0;
      saveStats();
      updateStats();

      isWorkSession = !isWorkSession;
      timeLeft = isWorkSession ? WORK_TIME : BREAK_TIME;
      updateDisplay();
      document.getElementById('startBtn').textContent = 'Start';
      console.log('Session skipped');
    }

    // Show notification
    function showNotification(title, body) {
      console.log(\`Notification: \${title} - \${body}\`);
      // In a real app, this would trigger native notifications
    }

    // Settings
    function openSettings() {
      console.log('Opening settings...');
      alert('Settings coming soon!\\n\\nCustomize:\\n• Work duration\\n• Break duration\\n• Notification sounds\\n• Auto-start breaks');
    }

    // Keyboard shortcuts
    document.addEventListener('keydown', (e) => {
      if (e.code === 'Space') {
        e.preventDefault();
        toggleTimer();
      } else if (e.code === 'KeyR') {
        resetTimer();
      } else if (e.code === 'KeyS') {
        skipSession();
      }
    });

    // Initialize
    loadStats();
    updateDisplay();
    console.log('Pomodoro Timer ready!');
    console.log('Shortcuts: Space = Start/Pause, R = Reset, S = Skip');

    // Set up tray menu when craft is ready
    window.addEventListener('craft:ready', function() {
      console.log('Craft bridge ready, setting up tray...');
      if (window.craft && window.craft.tray) {
        // Set initial tray title
        window.craft.tray.setTitle('🍅 25:00');

        // Set up tray context menu
        window.craft.tray.setMenu([
          { label: 'Start/Pause', action: 'toggle' },
          { label: 'Reset', action: 'reset' },
          { type: 'separator' },
          { label: 'Show Window', action: 'show' },
          { type: 'separator' },
          { label: 'Quit', action: 'quit' }
        ]).catch(console.error);
      }
    });

    // Handle tray menu actions
    window.addEventListener('craft:tray:menu', function(e) {
      switch(e.detail.action) {
        case 'toggle':
          toggleTimer();
          break;
        case 'reset':
          resetTimer();
          break;
      }
    });
  </script>
</body>
</html>
`

async function main() {
  console.log('⏱️  Starting Pomodoro Timer...')
  console.log('')
  console.log('📚 What is Pomodoro?')
  console.log('  The Pomodoro Technique uses a timer to break work into intervals,')
  console.log('  traditionally 25 minutes in length, separated by short breaks.')
  console.log('')
  console.log('⌨️  Keyboard Shortcuts:')
  console.log('  • Space: Start/Pause timer')
  console.log('  • R: Reset timer')
  console.log('  • S: Skip session')
  console.log('  • ESC: Hide window (stays in menubar)')
  console.log('')

  const app = createApp({
    html,
    window: {
      title: 'Pomodoro Timer',
      width: 500,
      height: 600,
      resizable: false,
      systemTray: true,
      alwaysOnTop: true,
      darkMode: true,
    },
  })

  try {
    await app.show()
    console.log('✅ Timer closed')
  } catch (error) {
    console.error('❌ Error:', error)
    process.exit(1)
  }
}

main()
