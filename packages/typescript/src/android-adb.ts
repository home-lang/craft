/** Restart adbd once and require a rooted, explicitly selected disposable emulator. */
export async function requireAndroidEmulatorRoot(adb: string, serial: string, timeoutMs = 60_000): Promise<void> {
  if (!/^emulator-\d+$/.test(serial)) throw new Error('An explicit disposable Android emulator serial is required')
  const deadline = Date.now() + timeoutMs
  async function run(args: string[]): Promise<{ code: number, output: string }> {
    const remaining = deadline - Date.now()
    if (remaining <= 0) throw new Error('Android root reconnect deadline exceeded')
    const child = Bun.spawn([adb, '-s', serial, ...args], { stdout: 'pipe', stderr: 'pipe', timeout: remaining })
    const [code, stdout, stderr] = await Promise.all([child.exited, new Response(child.stdout).text(), new Response(child.stderr).text()])
    return { code, output: `${stdout}\n${stderr}`.trim() }
  }
  const root = await run(['root'])
  // Root changes restart adbd. Some versions close the transport before they
  // acknowledge the request; that response requires reconnection and UID proof.
  if (root.code !== 0 && !/^adb: unable to connect for root: closed$/.test(root.output)) {
    throw new Error(`adb root failed (${root.code}): ${root.output}`)
  }
  const connected = await run(['wait-for-device'])
  if (connected.code !== 0) throw new Error(`Android root reconnect failed (${connected.code}): ${connected.output}`)
  const identity = await run(['shell', 'id', '-u'])
  if (identity.code !== 0 || identity.output !== '0') {
    throw new Error(`Storage fault tests require a rootable disposable AOSP emulator: ${identity.output}`)
  }
}
