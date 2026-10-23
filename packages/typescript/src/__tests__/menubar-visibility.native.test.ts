import assert from 'node:assert/strict'
import { test } from 'bun:test'
import { copyFile, mkdir, mkdtemp, rm, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'

// Opt-in real private-API acceptance on macOS 27 with existing Accessibility
// authorization. CI's default native tests cover unavailability and cancellation
// without requesting grants or changing security settings.
const nativeVisibilityTest = process.platform === 'darwin'
  && process.env.CRAFT_NATIVE_TEST_BIN && process.env.CRAFT_NATIVE_VISIBILITY_E2E === '1' ? test : test.skip

nativeVisibilityTest('packaged native visibility hides a group and releases its real macOS assertion', async () => {
  const runtime = process.env.CRAFT_NATIVE_TEST_BIN!
  const dir = await mkdtemp(join(tmpdir(), 'craft-visibility-packaged-'))
  const stages: Record<string, any> = {}
  let releaseTarget: () => void = () => {}
  const targetReady = new Promise<void>(resolve => { releaseTarget = resolve })
  const controllerScript = `(async () => {
    await craft.tray.setIcon('cup.and.saucer.fill');
    await craft.tray.setTooltip('Native visibility verification controller');
    await craft.menubar.init({backend:'nativeVisibility'});
    await fetch('/stage/initialized', {method:'POST',body:JSON.stringify(await craft.menubar.getState())});
    await fetch('/target-ready');
    await craft.timers.sleep(700);
    await craft.menubar.collapse();
    let collapsed;
    for (let i=0;i<100;i++) {
      collapsed=await craft.menubar.getState();
      if (!collapsed.busy) break;
      await craft.timers.sleep(100);
    }
    await fetch('/stage/collapsed',{method:'POST',body:JSON.stringify(collapsed)});
    await craft.menubar.expand();
    await fetch('/stage/expanded',{method:'POST',body:JSON.stringify(await craft.menubar.getState())});
    await craft.menubar.destroy();
    await fetch('/stage/destroyed',{method:'POST',body:JSON.stringify(await craft.menubar.getState())});
    craft.app.quit();
  })().catch(async error => { await fetch('/stage/error',{method:'POST',body:JSON.stringify({error:String(error)})}); craft.app.quit(); });`
  const targetScript = `(async () => { await craft.tray.setIcon('star.fill'); await craft.tray.setTitle('B·TEST'); await craft.tray.setTooltip('Native visibility verification target'); await fetch('/stage/target',{method:'POST',body:JSON.stringify(await craft.tray.getState())}); })();`
  const server = Bun.serve({ hostname:'127.0.0.1',port:0, async fetch(request) {
    const path = new URL(request.url).pathname
    if (path.startsWith('/stage/')) {
      const stage = path.slice('/stage/'.length)
      stages[stage] = await request.json()
      if (stage === 'target') releaseTarget()
      return new Response('ok')
    }
    if (path === '/target-ready') { await targetReady; return new Response('ready') }
    return new Response(`<script>${path === '/target' ? targetScript : controllerScript}</script>`,{headers:{'content-type':'text/html'}})
  }})
  const processes: ReturnType<typeof Bun.spawn>[] = []
  const logs: Promise<string>[] = []
  const watchdog = setTimeout(() => {
    for (const proc of processes) if (proc.exitCode === null) proc.kill('SIGTERM')
  }, 35000)
  async function bundle(name:string) {
    const app = join(dir, `${name}.app`), macos = join(app,'Contents/MacOS')
    await mkdir(macos,{recursive:true})
    await copyFile(runtime,join(macos,'craft'))
    const id = `org.craft-native.visibility-e2e.${name.toLowerCase()}.${process.pid}`
    await writeFile(join(app,'Contents/Info.plist'), `<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>CFBundleExecutable</key><string>craft</string><key>CFBundleIdentifier</key><string>${id}</string><key>CFBundleName</key><string>${name}</string><key>CFBundlePackageType</key><string>APPL</string><key>LSUIElement</key><true/></dict></plist>`)
    const signed = Bun.spawnSync(['codesign','--force','--sign','-','--identifier',id,app])
    assert.equal(signed.exitCode,0,signed.stderr.toString())
    const proc = Bun.spawn([join(macos,'craft'),'--headless','--system-tray','--title',name,'--url',`http://127.0.0.1:${server.port}/${name === 'Target' ? 'target' : ''}`],{stdout:'ignore',stderr:'pipe'})
    processes.push(proc)
    logs.push(new Response(proc.stderr).text())
    return proc
  }
  async function until(stage:string) {
    const deadline = Date.now()+30000
    while (!stages[stage] && !stages.error && Date.now()<deadline) await Bun.sleep(50)
    assert(!stages.error,JSON.stringify(stages.error))
    assert(stages[stage],`Missing native stage: ${stage}`)
    return stages[stage]
  }
  try {
    const controller = await bundle('Controller')
    const initialized = await until('initialized')
    assert.equal(initialized.backend,'nativeVisibility')
    assert.equal(initialized.available,true)
    assert.equal(initialized.authorized,true,'Native verification needs pre-existing Accessibility authorization; this test never requests it')
    assert.equal(initialized.markerWidth,20)
    await bundle('Target')
    const collapsed = await until('collapsed')
    assert.equal(collapsed.error,null,JSON.stringify(collapsed))
    assert.equal(collapsed.collapsed,true)
    assert(collapsed.hiddenAppCount >= 1,JSON.stringify(collapsed))
    assert.equal(collapsed.markerWidth,20)
    const expanded = await until('expanded')
    assert.equal(expanded.collapsed,false)
    assert.equal(expanded.hiddenAppCount,0)
    assert.equal(expanded.markerWidth,20)
    const destroyed = await until('destroyed')
    assert.equal(destroyed.initialized,false)
    assert.equal(await controller.exited,0)
    const evidence = {observedAt:new Date().toISOString(),runtime,initialized,collapsed,expanded,destroyed}
    console.log(JSON.stringify(evidence,null,2))
  }
  finally {
    clearTimeout(watchdog)
    for (const proc of processes) if (proc.exitCode === null) proc.kill('SIGTERM')
    await Promise.all(processes.map(proc=>proc.exited))
    for (const output of await Promise.all(logs)) if (output) console.error(output)
    server.stop(true)
    await rm(dir,{recursive:true,force:true})
  }
}, 40000)
