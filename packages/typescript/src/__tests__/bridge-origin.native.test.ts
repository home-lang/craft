import { expect, test } from 'bun:test'
import { mkdtemp, readFile, rm } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'

// Exercise the real WKNavigationDelegate and WKScriptMessageHandler. CI can
// opt in after building the native runtime by setting CRAFT_NATIVE_TEST_BIN.
const nativeTest = process.platform === 'darwin' && process.env.CRAFT_NATIVE_TEST_BIN ? test : test.skip

nativeTest('native bridge accepts its document and rejects child frames and foreign navigation', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'craft-origin-'))
  const seen = new Set<string>()
  const write = (name: string) => `window.webkit.messageHandlers.craft.postMessage({t:'fs',a:'writeFile',d:{path:${JSON.stringify(join(dir, name))},data:'ok'}});`
  const script = (name: string) => `<script>${write(name)}fetch('/seen/${name}').catch(()=>{});</script>`
  const server = Bun.serve({
    hostname: '127.0.0.1',
    port: 0,
    fetch(request): Response {
      const path = new URL(request.url).pathname
      if (path.startsWith('/seen/')) {
        seen.add(path.slice(6))
        return new Response('ok')
      }
      if (path === '/child') return new Response(script('child'), { headers: { 'content-type': 'text/html' } })
      if (path === '/foreign') return new Response(script('foreign'), { headers: { 'content-type': 'text/html' } })
      return new Response(`${script('trusted')}<iframe src="/child"></iframe><iframe src="http://localhost:${server.port}/child"></iframe><script>setTimeout(()=>location.href='http://localhost:${server.port}/foreign',1500)</script>`, { headers: { 'content-type': 'text/html' } })
    },
  })
  const proc = Bun.spawn([process.env.CRAFT_NATIVE_TEST_BIN!, '--headless', '--url', `http://127.0.0.1:${server.port}/`], { stdout: 'ignore', stderr: 'pipe' })
  const stderr = new Response(proc.stderr).text()
  try {
    const deadline = Date.now() + 15000
    while ((!seen.has('trusted') || !seen.has('child')) && Date.now() < deadline) await Bun.sleep(50)
    expect(seen.has('trusted')).toBe(true)
    expect(seen.has('child')).toBe(true)
    await Bun.sleep(2500)
    expect(await readFile(join(dir, 'trusted'), 'utf8')).toBe('ok')
    expect(await Bun.file(join(dir, 'child')).exists()).toBe(false)
    expect(await Bun.file(join(dir, 'foreign')).exists()).toBe(false)
    expect(seen.has('foreign')).toBe(false)
  }
  finally {
    proc.kill()
    await proc.exited
    const output = await stderr
    if (!seen.has('trusted')) console.error(output)
    server.stop(true)
    await rm(dir, { recursive: true, force: true })
  }
}, 25000)

nativeTest('app-directed inline HTML retains access to its native bridge', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'craft-inline-'))
  const marker = join(dir, 'inline')
  const html = `<script>window.webkit.messageHandlers.craft.postMessage({t:'fs',a:'writeFile',d:{path:${JSON.stringify(marker)},data:'ok'}})</script>`
  const proc = Bun.spawn([process.env.CRAFT_NATIVE_TEST_BIN!, '--headless', '--html', html], { stdout: 'ignore', stderr: 'pipe' })
  const stderr = new Response(proc.stderr).text()
  try {
    const deadline = Date.now() + 15000
    while (!await Bun.file(marker).exists() && Date.now() < deadline) await Bun.sleep(50)
    expect(await Bun.file(marker).exists()).toBe(true)
    expect(await readFile(marker, 'utf8')).toBe('ok')
  }
  finally {
    proc.kill()
    await proc.exited
    const output = await stderr
    if (!await Bun.file(marker).exists()) console.error(output)
    await rm(dir, { recursive: true, force: true })
  }
}, 20000)


nativeTest('a normal tray app does not manage other menu bar items until explicitly enabled', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'craft-tray-opt-in-'))
  const marker = join(dir, 'state.json')
  const html = `<script>(async () => {
    const before = await craft.menubar.getState();
    await craft.menubar.init();
    const after = await craft.menubar.getState();
    await craft.fs.writeFile(${JSON.stringify(marker)}, JSON.stringify({before, after}));
    craft.app.quit();
  })();</script>`
  const proc = Bun.spawn([process.env.CRAFT_NATIVE_TEST_BIN!, '--headless', '--system-tray', '--html', html], { stdout: 'ignore', stderr: 'pipe' })
  const stderr = new Response(proc.stderr).text()
  const timeout = setTimeout(() => proc.kill(), 15000)
  try {
    expect(await proc.exited).toBe(0)
    const result = JSON.parse(await readFile(marker, 'utf8'))
    expect(result.before.initialized).toBe(false)
    expect(result.before.collapsed).toBe(false)
    expect(result.after.initialized).toBe(true)
    expect(result.after.collapsed).toBe(false)
  }
  finally {
    clearTimeout(timeout)
    if (proc.exitCode === null) proc.kill()
    await proc.exited
    const output = await stderr
    if (proc.exitCode !== 0) console.error(output)
    await rm(dir, { recursive: true, force: true })
  }
}, 20000)
