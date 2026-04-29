// Craft JS bridge — runs at document-start in every Craft window.
//
// This file is the single source of truth for what `window.craft.*` looks
// like to user code. It's embedded into the binary via @embedFile and
// injected via WKUserScript / inline <script>, so it must be:
//
//   1. **Self-contained** — no imports, no transpiler, ES5-friendly
//      (avoid arrow functions, const/let are fine in modern WebKit).
//   2. **Idempotent** — may run twice if the page reloads.
//   3. **Defensive** — `webkit.messageHandlers.craft` may not exist (e.g.
//      when served outside a Craft window). Don't throw at module load.
//
// The native side dispatches messages by `t` (type) and answers async ones
// via `window.__craftBridgeResult(action, payload)`. Promises are resolved
// per-action — callers that need different per-call replies should pass an
// `id` field through the `data` payload and correlate themselves.

;(function () {
  if (window.craft && window.craft.__craft_bridge_loaded) return
  window.craft = window.craft || {}
  window.craft.__craft_bridge_loaded = true

  // -------------------------------------------------------------------------
  // Core: pending-call queue, result/error delivery, send helpers.
  // -------------------------------------------------------------------------

  window.__craftBridgePending = window.__craftBridgePending || {}

  // Native calls this with the same `action` string the JS facade enqueued
  // under, so the queue is keyed by action name. Action collisions across
  // bridges would confuse the queue — keep names unique on the Zig side.
  window.__craftBridgeResult = function (action, payload) {
    const q = window.__craftBridgePending[action] || []
    if (q.length > 0) {
      const e = q.shift()
      if (e && e.resolve) e.resolve(payload || {})
    }
  }

  // Catastrophic native-side failure: drop every pending promise with the
  // same error so callers don't hang forever.
  window.__craftBridgeError = function (err) {
    const p = window.__craftBridgePending || {}
    Object.keys(p).forEach(function (k) {
      const q = p[k]
      if (Array.isArray(q)) {
        while (q.length > 0) {
          const e = q.shift()
          if (e && e.reject) e.reject(err)
        }
      }
    })
    window.__craftBridgePending = {}
  }

  function _post(t, a, d) {
    try {
      window.webkit.messageHandlers.craft.postMessage({ t: t, a: a, d: d || '' })
      return true
    }
    catch (e) {
      return false
    }
  }

  // Fire-and-forget. Returns a Promise that resolves once the message is
  // posted (no native ack) — preserves the existing `_m` shape so callers
  // can still `await craft.window.show()` without surprises.
  function _send(t, a, d) {
    return new Promise(function (ok, no) {
      if (_post(t, a, d)) ok()
      else no(new Error('craft bridge unavailable'))
    })
  }

  // Request-with-response. Native must call sendResultToJS(action, json)
  // exactly once for each in-flight call. The action name must match.
  function _req(t, a, d) {
    return new Promise(function (ok, no) {
      const q = (window.__craftBridgePending[a] = window.__craftBridgePending[a] || [])
      q.push({ resolve: ok, reject: no })
      if (!_post(t, a, d)) {
        // Couldn't post — pop our entry off and reject. Don't reject the
        // whole queue; another _post may have succeeded for a sibling call.
        q.pop()
        no(new Error('craft bridge unavailable'))
      }
    })
  }

  function _evt(name) {
    return function (cb) {
      const h = function (e) { cb((e && e.detail) || {}) }
      window.addEventListener(name, h)
      return function () { window.removeEventListener(name, h) }
    }
  }

  function _stringify(d) {
    if (d == null) return ''
    if (typeof d === 'string') return d
    try { return JSON.stringify(d) } catch (e) { return '' }
  }

  // -------------------------------------------------------------------------
  // window — full surface from bridge_window.zig
  // -------------------------------------------------------------------------
  window.craft.window = {
    show:         function ()         { return _send('window', 'show') },
    hide:         function ()         { return _send('window', 'hide') },
    toggle:       function ()         { return _send('window', 'toggle') },
    focus:        function ()         { return _send('window', 'focus') },
    minimize:     function ()         { return _send('window', 'minimize') },
    maximize:     function ()         { return _send('window', 'maximize') },
    close:        function ()         { return _send('window', 'close') },
    center:       function ()         { return _send('window', 'center') },
    reload:       function ()         { return _send('window', 'reload') },
    toggleFullscreen: function ()     { return _send('window', 'toggleFullscreen') },
    setFullscreen: function (on)      { return _send('window', 'setFullscreen', _stringify({ value: !!on })) },
    setTitle:     function (title)    { return _send('window', 'setTitle', _stringify({ title: String(title) })) },
    setSize:      function (w, h)     { return _send('window', 'setSize', _stringify({ width: w, height: h })) },
    setPosition:  function (x, y)     { return _send('window', 'setPosition', _stringify({ x: x, y: y })) },
    setMinSize:   function (w, h)     { return _send('window', 'setMinSize', _stringify({ width: w, height: h })) },
    setMaxSize:   function (w, h)     { return _send('window', 'setMaxSize', _stringify({ width: w, height: h })) },
    setAspectRatio: function (w, h)   { return _send('window', 'setAspectRatio', _stringify({ width: w, height: h })) },
    setOpacity:   function (op)       { return _send('window', 'setOpacity', _stringify({ value: op })) },
    setAlwaysOnTop: function (on)     { return _send('window', 'setAlwaysOnTop', _stringify({ value: !!on })) },
    setResizable: function (on)       { return _send('window', 'setResizable', _stringify({ value: !!on })) },
    setMovable:   function (on)       { return _send('window', 'setMovable', _stringify({ value: !!on })) },
    setHasShadow: function (on)       { return _send('window', 'setHasShadow', _stringify({ value: !!on })) },
    setBackgroundColor: function (c)  { return _send('window', 'setBackgroundColor', _stringify({ color: String(c) })) },
    setVibrancy:  function (mat)      { return _send('window', 'setVibrancy', _stringify({ material: String(mat || '') })) },
  }

  // -------------------------------------------------------------------------
  // app — process-level controls
  // -------------------------------------------------------------------------
  window.craft.app = {
    hideDockIcon: function () { return _send('app', 'hideDockIcon') },
    showDockIcon: function () { return _send('app', 'showDockIcon') },
    quit:         function () { return _send('app', 'quit') },
  }

  // -------------------------------------------------------------------------
  // dialog — file pickers + alerts
  // -------------------------------------------------------------------------
  window.craft.dialog = {
    showOpenDialog: function (opts) {
      opts = opts || {}
      // Single vs multi vs folder map to distinct native actions because
      // each one configures NSOpenPanel differently and reports under a
      // different result key.
      if (opts.properties && opts.properties.indexOf('openDirectory') >= 0) {
        return _req('dialog', 'openFolder', _stringify(opts))
      }
      if (opts.properties && opts.properties.indexOf('multiSelections') >= 0) {
        return _req('dialog', 'openFiles', _stringify(opts))
      }
      return _req('dialog', 'openFile', _stringify(opts))
    },
    showSaveDialog: function (opts)  { return _req('dialog', 'saveFile', _stringify(opts || {})) },
    showMessageBox: function (opts) {
      opts = opts || {}
      // showAlert is a single-button info banner. showConfirm is OK/cancel
      // with a boolean response. Anything beyond two buttons isn't yet
      // wired natively; callers should use showAlert and detect.
      const isConfirm = (opts.buttons && opts.buttons.length >= 2) || opts.type === 'question'
      return _req('dialog', isConfirm ? 'showConfirm' : 'showAlert', _stringify(opts))
    },
    // Convenience helpers that match Electron-ish semantics.
    showAlert:   function (msg, opts) { return _req('dialog', 'showAlert', _stringify(Object.assign({ message: String(msg) }, opts || {}))) },
    showConfirm: function (msg, opts) { return _req('dialog', 'showConfirm', _stringify(Object.assign({ message: String(msg) }, opts || {}))) },
  }

  // -------------------------------------------------------------------------
  // clipboard — text + html (image read/write are stubbed natively)
  // -------------------------------------------------------------------------
  window.craft.clipboard = {
    writeText: function (text)        { return _send('clipboard', 'writeText', _stringify({ text: String(text) })) },
    readText:  function ()            { return _req('clipboard', 'readText').then(function (r) { return (r && r.text) || '' }) },
    writeHTML: function (html)        { return _send('clipboard', 'writeHTML', _stringify({ html: String(html) })) },
    readHTML:  function ()            { return _req('clipboard', 'readHTML').then(function (r) { return (r && r.html) || '' }) },
    clear:     function ()            { return _send('clipboard', 'clear') },
    hasText:   function ()            { return _req('clipboard', 'hasText').then(function (r) { return !!(r && r.value) }) },
    hasHTML:   function ()            { return _req('clipboard', 'hasHTML').then(function (r) { return !!(r && r.value) }) },
    hasImage:  function ()            { return _req('clipboard', 'hasImage').then(function (r) { return !!(r && r.value) }) },
  }

  // -------------------------------------------------------------------------
  // notifications — banner / badge
  // -------------------------------------------------------------------------
  window.craft.notifications = {
    show: function (opts) {
      // Convenience wrapper around schedule with no triggerAt.
      const o = Object.assign({}, opts || {})
      if (typeof o.title !== 'string' || o.title.length === 0) {
        return Promise.reject(new Error('notification title is required'))
      }
      return _send('notification', 'schedule', _stringify(o))
    },
    schedule:          function (opts) { return _send('notification', 'schedule', _stringify(opts || {})) },
    cancel:            function (id)   { return _send('notification', 'cancel', _stringify({ id: String(id) })) },
    cancelAll:         function ()     { return _send('notification', 'cancelAll') },
    setBadge:          function (n)    { return _send('notification', 'setBadge', _stringify({ count: Number(n) || 0 })) },
    clearBadge:        function ()     { return _send('notification', 'clearBadge') },
    requestPermission: function ()     { return _req('notification', 'requestPermission').then(function (r) { return (r && r.granted) === true }) },
  }

  // -------------------------------------------------------------------------
  // fs — read/write/etc; values come back keyed by action.
  // -------------------------------------------------------------------------
  window.craft.fs = {
    readFile:   function (path)             { return _req('fs', 'readFile', _stringify({ path: String(path) })) },
    writeFile:  function (path, data)       { return _send('fs', 'writeFile', _stringify({ path: String(path), data: String(data) })) },
    appendFile: function (path, data)       { return _send('fs', 'appendFile', _stringify({ path: String(path), data: String(data) })) },
    deleteFile: function (path)             { return _send('fs', 'deleteFile', _stringify({ path: String(path) })) },
    exists:     function (path)             { return _req('fs', 'exists', _stringify({ path: String(path) })).then(function (r) { return !!(r && r.exists) }) },
    stat:       function (path)             { return _req('fs', 'stat', _stringify({ path: String(path) })) },
    readDir:    function (path)             { return _req('fs', 'readDir', _stringify({ path: String(path) })) },
    mkdir:      function (path, opts)       { return _send('fs', 'mkdir', _stringify(Object.assign({ path: String(path) }, opts || {}))) },
    rmdir:      function (path, opts)       { return _send('fs', 'rmdir', _stringify(Object.assign({ path: String(path) }, opts || {}))) },
    copy:       function (from, to)         { return _send('fs', 'copy', _stringify({ from: String(from), to: String(to) })) },
    move:       function (from, to)         { return _send('fs', 'move', _stringify({ from: String(from), to: String(to) })) },
    watch:      function (path, callbackId) { return _send('fs', 'watch', _stringify({ path: String(path), callbackId: String(callbackId || '') })) },
    unwatch:    function (id)               { return _send('fs', 'unwatch', _stringify({ id: String(id) })) },
    homeDir:    function ()                 { return _req('fs', 'getHomeDir').then(function (r) { return (r && r.path) || '' }) },
    tempDir:    function ()                 { return _req('fs', 'getTempDir').then(function (r) { return (r && r.path) || '' }) },
    appDataDir: function ()                 { return _req('fs', 'getAppDataDir').then(function (r) { return (r && r.path) || '' }) },
  }

  // -------------------------------------------------------------------------
  // shell — open URLs + spawn processes
  // -------------------------------------------------------------------------
  window.craft.shell = {
    openExternal: function (url)              { return _send('shell', 'openUrl', _stringify({ url: String(url) })) },
    openPath:     function (path)             { return _send('shell', 'openPath', _stringify({ path: String(path) })) },
    showInFinder: function (path)             { return _send('shell', 'showInFinder', _stringify({ path: String(path) })) },
    spawn:        function (id, cmd, args, opts) {
      return _send('shell', 'spawn', _stringify(Object.assign({
        id: String(id), command: String(cmd), args: args || [],
      }, opts || {})))
    },
    kill:         function (id)               { return _send('shell', 'kill', _stringify({ id: String(id) })) },
    getEnv:       function (name)             { return _req('shell', 'getEnv', _stringify({ name: String(name) })).then(function (r) { return r && r.value }) },
    setEnv:       function (name, value)      { return _send('shell', 'setEnv', _stringify({ name: String(name), value: String(value) })) },
  }

  // -------------------------------------------------------------------------
  // shortcuts — global hotkeys
  // -------------------------------------------------------------------------
  window.craft.shortcuts = {
    register:       function (id, accelerator, opts) {
      return _send('shortcuts', 'register', _stringify(Object.assign({
        id: String(id), accelerator: String(accelerator),
      }, opts || {})))
    },
    unregister:     function (id) { return _send('shortcuts', 'unregister', _stringify({ id: String(id) })) },
    unregisterAll:  function ()   { return _send('shortcuts', 'unregisterAll') },
    enable:         function (id) { return _send('shortcuts', 'enable', _stringify({ id: String(id) })) },
    disable:        function (id) { return _send('shortcuts', 'disable', _stringify({ id: String(id) })) },
    isRegistered:   function (id) { return _req('shortcuts', 'isRegistered', _stringify({ id: String(id) })).then(function (r) { return !!(r && r.value) }) },
    list:           function ()   { return _req('shortcuts', 'list').then(function (r) { return (r && r.shortcuts) || [] }) },
    on:             _evt('craft:shortcut'),
  }

  // -------------------------------------------------------------------------
  // theme — system appearance
  // -------------------------------------------------------------------------
  // Native side delivers `craft:theme` with `{appearance:'dark'|'light'}`
  // via __craftDeliverTheme on app boot and on every appearance change.
  window.__craftDeliverTheme = function (info) {
    if (!info) return
    window.__craftCurrentTheme = info
    window.dispatchEvent(new CustomEvent('craft:theme', { detail: info }))
  }
  window.craft.theme = {
    get:        function () { return window.__craftCurrentTheme || { appearance: 'light' } },
    onChange:   _evt('craft:theme'),
  }

  // -------------------------------------------------------------------------
  // dragOut — start a native drag from a DOM element so the user can drag
  // a file *out* of the window onto Finder / Slack / etc.
  // -------------------------------------------------------------------------
  // Usage:
  //   craft.dragOut.start(['/Users/me/export.png'], { event: mouseEvent })
  // The second arg is optional but improves drag preview alignment when
  // the caller can pass the originating event.
  window.craft.dragOut = {
    start: function (paths, opts) {
      const arr = Array.isArray(paths) ? paths : [paths]
      const filtered = arr.filter(function (p) { return typeof p === 'string' && p.length > 0 })
      if (filtered.length === 0) return Promise.reject(new Error('dragOut: at least one path required'))
      const o = opts || {}
      return _send('dragOut', 'start', _stringify({
        paths: filtered,
        x: typeof o.x === 'number' ? o.x : (o.event ? o.event.clientX : 0),
        y: typeof o.y === 'number' ? o.y : (o.event ? o.event.clientY : 0),
      }))
    },
  }

  // -------------------------------------------------------------------------
  // deepLink — receive `myapp://...` URLs from the OS
  // -------------------------------------------------------------------------
  // Native side delivers via __craftDeliverDeepLink('myapp://path').
  window.__craftDeliverDeepLink = function (url) {
    if (typeof url !== 'string' || url.length === 0) return
    window.__craftPendingDeepLink = url
    window.dispatchEvent(new CustomEvent('craft:deepLink', { detail: { url: url } }))
  }
  window.craft.deepLink = {
    onUrl: _evt('craft:deepLink'),
    // If the OS launched the app *because* of a URL, that URL may be
    // delivered before the page is ready. Subscribers added late can
    // still get it via this getter.
    getInitialUrl: function () { return window.__craftPendingDeepLink || null },
  }

  // -------------------------------------------------------------------------
  // power — battery + sleep prevention
  // -------------------------------------------------------------------------
  window.craft.power = {
    isCharging:        function () { return _req('power', 'isCharging').then(function (r) { return !!(r && r.value) }) },
    isPluggedIn:       function () { return _req('power', 'isPluggedIn').then(function (r) { return !!(r && r.value) }) },
    isLowPowerMode:    function () { return _req('power', 'isLowPowerMode').then(function (r) { return !!(r && r.value) }) },
    batteryLevel:      function () { return _req('power', 'getBatteryState').then(function (r) { return (r && r.level) || 0 }) },
    timeRemaining:     function () { return _req('power', 'getTimeRemaining').then(function (r) { return r && r.minutes }) },
    thermalState:      function () { return _req('power', 'getThermalState').then(function (r) { return (r && r.state) || 'nominal' }) },
    uptimeSeconds:     function () { return _req('power', 'getUptimeSeconds').then(function (r) { return (r && r.seconds) || 0 }) },
    preventSleep:      function (reason) { return _send('power', 'preventSleep', _stringify({ reason: String(reason || '') })) },
    allowSleep:        function () { return _send('power', 'allowSleep') },
    onSleep:           _evt('craft:powerSleep'),
    onWake:            _evt('craft:powerWake'),
  }

  // -------------------------------------------------------------------------
  // network — reachability + interface info
  // -------------------------------------------------------------------------
  window.craft.network = {
    connectionType:    function () { return _req('network', 'getConnectionType').then(function (r) { return (r && r.type) || 'unknown' }) },
    wifiSSID:          function () { return _req('network', 'getWiFiSSID').then(function (r) { return r && r.ssid }) },
    wifiSignalStrength:function () { return _req('network', 'getWiFiSignalStrength').then(function (r) { return r && r.dBm }) },
    ipAddress:         function () { return _req('network', 'getIPAddress').then(function (r) { return (r && r.address) || '' }) },
    macAddress:        function () { return _req('network', 'getMACAddress').then(function (r) { return (r && r.address) || '' }) },
    interfaces:        function () { return _req('network', 'getNetworkInterfaces').then(function (r) { return (r && r.interfaces) || [] }) },
    isVPNConnected:    function () { return _req('network', 'isVPNConnected').then(function (r) { return !!(r && r.value) }) },
    proxySettings:     function () { return _req('network', 'getProxySettings') },
    openPreferences:   function () { return _send('network', 'openNetworkPreferences') },
    onChange:          _evt('craft:networkChange'),
  }

  // -------------------------------------------------------------------------
  // updater — Sparkle / WinSparkle / custom feed
  // -------------------------------------------------------------------------
  window.craft.updater = {
    checkForUpdates:           function ()       { return _send('updater', 'checkForUpdates') },
    checkInBackground:         function ()       { return _send('updater', 'checkForUpdatesInBackground') },
    setAutomaticChecks:        function (on)     { return _send('updater', 'setAutomaticChecks', _stringify({ value: !!on })) },
    setCheckInterval:          function (sec)    { return _send('updater', 'setCheckInterval', _stringify({ seconds: Number(sec) || 0 })) },
    setFeedURL:                function (url)    { return _send('updater', 'setFeedURL', _stringify({ url: String(url) })) },
    getLastUpdateCheckDate:    function ()       { return _req('updater', 'getLastUpdateCheckDate').then(function (r) { return r && r.date }) },
    getUpdateInfo:             function ()       { return _req('updater', 'getUpdateInfo') },
    onAvailable:               _evt('craft:updateAvailable'),
    onDownloaded:              _evt('craft:updateDownloaded'),
  }

  // -------------------------------------------------------------------------
  // tray — system menubar item (only meaningful when `system_tray: true`)
  // -------------------------------------------------------------------------
  window.craft.tray = {
    setTitle:   function (t) {
      // 20-char cap mirrors NSStatusItem behavior — anything past it gets
      // visually clipped, so we truncate eagerly to keep the JS-side
      // intent and the rendered title in sync.
      const s = String(t == null ? '' : t)
      return _send('tray', 'setTitle', s.length > 20 ? s.substring(0, 20) : s)
    },
    setTooltip: function (t)        { return _send('tray', 'setTooltip', String(t == null ? '' : t)) },
    setIcon:    function (icon)     { return _send('tray', 'setIcon', _stringify({ icon: String(icon) })) },
    setMenu:    function (items)    { return _send('tray', 'setMenu', _stringify(items || [])) },
    destroy:    function ()         { return _send('tray', 'destroy') },
    onClick:    function (cb) {
      const h = function (e) {
        cb({
          button:    (e.detail && e.detail.button) || 'left',
          timestamp: (e.detail && e.detail.timestamp) || Date.now(),
          modifiers: (e.detail && e.detail.modifiers) || {},
        })
      }
      window.addEventListener('craft:tray:click', h)
      return function () { window.removeEventListener('craft:tray:click', h) }
    },
    onClickToggleWindow: function () {
      return this.onClick(function () { window.craft.window.toggle() })
    },
    onMenuAction: _evt('craft:tray:menuAction'),
  }
  window.__craftDeliverAction = function (a) {
    if (a && a.length > 0) {
      window.dispatchEvent(new CustomEvent('craft:tray:menuAction', { detail: { action: a } }))
    }
  }

  // -------------------------------------------------------------------------
  // menubar — collapse/expand (only meaningful in tray mode)
  // -------------------------------------------------------------------------
  window.craft.menubar = {
    init:                  function ()      { return _send('menubarCollapse', 'init') },
    collapse:              function ()      { return _send('menubarCollapse', 'collapse') },
    expand:                function ()      { return _send('menubarCollapse', 'expand') },
    toggle:                function ()      { return _send('menubarCollapse', 'toggle') },
    getState:              function () {
      // Native menubar uses a fully-qualified result key, so we have to
      // queue under the same key to receive the response.
      return new Promise(function (ok, no) {
        const key = 'menubarCollapse:getState'
        const q = (window.__craftBridgePending[key] = window.__craftBridgePending[key] || [])
        q.push({ resolve: ok, reject: no })
        if (!_post('menubarCollapse', 'getState', '')) {
          q.pop()
          no(new Error('craft bridge unavailable'))
        }
      })
    },
    setAutoCollapse:       function (s)     { return _send('menubarCollapse', 'setAutoCollapse', String(!!s)) },
    enableAlwaysHidden:    function ()      { return _send('menubarCollapse', 'enableAlwaysHidden') },
    disableAlwaysHidden:   function ()      { return _send('menubarCollapse', 'disableAlwaysHidden') },
    setSeparatorHidden:    function (h)     { return _send('menubarCollapse', 'setSeparatorHidden', h ? 'true' : 'false') },
    onStateChange:         _evt('craft:menubar:stateChange'),
  }

  // -------------------------------------------------------------------------
  // onFileDrop — file paths from native drag-drop (set from macos_file_drop)
  // -------------------------------------------------------------------------
  window.__craftDeliverFileDrop = function (paths) {
    if (!Array.isArray(paths) || paths.length === 0) return
    window.dispatchEvent(new CustomEvent('craft:fileDrop', { detail: { paths: paths } }))
  }
  window.craft.onFileDrop = _evt('craft:fileDrop')

  // -------------------------------------------------------------------------
  // Ready event + opt-in tray polling.
  // -------------------------------------------------------------------------
  function fireReady() {
    window.dispatchEvent(new CustomEvent('craft:ready'))
    if (typeof window.initializeCraftApp === 'function') window.initializeCraftApp()
  }
  if (document.readyState === 'loading')
    document.addEventListener('DOMContentLoaded', fireReady)
  else
    fireReady()

  // The full bridge enables tray + menubar polling via this flag, set by
  // the Zig side BEFORE this script is injected. Polling is a stopgap
  // until we have a proper native→JS push channel for these channels.
  if (window.__craftEnableTrayPolling) {
    setInterval(function () { _post('tray', 'pollActions', '') }, 100)
    setInterval(function () { _post('menubarCollapse', 'poll', '') }, 1000)
  }
})()
