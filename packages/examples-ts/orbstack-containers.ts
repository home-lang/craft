/**
 * OrbStack Containers Style Example
 * A container management UI with OrbStack's minimal dark sidebar
 *
 * Features:
 * - Dark #1a1a1a background
 * - Status indicators (running, stopped, warning)
 * - Section counts
 * - Monospace metadata
 */

import { createApp } from 'ts-craft'

const html = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Containers</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }

    body {
      font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif;
      height: 100vh;
      display: flex;
      background: #111;
      color: white;
      overflow: hidden;
    }

    /* ==================== SIDEBAR ==================== */
    .sidebar {
      width: 220px;
      height: 100%;
      display: flex;
      flex-direction: column;
      background: #1a1a1a;
      border-right: 1px solid rgba(255, 255, 255, 0.06);
      user-select: none;
    }

    /* Window drag area */
    .drag-area {
      height: 38px;
      -webkit-app-region: drag;
    }

    /* Search */
    .search {
      margin: 0 0.5rem 0.5rem;
      padding: 0.5rem 0.625rem;
      background: rgba(255, 255, 255, 0.05);
      border-radius: 4px;
      display: flex;
      align-items: center;
      gap: 0.5rem;
    }

    .search .icon {
      color: rgba(255, 255, 255, 0.35);
      font-size: 12px;
    }

    .search input {
      flex: 1;
      background: none;
      border: none;
      color: white;
      font-size: 12px;
      outline: none;
    }

    .search input::placeholder {
      color: rgba(255, 255, 255, 0.3);
    }

    /* Sections */
    .items-container {
      flex: 1;
      overflow-y: auto;
      padding: 0 0.5rem;
    }

    .items-container::-webkit-scrollbar {
      width: 4px;
    }

    .items-container::-webkit-scrollbar-thumb {
      background: rgba(255, 255, 255, 0.1);
      border-radius: 2px;
    }

    .section {
      margin-bottom: 0.75rem;
    }

    .section-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 0.5rem;
      font-size: 11px;
      font-weight: 500;
      color: rgba(255, 255, 255, 0.35);
      text-transform: uppercase;
      letter-spacing: 0.3px;
    }

    .section-header .count {
      background: rgba(255, 255, 255, 0.08);
      padding: 0.125rem 0.375rem;
      border-radius: 4px;
      font-size: 10px;
    }

    .item {
      display: flex;
      align-items: center;
      gap: 0.5rem;
      padding: 0.375rem 0.5rem;
      margin: 1px 0;
      border-radius: 4px;
      cursor: pointer;
      transition: background 0.1s ease;
      font-size: 13px;
      color: rgba(255, 255, 255, 0.75);
    }

    .item:hover {
      background: rgba(255, 255, 255, 0.06);
    }

    .item.selected {
      background: rgba(255, 255, 255, 0.1);
      color: white;
    }

    .item .status {
      width: 6px;
      height: 6px;
      border-radius: 50%;
      flex-shrink: 0;
    }

    .item .status.running { background: #22c55e; }
    .item .status.stopped { background: #6b7280; }
    .item .status.warning { background: #f59e0b; }
    .item .status.error { background: #ef4444; }

    .item .name {
      flex: 1;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    .item .meta {
      font-size: 11px;
      color: rgba(255, 255, 255, 0.35);
      font-family: 'SF Mono', 'Menlo', 'Consolas', monospace;
    }

    /* Footer actions */
    .footer {
      padding: 0.75rem 0.5rem;
      border-top: 1px solid rgba(255, 255, 255, 0.06);
    }

    .footer-btn {
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 0.5rem;
      padding: 0.5rem;
      border-radius: 4px;
      background: rgba(255, 255, 255, 0.06);
      color: rgba(255, 255, 255, 0.6);
      font-size: 12px;
      cursor: pointer;
      transition: all 0.15s;
    }

    .footer-btn:hover {
      background: rgba(255, 255, 255, 0.1);
      color: white;
    }

    /* ==================== MAIN CONTENT ==================== */
    .main {
      flex: 1;
      display: flex;
      flex-direction: column;
      background: #111;
    }

    /* Header */
    .header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 1rem 1.5rem;
      border-bottom: 1px solid rgba(255, 255, 255, 0.06);
      -webkit-app-region: drag;
    }

    .header-left {
      display: flex;
      align-items: center;
      gap: 1rem;
    }

    .header h1 {
      font-size: 1.25rem;
      font-weight: 600;
    }

    .header .badge {
      padding: 0.25rem 0.5rem;
      background: rgba(34, 197, 94, 0.2);
      color: #22c55e;
      font-size: 11px;
      font-weight: 500;
      border-radius: 4px;
    }

    .header-actions {
      display: flex;
      gap: 0.5rem;
      -webkit-app-region: no-drag;
    }

    .action-btn {
      padding: 0.5rem 1rem;
      background: rgba(255, 255, 255, 0.08);
      border-radius: 6px;
      font-size: 12px;
      color: rgba(255, 255, 255, 0.8);
      cursor: pointer;
      transition: all 0.15s;
      border: none;
    }

    .action-btn:hover {
      background: rgba(255, 255, 255, 0.12);
      color: white;
    }

    .action-btn.primary {
      background: #22c55e;
      color: white;
    }

    .action-btn.primary:hover {
      background: #16a34a;
    }

    .action-btn.danger {
      background: rgba(239, 68, 68, 0.2);
      color: #ef4444;
    }

    .action-btn.danger:hover {
      background: rgba(239, 68, 68, 0.3);
    }

    /* Content area */
    .content {
      flex: 1;
      padding: 1.5rem;
      overflow: auto;
    }

    /* Info panels */
    .info-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
      gap: 1rem;
      margin-bottom: 1.5rem;
    }

    .info-card {
      background: rgba(255, 255, 255, 0.03);
      border: 1px solid rgba(255, 255, 255, 0.06);
      border-radius: 8px;
      padding: 1rem;
    }

    .info-card .label {
      font-size: 11px;
      color: rgba(255, 255, 255, 0.4);
      text-transform: uppercase;
      letter-spacing: 0.5px;
      margin-bottom: 0.5rem;
    }

    .info-card .value {
      font-size: 1.5rem;
      font-weight: 600;
    }

    .info-card .value.green { color: #22c55e; }
    .info-card .value.yellow { color: #f59e0b; }
    .info-card .value.red { color: #ef4444; }

    /* Logs */
    .logs-section h2 {
      font-size: 0.875rem;
      font-weight: 500;
      color: rgba(255, 255, 255, 0.6);
      margin-bottom: 0.75rem;
    }

    .logs {
      background: rgba(0, 0, 0, 0.4);
      border-radius: 6px;
      padding: 1rem;
      font-family: 'SF Mono', 'Menlo', 'Consolas', monospace;
      font-size: 12px;
      line-height: 1.6;
      max-height: 300px;
      overflow: auto;
    }

    .logs::-webkit-scrollbar {
      width: 6px;
    }

    .logs::-webkit-scrollbar-thumb {
      background: rgba(255, 255, 255, 0.1);
      border-radius: 3px;
    }

    .log-line {
      display: flex;
      gap: 1rem;
    }

    .log-time {
      color: rgba(255, 255, 255, 0.3);
      flex-shrink: 0;
    }

    .log-msg {
      color: rgba(255, 255, 255, 0.7);
    }

    .log-msg.info { color: #3b82f6; }
    .log-msg.success { color: #22c55e; }
    .log-msg.warning { color: #f59e0b; }
    .log-msg.error { color: #ef4444; }
  </style>
</head>
<body>
  <aside class="sidebar">
    <div class="drag-area"></div>

    <div class="search">
      <span class="icon">🔍</span>
      <input type="text" placeholder="Filter...">
    </div>

    <div class="items-container">
      <div class="section">
        <div class="section-header">
          <span>Machines</span>
          <span class="count">3</span>
        </div>
        <div class="item selected" onclick="selectItem(this, 'ubuntu')">
          <span class="status running"></span>
          <span class="name">ubuntu</span>
          <span class="meta">arm64</span>
        </div>
        <div class="item" onclick="selectItem(this, 'debian')">
          <span class="status running"></span>
          <span class="name">debian</span>
          <span class="meta">arm64</span>
        </div>
        <div class="item" onclick="selectItem(this, 'fedora')">
          <span class="status stopped"></span>
          <span class="name">fedora</span>
          <span class="meta">arm64</span>
        </div>
      </div>

      <div class="section">
        <div class="section-header">
          <span>Containers</span>
          <span class="count">6</span>
        </div>
        <div class="item" onclick="selectItem(this, 'postgres-dev')">
          <span class="status running"></span>
          <span class="name">postgres-dev</span>
          <span class="meta">5432</span>
        </div>
        <div class="item" onclick="selectItem(this, 'redis-cache')">
          <span class="status running"></span>
          <span class="name">redis-cache</span>
          <span class="meta">6379</span>
        </div>
        <div class="item" onclick="selectItem(this, 'nginx-proxy')">
          <span class="status warning"></span>
          <span class="name">nginx-proxy</span>
          <span class="meta">80</span>
        </div>
        <div class="item" onclick="selectItem(this, 'api-server')">
          <span class="status running"></span>
          <span class="name">api-server</span>
          <span class="meta">3000</span>
        </div>
        <div class="item" onclick="selectItem(this, 'mongo-test')">
          <span class="status stopped"></span>
          <span class="name">mongo-test</span>
          <span class="meta">27017</span>
        </div>
        <div class="item" onclick="selectItem(this, 'worker-1')">
          <span class="status error"></span>
          <span class="name">worker-1</span>
          <span class="meta">err</span>
        </div>
      </div>

      <div class="section">
        <div class="section-header">
          <span>Kubernetes</span>
          <span class="count">1</span>
        </div>
        <div class="item" onclick="selectItem(this, 'minikube')">
          <span class="status running"></span>
          <span class="name">minikube</span>
          <span class="meta">k8s</span>
        </div>
      </div>
    </div>

    <div class="footer">
      <div class="footer-btn" onclick="createNew()">
        <span>+</span>
        <span>Create New</span>
      </div>
    </div>
  </aside>

  <main class="main">
    <div class="header">
      <div class="header-left">
        <h1 id="selected-name">ubuntu</h1>
        <span class="badge" id="status-badge">Running</span>
      </div>
      <div class="header-actions">
        <button class="action-btn">Terminal</button>
        <button class="action-btn">Files</button>
        <button class="action-btn danger">Stop</button>
        <button class="action-btn primary">Restart</button>
      </div>
    </div>

    <div class="content">
      <div class="info-grid">
        <div class="info-card">
          <div class="label">CPU Usage</div>
          <div class="value green" id="cpu">12%</div>
        </div>
        <div class="info-card">
          <div class="label">Memory</div>
          <div class="value" id="memory">256 MB</div>
        </div>
        <div class="info-card">
          <div class="label">Disk</div>
          <div class="value" id="disk">2.4 GB</div>
        </div>
        <div class="info-card">
          <div class="label">Network</div>
          <div class="value" id="network">↑ 1.2 MB/s</div>
        </div>
      </div>

      <div class="logs-section">
        <h2>Recent Logs</h2>
        <div class="logs" id="logs">
          <div class="log-line"><span class="log-time">12:34:56</span><span class="log-msg success">Container started successfully</span></div>
          <div class="log-line"><span class="log-time">12:34:57</span><span class="log-msg">Mounting volumes...</span></div>
          <div class="log-line"><span class="log-time">12:34:58</span><span class="log-msg info">Network configured: 172.17.0.2</span></div>
          <div class="log-line"><span class="log-time">12:35:01</span><span class="log-msg">Starting services...</span></div>
          <div class="log-line"><span class="log-time">12:35:02</span><span class="log-msg success">All services healthy</span></div>
          <div class="log-line"><span class="log-time">12:35:10</span><span class="log-msg">Accepting connections on port 22</span></div>
        </div>
      </div>
    </div>
  </main>

  <script>
    const items = {
      'ubuntu': { status: 'Running', cpu: '12%', memory: '256 MB', disk: '2.4 GB', network: '↑ 1.2 MB/s' },
      'debian': { status: 'Running', cpu: '8%', memory: '128 MB', disk: '1.8 GB', network: '↑ 0.5 MB/s' },
      'fedora': { status: 'Stopped', cpu: '0%', memory: '0 MB', disk: '3.1 GB', network: '—' },
      'postgres-dev': { status: 'Running', cpu: '15%', memory: '512 MB', disk: '1.2 GB', network: '↑ 2.3 MB/s' },
      'redis-cache': { status: 'Running', cpu: '3%', memory: '64 MB', disk: '128 MB', network: '↑ 0.8 MB/s' },
      'nginx-proxy': { status: 'Warning', cpu: '45%', memory: '128 MB', disk: '256 MB', network: '↑ 5.2 MB/s' },
      'api-server': { status: 'Running', cpu: '22%', memory: '384 MB', disk: '512 MB', network: '↑ 3.1 MB/s' },
      'mongo-test': { status: 'Stopped', cpu: '0%', memory: '0 MB', disk: '2.8 GB', network: '—' },
      'worker-1': { status: 'Error', cpu: '0%', memory: '0 MB', disk: '64 MB', network: '—' },
      'minikube': { status: 'Running', cpu: '35%', memory: '2.1 GB', disk: '8.4 GB', network: '↑ 1.8 MB/s' },
    };

    function selectItem(el, name) {
      document.querySelectorAll('.item').forEach(i => i.classList.remove('selected'));
      el.classList.add('selected');

      const data = items[name];
      document.getElementById('selected-name').textContent = name;
      document.getElementById('status-badge').textContent = data.status;
      document.getElementById('cpu').textContent = data.cpu;
      document.getElementById('memory').textContent = data.memory;
      document.getElementById('disk').textContent = data.disk;
      document.getElementById('network').textContent = data.network;

      // Update status badge color
      const badge = document.getElementById('status-badge');
      badge.className = 'badge';
      if (data.status === 'Stopped') badge.style.background = 'rgba(107, 114, 128, 0.2)';
      else if (data.status === 'Warning') badge.style.background = 'rgba(245, 158, 11, 0.2)';
      else if (data.status === 'Error') badge.style.background = 'rgba(239, 68, 68, 0.2)';
      else badge.style.background = 'rgba(34, 197, 94, 0.2)';

      badge.style.color = data.status === 'Stopped' ? '#6b7280' :
                          data.status === 'Warning' ? '#f59e0b' :
                          data.status === 'Error' ? '#ef4444' : '#22c55e';

      // Update CPU color
      const cpuVal = parseInt(data.cpu);
      const cpuEl = document.getElementById('cpu');
      cpuEl.className = 'value ' + (cpuVal > 80 ? 'red' : cpuVal > 50 ? 'yellow' : 'green');
    }

    function createNew() {
      if (window.craft?.app?.notify) {
        window.craft.app.notify({
          title: 'Create New',
          body: 'Would open creation dialog...'
        });
      }
    }

    console.log('[OrbStack Containers] Demo loaded');
  </script>
</body>
</html>
`

const app = createApp({
  html,
  window: {
    title: 'Containers',
    width: 1000,
    height: 700,
    minWidth: 700,
    minHeight: 500,
    titlebarHidden: true,
  },
})

await app.show()
