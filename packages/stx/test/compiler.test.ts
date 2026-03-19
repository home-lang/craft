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

  test('parse client script', () => {
    const source = `<script client>const x = 1</script>`
    const desc = parse(source)
    expect(desc.scriptClient).not.toBeNull()
    expect(desc.scriptClient!.content).toBe('const x = 1')
  })

  test('parse server script', () => {
    const source = `<script server>const y = 2</script>`
    const desc = parse(source)
    expect(desc.scriptServer).not.toBeNull()
    expect(desc.scriptServer!.content).toBe('const y = 2')
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

<script client>
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
<script client>
const msg = state('hello')
</script>
<template><p>{{ msg() }}</p></template>
`
    const output = compile(source)
    expect(output).toContain("const msg = state('hello')")
    expect(output).toContain('export default function render()')
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

  test('compile scoped styles', () => {
    const source = `
<template><div>hi</div></template>
<style scoped>div { color: red; }</style>
`
    const output = compile(source, { filename: 'test.stx' })
    expect(output).toContain('document.createElement')
    expect(output).toContain('data-v-')
  })

  test('import stx runtime', () => {
    const source = `<template><div>hi</div></template>`
    const output = compile(source)
    expect(output).toContain("from '@craft-native/stx'")
  })
})
