/**
 * STX SFC Compiler
 *
 * Transforms a parsed SFC descriptor into executable JavaScript.
 * Handles:
 *   - {{ expr }} interpolation in templates
 *   - @ directives (@click, @model, @show, @if, @for, @class, @bind:*)
 *   - <slot /> content projection
 *   - Scoped styles via attribute selectors
 */

import { parse } from './parser'
import type { SFCDescriptor } from './parser'

export interface CompileOptions {
  filename?: string
  ssr?: boolean
}

/**
 * Compile an .stx source string into JavaScript module code.
 */
export function compile(source: string, options: CompileOptions = {}): string {
  const filename = options.filename ?? 'component.stx'
  const descriptor = parse(source, filename)

  const parts: string[] = []

  // Imports
  parts.push(`import { h, mount, state, derived, effect, onMount, onDestroy, onUpdate } from '@craft-native/stx';`)

  // Server script (only in SSR mode)
  if (options.ssr && descriptor.scriptServer) {
    parts.push(`// --- server ---`)
    parts.push(descriptor.scriptServer.content)
  }

  // Client script
  if (descriptor.scriptClient) {
    parts.push(`// --- client ---`)
    parts.push(descriptor.scriptClient.content)
  }

  // Template -> render function
  if (descriptor.template) {
    const renderCode = compileTemplate(descriptor.template.content)
    parts.push(``)
    parts.push(`export default function render() {`)
    parts.push(`  return ${renderCode};`)
    parts.push(`}`)
  }

  // Scoped styles
  for (const style of descriptor.styles) {
    const scopeId = generateScopeId(filename)
    const isScoped = style.attrs.scoped === true
    const cssStr = isScoped ? scopeCSS(style.content, scopeId) : style.content

    parts.push(``)
    parts.push(`// --- style ---`)
    parts.push(`if (typeof document !== 'undefined') {`)
    parts.push(`  const __style = document.createElement('style');`)
    parts.push(`  __style.textContent = ${JSON.stringify(cssStr)};`)
    parts.push(`  document.head.appendChild(__style);`)
    parts.push(`}`)
  }

  return parts.join('\n')
}

/**
 * Compile a template string into h() call expressions.
 */
function compileTemplate(template: string): string {
  // Simple template compiler: converts HTML to nested h() calls
  // Handles {{ expr }}, @ directives, and basic HTML elements

  const trimmed = template.trim()

  // If it's a single root element, parse it
  const rootMatch = trimmed.match(/^<(\w[\w-]*)((?:\s+[^>]*)?)>([\s\S]*)<\/\1>$/)
  if (rootMatch) {
    const [, tag, attrsRaw, inner] = rootMatch
    const attrs = compileAttrs(attrsRaw.trim())
    const children = compileChildren(inner.trim())
    return `h('${tag}', ${attrs}${children ? `, ${children}` : ''})`
  }

  // Self-closing element
  const selfClose = trimmed.match(/^<(\w[\w-]*)((?:\s+[^>]*)?)?\s*\/>$/)
  if (selfClose) {
    const [, tag, attrsRaw] = selfClose
    const attrs = compileAttrs((attrsRaw || '').trim())
    return `h('${tag}', ${attrs})`
  }

  // Plain text with potential interpolation
  return compileTextNode(trimmed)
}

function compileAttrs(raw: string): string {
  if (!raw) return '{}'

  const attrs: string[] = []
  // Match attributes: key="value", @directive="value", :bind="value", key
  const attrRegex = /([@:]?[\w.:-]+)(?:="([^"]*)")?/g
  let match

  // eslint-disable-next-line no-cond-assign
  while ((match = attrRegex.exec(raw)) !== null) {
    const [, key, value] = match

    if (key.startsWith('@')) {
      // @ directives — pass as-is, h() handles them
      attrs.push(`'${key}': ${value ?? 'true'}`)
    }
    else if (key.startsWith(':')) {
      // Dynamic binding
      const attrName = key.slice(1)
      attrs.push(`'${attrName}': ${value}`)
    }
    else if (value !== undefined) {
      // Check if value contains {{ }} — make it dynamic
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

  return `{ ${attrs.join(', ')} }`
}

function compileChildren(inner: string): string {
  if (!inner) return ''

  const parts: string[] = []
  // Split into child elements and text nodes
  const childRegex = /(<\w[\s\S]*?(?:\/>|<\/\w[\w-]*>))|([^<]+)/g
  let match

  // eslint-disable-next-line no-cond-assign
  while ((match = childRegex.exec(inner)) !== null) {
    if (match[1]) {
      // Child element
      parts.push(compileTemplate(match[1].trim()))
    }
    else if (match[2]?.trim()) {
      // Text node
      parts.push(compileTextNode(match[2].trim()))
    }
  }

  return parts.join(', ')
}

// eslint-disable-next-line pickier/no-unused-vars
function compileTextNode(text: string): string {
  if (text.includes('{{')) {
    // Template interpolation -> template literal
    const expr = text.replace(/\{\{(.*?)\}\}/g, (_, e) => `\${${e.trim()}}`)
    return `\`${expr}\``
  }
  return `'${text.replace(/'/g, "\\'")}'`
}

function generateScopeId(filename: string): string {
  let hash = 0
  for (let i = 0; i < filename.length; i++) {
    hash = ((hash << 5) - hash + filename.charCodeAt(i)) | 0
  }
  return `data-v-${Math.abs(hash).toString(36)}`
}

function scopeCSS(css: string, scopeId: string): string {
  // Add scope attribute selector to each rule
  return css.replace(
    /([^{}]+)\{/g,
    (_, selector: string) => {
      const scoped = selector
        .split(',')
        .map((s: string) => {
          const trimmed = s.trim()
          if (!trimmed || trimmed.startsWith('@')) return trimmed
          return `${trimmed}[${scopeId}]`
        })
        .join(', ')
      return `${scoped} {`
    },
  )
}
