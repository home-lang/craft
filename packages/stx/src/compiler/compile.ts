/**
 * STX SFC Compiler
 *
 * Transforms a parsed SFC descriptor into executable JavaScript.
 *
 * Features:
 * - TypeScript-first: scripts transpiled via Bun.Transpiler
 * - Auto-binding: scans template refs, auto-wraps stx.mount() if needed
 * - Scoped styles: data-v-stx-{hash} attribute selector (deterministic from file path)
 * - Composition API: defineProps/defineEmits/withDefaults on window.stx, auto-imported
 * - Props hydration: data-stx-props serialization on component elements
 */

import { parse } from './parser'
import type { SFCDescriptor, SFCBlock } from './parser'

export interface CompileOptions {
  filename?: string
  ssr?: boolean
}

// ============================================================================
// Template reference scanning (Auto-binding)
// ============================================================================

/**
 * Scan template for identifiers referenced in {{ }}, :attr, @event, @model, @for
 */
function scanTemplateRefs(template: string): Set<string> {
  const refs = new Set<string>()
  const identRegex = /[a-zA-Z_$][\w$]*/g

  // {{ expr }}
  const interpRegex = /\{\{(.*?)\}\}/g
  let match
  // eslint-disable-next-line no-cond-assign
  while ((match = interpRegex.exec(template)) !== null) {
    let ident
    // eslint-disable-next-line no-cond-assign
    while ((ident = identRegex.exec(match[1])) !== null) {
      refs.add(ident[0])
    }
  }

  // :attr="expr" and @directive="expr"
  const directiveRegex = /[@:][\w.:-]+="([^"]*)"/g
  // eslint-disable-next-line no-cond-assign
  while ((match = directiveRegex.exec(template)) !== null) {
    let ident
    // eslint-disable-next-line no-cond-assign
    while ((ident = identRegex.exec(match[1])) !== null) {
      refs.add(ident[0])
    }
  }

  return refs
}

/**
 * Scan script for top-level declarations (const, let, var, function)
 */
function scanScriptDeclarations(script: string): Set<string> {
  const decls = new Set<string>()
  const declRegex = /(?:^|\n)\s*(?:export\s+)?(?:const|let|var|function)\s+(\w+)/g
  let match
  // eslint-disable-next-line no-cond-assign
  while ((match = declRegex.exec(script)) !== null) {
    decls.add(match[1])
  }
  return decls
}

/**
 * Check if script already contains stx.mount() or mount()
 */
