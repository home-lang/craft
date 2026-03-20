/**
 * STX SFC Parser
 *
 * Parses .stx files into a descriptor with template, script, and style blocks.
 *
 * Features:
 * - Scripts are TypeScript by default (no lang="ts" needed)
 * - <script> = client TS, <script server> = server TS, <script js> = plain JS
 * - Tracks script language for Bun.Transpiler routing
 */

export interface SFCBlock {
  content: string
  attrs: Record<string, string | true>
  lang: 'ts' | 'js'
  start: number
  end: number
}

export interface SFCDescriptor {
  template: SFCBlock | null
  scriptServer: SFCBlock | null
  scriptClient: SFCBlock | null
  styles: SFCBlock[]
  filename: string
}

const blockRegex = /<(template|script|style)(\s[^>]*)?>([^]*?)<\/\1>/g

function parseAttrs(raw: string | undefined): Record<string, string | true> {
  const attrs: Record<string, string | true> = {}
  if (!raw) return attrs

  const attrRegex = /(\w[\w-]*)(?:="([^"]*)")?/g
  let match
  // eslint-disable-next-line no-cond-assign
  while ((match = attrRegex.exec(raw)) !== null) {
    attrs[match[1]] = match[2] ?? true
  }

  return attrs
}

function resolveScriptLang(attrs: Record<string, string | true>): 'ts' | 'js' {
  // TypeScript by default. Opt out with <script js> or <script lang="js">
  if (attrs.js === true) return 'js'
  if (attrs.lang === 'js' || attrs.lang === 'javascript') return 'js'
  return 'ts'
}

/**
 * Parse an .stx file into its constituent blocks.
 */
export function parse(source: string, filename: string = 'anonymous.stx'): SFCDescriptor {
  const descriptor: SFCDescriptor = {
    template: null,
    scriptServer: null,
    scriptClient: null,
    styles: [],
    filename,
  }

  let match
  // eslint-disable-next-line no-cond-assign
  while ((match = blockRegex.exec(source)) !== null) {
    const [fullMatch, tag, rawAttrs, content] = match
    const attrs = parseAttrs(rawAttrs)
    const block: SFCBlock = {
      content: content.trim(),
      attrs,
      lang: tag === 'script' ? resolveScriptLang(attrs) : 'ts',
      start: match.index,
      end: match.index + fullMatch.length,
    }

    switch (tag) {
      case 'template':
        descriptor.template = block
        break
      case 'script':
        if (attrs.server) {
          descriptor.scriptServer = block
        }
        else {
          // <script>, <script client>, <script js>, etc. are all client
          descriptor.scriptClient = block
        }
        break
      case 'style':
        descriptor.styles.push(block)
        break
    }
  }

  return descriptor
}
