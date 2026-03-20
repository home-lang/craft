import { describe, expect, test } from 'bun:test'
import { parse } from '../src/compiler/parser'
import { compile } from '../src/compiler/compile'

describe('parser', () => {
  test('parse template block', () => {
    const source = `<template><div>Hello</div></template>`
    const desc = parse(source)
    expect(desc.template).not.toBeNull()
    expect(desc.template!.content).toBe('<div>Hello</div>')
  })

  test('parse bare script as client TS by default', () => {
    const source = `<script>const x: number = 1</script>`
    const desc = parse(source)
    expect(desc.scriptClient).not.toBeNull()
    expect(desc.scriptClient!.lang).toBe('ts')
    expect(desc.scriptClient!.content).toBe('const x: number = 1')
  })

  test('parse <script client> as client TS', () => {
    const source = `<script client>const x = 1</script>`
    const desc = parse(source)
    expect(desc.scriptClient).not.toBeNull()
    expect(desc.scriptClient!.lang).toBe('ts')
  })

  test('parse <script server>', () => {
    const source = `<script server>const y = 2</script>`
    const desc = parse(source)
    expect(desc.scriptServer).not.toBeNull()
    expect(desc.scriptServer!.lang).toBe('ts')
    expect(desc.scriptServer!.content).toBe('const y = 2')
  })

  test('parse <script js> opts out of TypeScript', () => {
    const source = `<script js>var x = 1</script>`
    const desc = parse(source)
    expect(desc.scriptClient).not.toBeNull()
    expect(desc.scriptClient!.lang).toBe('js')
  })

  test('parse <script lang="js"> opts out of TypeScript', () => {
    const source = `<script lang="js">var x = 1</script>`
    const desc = parse(source)
    expect(desc.scriptClient).not.toBeNull()
    expect(desc.scriptClient!.lang).toBe('js')
  })

  test('parse scoped style', () => {
    const source = `<style scoped>h1 { color: red; }</style>`
    const desc = parse(source)
    expect(desc.styles.length).toBe(1)
    expect(desc.styles[0].attrs.scoped).toBe(true)
    expect(desc.styles[0].content).toBe('h1 { color: red; }')
  })

  test('parse full SFC', () => {
    const source = `
<script server>
const title = 'Hello'
</script>

<script>
const count = state(0)
</script>

<template>
  <div class="container">
    <h1>{{ title }}</h1>
  </div>
</template>

<style scoped>
.container { padding: 1rem; }
</style>
`
    const desc = parse(source)
    expect(desc.scriptServer).not.toBeNull()
    expect(desc.scriptClient).not.toBeNull()
    expect(desc.template).not.toBeNull()
    expect(desc.styles.length).toBe(1)
  })

  test('parse empty source', () => {
    const desc = parse('')
    expect(desc.template).toBeNull()
    expect(desc.scriptClient).toBeNull()
    expect(desc.scriptServer).toBeNull()
    expect(desc.styles.length).toBe(0)
  })
})

describe('compile', () => {
  test('compile template with interpolation', () => {
    const source = `<template><h1>{{ title }}</h1></template>`
    const output = compile(source)
    expect(output).toContain('h(')
    expect(output).toContain('title')
  })

  test('compile with client script', () => {
    const source = `
<script>
const msg = state('hello')
</script>
<template><p>{{ msg() }}</p></template>
`
    const output = compile(source)
    // Bun.Transpiler may normalize quotes
    expect(output).toMatch(/const msg = state\(["']hello["']\)/)
    expect(output).toContain('function')
  })

  test('include server script only in SSR mode', () => {
    const source = `
<script server>const x = 1</script>
<template><div>hi</div></template>
`
    const clientOutput = compile(source, { ssr: false })
    expect(clientOutput).not.toContain('const x = 1')

    const ssrOutput = compile(source, { ssr: true })
    expect(ssrOutput).toContain('const x = 1')
  })

  test('scoped styles use data-v-stx- prefix', () => {
    const source = `
<template><div>hi</div></template>
<style scoped>div { color: red; }</style>
`
    const output = compile(source, { filename: 'test.stx' })
    expect(output).toContain('data-v-stx-')
    expect(output).toContain('data-stx-scope')
  })

  test('composition API auto-imported from window.stx', () => {
    const source = `<template><div>hi</div></template>`
    const output = compile(source)
    expect(output).toContain('window.stx')
    expect(output).toContain('defineProps')
    expect(output).toContain('defineEmits')
    expect(output).toContain('withDefaults')
  })

  test('auto-binding when script decls match template refs', () => {
    const source = `
<script>
const count = state(0)
const name = 'world'
</script>
<template>
  <div>
    <p>{{ count() }}</p>
    <p>{{ name }}</p>
  </div>
</template>
`
    const output = compile(source)
    // Auto-binding should detect count and name are used in template
    expect(output).toContain('Auto-bound by stx compiler')
    expect(output).toContain("mount(__stx_render, '#app')")
  })

  test('no auto-binding when mount() is explicit', () => {
    const source = `
<script>
const count = state(0)
mount(render, '#app')
</script>
<template><p>{{ count() }}</p></template>
`
    const output = compile(source)
    expect(output).not.toContain('Auto-bound')
  })

  test('no auto-binding when no template refs match', () => {
    const source = `
<script>
const x = 1
</script>
<template><p>Hello world</p></template>
`
    const output = compile(source)
    expect(output).not.toContain('Auto-bound')
    expect(output).toContain('export default function render()')
  })

  test('scope ID is deterministic from filename', () => {
    const source = `
<template><div>hi</div></template>
<style scoped>div { color: red; }</style>
`
    const output1 = compile(source, { filename: 'components/Card.stx' })
    const output2 = compile(source, { filename: 'components/Card.stx' })
    const output3 = compile(source, { filename: 'components/Button.stx' })

    // Same filename = same scope ID
    expect(output1).toBe(output2)
    // Different filename = different scope ID
    expect(output1).not.toBe(output3)
  })

  test('scope attribute injected into template root', () => {
    const source = `
<template><div class="foo">hi</div></template>
<style scoped>div { color: red; }</style>
`
    const output = compile(source, { filename: 'test.stx' })
    // The h() call should include the scope attribute
    expect(output).toContain('data-v-stx-')
  })

  test('non-scoped styles pass through unchanged', () => {
    const source = `
<template><div>hi</div></template>
<style>.global { color: blue; }</style>
`
    const output = compile(source)
    expect(output).toContain('.global { color: blue; }')
    expect(output).not.toContain('data-v-stx-')
  })

  test('slot compilation', () => {
    const source = `<template><slot /></template>`
    const output = compile(source)
    expect(output).toContain('__slots')
  })
})