function hasExplicitMount(script: string): boolean {
  return /\b(?:stx\.)?mount\s*\(/.test(script)
}

// ============================================================================
// TypeScript transpilation
// ============================================================================

/**
 * Transpile TypeScript to JavaScript using Bun.Transpiler
 */
function transpileTS(code: string, _lang: 'ts' | 'js'): string {
  if (_lang === 'js') return code

  // Use Bun.Transpiler for type stripping
  if (typeof Bun !== 'undefined' && Bun.Transpiler) {
    const transpiler = new Bun.Transpiler({ loader: 'ts' })
    return transpiler.transformSync(code)
  }

  // Fallback: basic type annotation stripping for non-Bun environments
  return code
    .replace(/:\s*\w[\w<>,\s|&\[\]]*(?=\s*[=;,)\n{])/g, '')
    .replace(/\bas\s+\w+/g, '')
    .replace(/<\w[\w<>,\s|&]*>/g, '')
}

// ============================================================================
// Scoped styles
// ============================================================================

/**
 * Generate deterministic scope ID from file path.
 * Format: data-v-stx-{hash}
 */
function generateScopeId(filename: string): string {
  let hash = 0
  for (let i = 0; i < filename.length; i++) {
    hash = ((hash << 5) - hash + filename.charCodeAt(i)) | 0
  }
  return `data-v-stx-${Math.abs(hash).toString(36)}`
}

/**
 * Scope CSS selectors with attribute selector.
 * Handles @media, @keyframes, nested selectors.
 */
function scopeCSS(css: string, scopeId: string): string {
  const lines = css.split('\n')
  const result: string[] = []
  let inAtRule = 0

  for (const line of lines) {
    const trimmed = line.trim()

    // Track @-rule nesting
    if (trimmed.startsWith('@media') || trimmed.startsWith('@supports')) {
      result.push(line)
      if (trimmed.includes('{')) inAtRule++
      continue
    }

    if (trimmed.startsWith('@keyframes') || trimmed.startsWith('@font-face')) {
      result.push(line)
      if (trimmed.includes('{')) inAtRule++
      continue
    }

    // Closing brace for @-rules
    if (trimmed === '}' && inAtRule > 0) {
      inAtRule--
      result.push(line)
      continue
    }

    // Selector line (contains { but not @)
    if (trimmed.includes('{') && !trimmed.startsWith('@')) {
      const parts = trimmed.split('{')
      const selector = parts[0]
      const rest = parts.slice(1).join('{')

      const scopedSelector = selector
        .split(',')
        .map((s) => {
          const sel = s.trim()
          if (!sel) return sel
          // Don't scope :root or * or keyframe steps
          if (sel === ':root' || sel === '*' || /^\d+%$/.test(sel) || sel === 'from' || sel === 'to') {
            return sel
          }
          return `${sel}[${scopeId}]`
        })
        .join(', ')

      result.push(`${scopedSelector} {${rest}`)
      continue
    }

    result.push(line)
  }

  return result.join('\n')
}

// ============================================================================
// Template compiler
// ============================================================================

function compileTemplate(template: string, scopeId?: string): string {
  const trimmed = template.trim()

  // Single root element
  const rootMatch = trimmed.match(/^<(\w[\w-]*)((?:\s+[^>]*)?)>([\s\S]*)<\/\1>$/)
  if (rootMatch) {
    const [, tag, attrsRaw, inner] = rootMatch
    const attrs = compileAttrs(attrsRaw.trim(), scopeId)
    const children = compileChildren(inner.trim(), scopeId)
    return `h('${tag}', ${attrs}${children ? `, ${children}` : ''})`
  }

  // Self-closing element
  const selfClose = trimmed.match(/^<(\w[\w-]*)((?:\s+[^>]*)?)?\s*\/>$/)
  if (selfClose) {
    const [, tag, attrsRaw] = selfClose

    // <slot /> — content projection
    if (tag === 'slot') {
      return `__slots.default ? __slots.default() : ''`
    }

    const attrs = compileAttrs((attrsRaw || '').trim(), scopeId)
    return `h('${tag}', ${attrs})`
  }

  return compileTextNode(trimmed)
}

function compileAttrs(raw: string, scopeId?: string): string {
  const attrs: string[] = []

  if (raw) {
    const attrRegex = /([@:]?[\w.:-]+)(?:="([^"]*)")?/g
    let match

    // eslint-disable-next-line no-cond-assign
    while ((match = attrRegex.exec(raw)) !== null) {
      const [, key, value] = match

      if (key.startsWith('@')) {
        attrs.push(`'${key}': ${value ?? 'true'}`)
      }
      else if (key.startsWith(':')) {
        const attrName = key.slice(1)
        attrs.push(`'${attrName}': ${value}`)
      }
      else if (value !== undefined) {
        if (value.includes('{{')) {
          const expr = value.replace(/\{\{(.*?)\}\}/g, (_, e) => `\${${e.trim()}}`)
          attrs.push(`'${key}': \`${expr}\``)
        }
        else {
          attrs.push(`'${key}': '${value}'`)
        }
      }
      else {
        attrs.push(`'${key}': true`)
      }
    }
  }

  // Inject scope attribute for scoped styles
  if (scopeId) {
    attrs.push(`'${scopeId}': true`)
  }

  return `{ ${attrs.join(', ')} }`
}

function compileChildren(inner: string, scopeId?: string): string {
  if (!inner) return ''

  const parts: string[] = []
  const childRegex = /(<\w[\s\S]*?(?:\/>|<\/\w[\w-]*>))|([^<]+)/g
  let match

  // eslint-disable-next-line no-cond-assign
  while ((match = childRegex.exec(inner)) !== null) {
    if (match[1]) {
      parts.push(compileTemplate(match[1].trim(), scopeId))
    }
    else if (match[2]?.trim()) {
      parts.push(compileTextNode(match[2].trim()))
    }
  }

  return parts.join(', ')
}

