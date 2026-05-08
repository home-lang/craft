#!/usr/bin/env bun

const commands = [
  ['bun', 'run', 'build'],
  ['bun', 'run', 'typecheck'],
  ['bun', 'run', 'test'],
  ['bun', 'run', 'fmt:check'],
  ['bun', 'run', 'verify:cimports'],
  ['cd packages/ts-maps && bun run build && bun test'],
  ['cd packages/create-craft && bun bin/cli.ts --version && bun bin/cli.ts list'],
  ['bun', 'scripts/verify-packages.ts'],
  ['bun', 'scripts/verify-create-craft.ts'],
  ['bun', 'run', 'lint'],
]

for (const command of commands) {
  const display = command.join(' ')
  console.log(`\n> ${display}`)
  const proc = command.length === 1
    ? Bun.spawnSync(['bash', '-lc', command[0]], { stdout: 'inherit', stderr: 'inherit' })
    : Bun.spawnSync(command, { stdout: 'inherit', stderr: 'inherit' })

  if (!proc.success)
    process.exit(proc.exitCode ?? 1)
}

console.log('\nVerification complete.')
