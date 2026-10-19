import { accessSync, constants, realpathSync, statSync } from 'node:fs'
import { isAbsolute, join, sep } from 'node:path'

/** Resolve the JDK selected by the managed toolchain. */
export function managedJavaHome(managed: string, env: NodeJS.ProcessEnv = process.env): string {
  try {
    const selected = env.JAVA_HOME?.trim()
    if (!selected || !isAbsolute(selected)) throw new Error('Missing absolute JDK selection')
    const prefix = realpathSync(managed)
    const home = realpathSync(selected)
    if (!home.startsWith(prefix + sep)) throw new Error('JDK is outside the managed toolchain')
    for (const binary of ['java', 'javac']) {
      const path = join(home, 'bin', binary)
      accessSync(path, constants.X_OK)
      if (!statSync(path).isFile()) throw new Error('JDK executable is not a file')
      if (!realpathSync(path).startsWith(home + sep)) throw new Error('JDK executable is outside its selected home')
    }
    // Pantry's .bin entry can be a forwarding executable. Its directory does
    // not identify the JDK; preserve the action's explicit installation path.
    return selected
  }
  catch {
    throw new Error('JAVA_HOME must identify a managed JDK with executable bin/java and bin/javac.')
  }
}