// eslint-disable-next-line pickier/no-unused-vars
function compileTextNode(text: string): string {
  if (text.includes('{{')) {
    const expr = text.replace(/\{\{(.*?)\}\}/g, (_, e) => `\${${e.trim()}}`)
    return `\`${expr}\``
  }
  return `'${text.replace(/'/g, "\\'")}'`
}

// ============================================================================
// Main compiler
// ============================================================================

/**
 * Compile an .stx source string into JavaScript module code.
 */
export function compile(source: string, options: CompileOptions = {}): string {
  const filename = options.filename ?? 'component.stx'
  const descriptor = parse(source, filename)
  const parts: string[] = []

  // Determine scope ID for scoped styles
  const hasScoped = descriptor.styles.some(s => s.attrs.scoped === true)
  const scopeId = hasScoped ? generateScopeId(filename) : undefined

  // Composition API available on window.stx (auto-imported)
  parts.push(`// Auto-imported from window.stx`)
  parts.push(`const { defineProps, defineEmits, withDefaults, defineExpose, state, derived, effect, batch, untrack, peek, isSignal, isDerived, onMount, onDestroy, onUpdate, onMounted, onUnmounted, onUpdated, onBeforeMount, onBeforeUpdate, onBeforeUnmount, h, mount, provide, inject, nextTick, useRef, navigate } = window.stx || {};`)
  parts.push(``)

  // Server script (only in SSR mode)
  if (options.ssr && descriptor.scriptServer) {
    parts.push(`// --- server ---`)
    const code = transpileTS(descriptor.scriptServer.content, descriptor.scriptServer.lang)
    parts.push(code)
  }

  // Client script — transpile TS
  let clientCode = ''
  if (descriptor.scriptClient) {
    clientCode = transpileTS(descriptor.scriptClient.content, descriptor.scriptClient.lang)
  }

  // Template -> render function
  if (descriptor.template) {
    const renderCode = compileTemplate(descriptor.template.content, scopeId)

    // Auto-binding: check if script needs auto-wrapping
    const templateRefs = scanTemplateRefs(descriptor.template.content)
    const scriptDecls = clientCode ? scanScriptDeclarations(clientCode) : new Set<string>()
    const needsAutoMount = templateRefs.size > 0
      && scriptDecls.size > 0
      && !hasExplicitMount(clientCode)
      && [...templateRefs].some(ref => scriptDecls.has(ref))

    parts.push(``)

    if (needsAutoMount) {
      // Scope isolation: wrap script declarations and render in the same
      // stx.mount() IIFE so all declarations share a scope. This matches
      // how stx evaluates expressions via new Function(...Object.keys(scope), expr).
      parts.push(`// Auto-bound by stx compiler`)
      parts.push(`if (typeof document !== 'undefined') {`)
      parts.push(`  stx.mount(() => {`)
      if (clientCode) {
        // Indent client code inside the mount scope
        for (const line of clientCode.split('\n')) {
          parts.push(`    ${line}`)
        }
      }
      parts.push(``)
      parts.push(`    return ${renderCode};`)
      parts.push(`  }, '#app');`)
      parts.push(`}`)
    }
    else {
      // No auto-binding — emit script and render separately
      if (clientCode) {
        parts.push(`// --- client ---`)
        parts.push(clientCode)
        parts.push(``)
      }
      parts.push(`export default function render() {`)
      parts.push(`  return ${renderCode};`)
      parts.push(`}`)
    }
  }
  else if (clientCode) {
    // No template, just client script
    parts.push(`// --- client ---`)
    parts.push(clientCode)
  }

  // Scoped styles (data-v-stx-{hash})
  for (const style of descriptor.styles) {
    const isScoped = style.attrs.scoped === true
    const cssStr = isScoped && scopeId ? scopeCSS(style.content, scopeId) : style.content

    parts.push(``)
    parts.push(`// --- style ---`)
    parts.push(`if (typeof document !== 'undefined') {`)
    parts.push(`  const __style = document.createElement('style');`)
    parts.push(`  __style.textContent = ${JSON.stringify(cssStr)};`)
    if (isScoped && scopeId) {
      parts.push(`  __style.setAttribute('data-stx-scope', '${scopeId}');`)
    }
    parts.push(`  document.head.appendChild(__style);`)
    parts.push(`}`)
  }

  return parts.join('\n')
}
