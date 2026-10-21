import { expect, test } from 'bun:test'
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'

const nativeTest = process.platform === 'darwin' && process.env.CRAFT_NATIVE_TEST_BIN ? test : test.skip

nativeTest('hidden WebKit deadlines retain correlation and release cancelled native work', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'craft-timers-'))
  const marker = join(dir, 'result.json')
  const input = join(dir, 'index.html')
  await writeFile(input, `<script>
(async () => {
  const order = [];
  await Promise.all([
    craft.timers.sleep(180).then(() => order.push('slow')),
    craft.timers.sleep(5).then(() => order.push('fast')),
    ...Array.from({ length: 20 }, () => craft.timers.sleep(30)),
  ]);
  if (order.join(',') !== 'fast,slow') throw new Error('Replies were misrouted');
  for (let i = 0; i < 300; i++) {
    const controller = new AbortController();
    const waiting = craft.timers.sleep(86400000, { signal: controller.signal });
    controller.abort();
    await waiting.then(() => { throw new Error('Cancelled deadline fired'); }, error => {
      if (error.name !== 'AbortError') throw error;
    });
  }
  // This reply is a barrier after the cancellation messages. A leak would
  // exhaust the bounded timer pool or leave pending sleep replies behind.
  await craft.fs.writeFile(${JSON.stringify(join(dir, 'responsive'))}, 'ok');
  const pending = Object.values(window.__craftBridgeById).filter(entry => entry.action === 'sleep' || entry.action === 'cancel');
  if (pending.length !== 0) throw new Error('Cancelled timer requests leaked: ' + JSON.stringify(pending.map(entry => ({ id: entry.id, action: entry.action }))));
  const started = Date.now();
  await craft.timers.sleep(65000);
  const elapsed = Date.now() - started;
  if (elapsed < 65000 || elapsed > 75000) throw new Error('Hidden deadline delayed: ' + elapsed);
  await craft.fs.writeFile(${JSON.stringify(marker)}, JSON.stringify({ ok: true, elapsed }));
})().catch(async error => {
  await craft.fs.writeFile(${JSON.stringify(marker)}, JSON.stringify({ error: String(error) }));
}).finally(() => craft.app.quit());
</script>`)
  const proc = Bun.spawn([process.env.CRAFT_NATIVE_TEST_BIN!, '--headless', '--html-file', input], { stdout: 'ignore', stderr: 'pipe' })
  const stderr = new Response(proc.stderr).text()
  const timeout = setTimeout(() => { proc.kill() }, 80000)
  try {
    expect(await proc.exited).toBe(0)
    const result = JSON.parse(await readFile(marker, 'utf8'))
    expect(result.error).toBeUndefined()
    expect(result.ok).toBe(true)
    expect(result.elapsed).toBeGreaterThanOrEqual(65000)
  }
  finally {
    clearTimeout(timeout)
    if (proc.exitCode === null) proc.kill()
    await proc.exited
    const output = await stderr
    if (proc.exitCode !== 0) console.error(output)
    await rm(dir, { recursive: true, force: true })
  }
}, 85000)
