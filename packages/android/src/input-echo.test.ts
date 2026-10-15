/** Execute the native input reconciler on the JVM when the Android toolchain is cached. */
import { test } from 'bun:test'
import { existsSync } from 'node:fs'
import { mkdtemp, rm } from 'node:fs/promises'
import { homedir, tmpdir } from 'node:os'
import { delimiter, dirname, join } from 'node:path'

const cache = join(process.env.GRADLE_USER_HOME || join(homedir(), '.gradle'), 'caches/modules-2/files-2.1')
const jars = existsSync(cache) ? [...new Bun.Glob('**/*.jar').scanSync({ cwd: cache, absolute: true })] : []
const compiler = jars.find(path => path.includes('/kotlin-compiler-embeddable/'))
test.skipIf(!compiler)('keeps newer keystrokes while earlier props are acknowledged', async () => {
  if (!compiler) return
  const template = await Bun.file(new URL('../templates/MainActivityNative.kt.template', import.meta.url)).text()
  const helper = template.match(/internal class CraftNativeInputEcho \{[\s\S]*?\n\}/)?.[0]
  if (!helper) throw new Error('Craft Android input reconciler is missing')
  const version = compiler.split('/kotlin-compiler-embeddable/')[1]!.split('/')[0]!
  const standard = jars.find(path => path.includes(`/kotlin-stdlib/${version}/`))!
  const pom = [...new Bun.Glob('../**/*.pom').scanSync({ cwd: dirname(compiler), absolute: true })][0]
  if (!pom) throw new Error('The cached Kotlin compiler POM is missing')
  const dependencies = [...(await Bun.file(pom).text()).matchAll(/<dependency>\s*<groupId>([^<]+)<\/groupId>\s*<artifactId>([^<]+)<\/artifactId>\s*<version>([^<]+)<\/version>/g)].map(([, group, artifact, version]) => {
    const jar = jars.find(path => path.includes(`/${group}/${artifact}/${version}/`))
    if (!jar) throw new Error(`Build Android first: missing ${artifact} ${version}`)
    return jar
  })
  const annotations = jars.find(path => path.includes('/org.jetbrains/annotations/'))
  const classpath = [compiler, ...dependencies, annotations].filter(Boolean).join(delimiter)
  const directory = await mkdtemp(join(tmpdir(), 'hq-android-input-'))
  try {
    const source = join(directory, 'InputEcho.kt')
    await Bun.write(source, `${helper}\n${await Bun.file(new URL('./fixtures/input-echo.kt', import.meta.url)).text()}`)
    const compile = Bun.spawnSync(['java', '-cp', classpath, 'org.jetbrains.kotlin.cli.jvm.K2JVMCompiler', '-no-stdlib', '-no-reflect', '-classpath', [standard, classpath].join(delimiter), '-d', directory, source], { stdout: 'inherit', stderr: 'inherit' })
    if (compile.exitCode) throw new Error('Kotlin input regression did not compile')
    const run = Bun.spawnSync(['java', '-cp', [directory, standard].join(delimiter), 'InputEchoKt'], { stdout: 'inherit', stderr: 'inherit' })
    if (run.exitCode) throw new Error('Android input regression failed')
  }
  finally {
    await rm(directory, { recursive: true, force: true })
  }

}, 60_000)
