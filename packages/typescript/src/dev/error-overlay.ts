/**
 * Craft Error Overlay
 * Visual error display for development with helpful suggestions
 */

// Types
export interface ErrorInfo {
  message: string
  stack?: string
  source?: string
  line?: number
  column?: number
  componentStack?: string
  suggestions?: string[]
}

export interface ErrorOverlayConfig {
  enableOverlay?: boolean
  enableConsole?: boolean
  dismissOnClick?: boolean
  position?: 'top' | 'bottom' | 'center'
}

// Error patterns and suggestions
const ERROR_PATTERNS: Array<{
  pattern: RegExp
  suggestion: string
}> = [
  {
    pattern: /Cannot read propert(y|ies) .* of (undefined|null)/i,
    suggestion:
      'Check if the object exists before accessing its properties. Use optional chaining (?.) or null checks.',
  },
  {
    pattern: /is not a function/i,
    suggestion:
      'Verify the variable is actually a function. Check for typos in the function name or ensure it is imported correctly.',
  },
  {
    pattern: /is not defined/i,
    suggestion:
      'The variable or function is not in scope. Check imports, ensure correct spelling, or verify it is declared.',
  },
  {
    pattern: /Cannot find module/i,
    suggestion:
      'The module could not be found. Check the import path, ensure the package is installed, or verify the file exists.',
  },
  {
    pattern: /Maximum call stack/i,
    suggestion:
      'Infinite recursion detected. Check for functions calling themselves without a proper base case.',
  },
  {
    pattern: /Unexpected token/i,
    suggestion:
      'Syntax error in your code. Check for missing brackets, semicolons, or invalid JavaScript syntax.',
  },
  {
    pattern: /Cannot set propert/i,
    suggestion:
      'Attempting to set a property on undefined/null. Ensure the object is initialized before setting properties.',
  },
  {
    pattern: /Network request failed/i,
    suggestion:
      'The network request could not be completed. Check your internet connection, API URL, and CORS settings.',
  },
  {
    pattern: /CORS/i,
    suggestion:
      'Cross-Origin Resource Sharing error. The server needs to include proper CORS headers or use a proxy.',
  },
  {
    pattern: /Failed to fetch/i,
    suggestion:
      'Network request failed. Check if the server is running, the URL is correct, and there are no CORS issues.',
  },
  {
    pattern: /SyntaxError.*JSON/i,
    suggestion:
      'Invalid JSON format. Check the JSON syntax - ensure proper quotes, commas, and no trailing commas.',
  },
  {
    pattern: /Cannot access .* before initialization/i,
    suggestion:
      'Temporal dead zone error. The variable is accessed before its declaration. Move the declaration up or use var.',
  },
  {
    pattern: /Assignment to constant/i,
    suggestion: 'Cannot reassign a const variable. Use let instead if the value needs to change.',
  },
  {
    pattern: /Invalid hook call/i,
    suggestion:
      'Hooks can only be called inside function components. Ensure you are not calling hooks conditionally or in loops.',
  },
  {
    pattern: /Each child.*unique.*key/i,
    suggestion:
      'React list items need unique key props. Add a unique key prop to each item in the array.',
  },
]

// Parse error to extract useful information
function parseError(error: Error | string): ErrorInfo {
  const isError = error instanceof Error
  const message = isError ? error.message : String(error)
  const stack = isError ? error.stack : undefined

  let source: string | undefined
  let line: number | undefined
  let column: number | undefined

  // Try to extract location from stack
  if (stack) {
    const match = stack.match(/at .+ \((.+):(\d+):(\d+)\)/)
    if (match) {
      source = match[1]
      line = parseInt(match[2])
      column = parseInt(match[3])
    }
  }

  // Generate suggestions
  const suggestions: string[] = []
  for (const { pattern, suggestion } of ERROR_PATTERNS) {
    if (pattern.test(message)) {
      suggestions.push(suggestion)
    }
  }

  return {
    message,
    stack,
    source,
    line,
    column,
    suggestions,
  }
}

// Format stack trace for display
function formatStackTrace(stack: string): string {
  return stack
    .split('\n')
    .map((line) => {
      // Highlight file paths
      line = line.replace(
        /\((.+?):(\d+):(\d+)\)/g,
        '<span class="stack-location">($1:<span class="stack-line">$2</span>:$3)</span>'
      )
      // Highlight function names
      line = line.replace(/at (\S+)/, 'at <span class="stack-function">$1</span>')
      return line
    })
    .join('\n')
}

// Generate overlay HTML
function generateOverlayHtml(error: ErrorInfo, config: ErrorOverlayConfig): string {
  const positionStyles =
    config.position === 'top'
      ? 'top: 0; bottom: auto;'
      : config.position === 'bottom'
        ? 'top: auto; bottom: 0;'
        : 'top: 50%; transform: translateY(-50%);'

  return `
<div id="craft-error-overlay" style="
  position: fixed;
  ${positionStyles}
  left: 0;
  right: 0;
  z-index: 99999;
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  font-size: 14px;
  line-height: 1.5;
">
  <div style="
    background: #1e1e1e;
    color: #f8f8f2;
    max-height: 80vh;
    overflow: auto;
    box-shadow: 0 4px 24px rgba(0,0,0,0.5);
  ">
    <!-- Header -->
    <div style="
      background: #cc3333;
      color: white;
      padding: 12px 16px;
      display: flex;
      justify-content: space-between;
      align-items: center;
    ">
      <div style="display: flex; align-items: center; gap: 8px;">
        <span style="font-size: 20px;">⚠️</span>
        <span style="font-weight: 600;">Runtime Error</span>
      </div>
      <button id="craft-error-close" style="
        background: rgba(255,255,255,0.2);
        border: none;
        color: white;
        padding: 4px 12px;
        border-radius: 4px;
        cursor: pointer;
        font-size: 14px;
      ">✕ Close</button>
    </div>

    <!-- Error Message -->
    <div style="padding: 16px; border-bottom: 1px solid #333;">
      <div style="
        color: #ff6b6b;
        font-size: 18px;
        font-weight: 500;
        margin-bottom: 8px;
        word-break: break-word;
      ">${escapeHtml(error.message)}</div>

      ${
        error.source
          ? `
        <div style="color: #888; font-size: 12px;">
          ${escapeHtml(error.source)}${error.line ? `:${error.line}` : ''}${error.column ? `:${error.column}` : ''}
        </div>
      `
          : ''
      }
    </div>

    ${
      error.suggestions && error.suggestions.length > 0
        ? `
      <!-- Suggestions -->
      <div style="padding: 16px; background: #252526; border-bottom: 1px solid #333;">
        <div style="color: #569cd6; font-weight: 600; margin-bottom: 8px;">💡 Suggestions</div>
        <ul style="margin: 0; padding-left: 20px; color: #9cdcfe;">
          ${error.suggestions.map((s) => `<li style="margin-bottom: 4px;">${escapeHtml(s)}</li>`).join('')}
        </ul>
      </div>
    `
        : ''
    }

    ${
      error.stack
        ? `
      <!-- Stack Trace -->
      <div style="padding: 16px;">
        <div style="color: #888; font-weight: 600; margin-bottom: 8px;">Stack Trace</div>
        <pre style="
          margin: 0;
          white-space: pre-wrap;
          word-break: break-word;
          color: #888;
          font-size: 12px;
        "><style>
          .stack-location { color: #6a9955; }
          .stack-line { color: #b5cea8; }
          .stack-function { color: #dcdcaa; }
        </style>${formatStackTrace(error.stack)}</pre>
      </div>
    `
        : ''
    }

    ${
      error.componentStack
        ? `
      <!-- Component Stack -->
      <div style="padding: 16px; border-top: 1px solid #333;">
        <div style="color: #888; font-weight: 600; margin-bottom: 8px;">Component Stack</div>
        <pre style="
          margin: 0;
          white-space: pre-wrap;
          color: #ce9178;
          font-size: 12px;
        ">${escapeHtml(error.componentStack)}</pre>
      </div>
    `
        : ''
    }

    <!-- Actions -->
    <div style="padding: 12px 16px; background: #252526; display: flex; gap: 8px;">
      <button onclick="location.reload()" style="
        background: #0e639c;
        color: white;
        border: none;
        padding: 8px 16px;
        border-radius: 4px;
        cursor: pointer;
        font-size: 14px;
      ">🔄 Reload Page</button>
      <button id="craft-error-copy" style="
        background: #3c3c3c;
        color: white;
        border: none;
        padding: 8px 16px;
        border-radius: 4px;
        cursor: pointer;
        font-size: 14px;
      ">📋 Copy Error</button>
    </div>
  </div>
</div>
<script>
  document.getElementById('craft-error-close').onclick = function() {
    document.getElementById('craft-error-overlay').remove();
  };
  document.getElementById('craft-error-copy').onclick = function() {
    navigator.clipboard.writeText(${JSON.stringify(error.message + '\n\n' + (error.stack || ''))});
    this.textContent = '✓ Copied!';
    setTimeout(() => this.textContent = '📋 Copy Error', 2000);
  };
  ${config.dismissOnClick ? `document.getElementById('craft-error-overlay').onclick = function(e) { if (e.target === this) this.remove(); };` : ''}
</script>
`
}

function escapeHtml(str: string): string {
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;')
}

// Error Overlay class
export class ErrorOverlay {
  private config: ErrorOverlayConfig
  private currentError: ErrorInfo | null = null

  constructor(config: ErrorOverlayConfig = {}) {
    this.config = {
      enableOverlay: true,
      enableConsole: true,
      dismissOnClick: true,
      position: 'top',
      ...config,
    }
  }

  /**
   * Show error overlay
   */
  show(error: Error | string, componentStack?: string): void {
    const errorInfo = parseError(error)
    if (componentStack) {
      errorInfo.componentStack = componentStack
    }

    this.currentError = errorInfo

    if (this.config.enableConsole) {
      console.error('[Craft Error]', errorInfo.message)
      if (errorInfo.stack) {
        console.error(errorInfo.stack)
      }
    }

    if (this.config.enableOverlay && typeof document !== 'undefined') {
      // Remove existing overlay
      this.hide()

      // Insert new overlay
      const container = document.createElement('div')
      container.innerHTML = generateOverlayHtml(errorInfo, this.config)
      document.body.appendChild(container.firstElementChild!)
    }
  }

  /**
   * Hide error overlay
   */
  hide(): void {
    if (typeof document !== 'undefined') {
      const existing = document.getElementById('craft-error-overlay')
      if (existing) {
        existing.remove()
      }
    }
    this.currentError = null
  }

  /**
   * Get current error
   */
  getCurrentError(): ErrorInfo | null {
    return this.currentError
  }

  /**
   * Install global error handlers
   */
  install(): void {
    if (typeof window === 'undefined') return

    // Handle uncaught errors
    window.onerror = (message, source, line, column, error) => {
      const errorInfo = error ? parseError(error) : parseError(String(message))
      errorInfo.source = source || undefined
      errorInfo.line = line || undefined
      errorInfo.column = column || undefined
      this.show(error || String(message))
      return false // Don't prevent default handling
    }

    // Handle unhandled promise rejections
    window.onunhandledrejection = (event) => {
      this.show(event.reason)
    }
  }

  /**
   * Uninstall global error handlers
   */
  uninstall(): void {
    if (typeof window === 'undefined') return
    window.onerror = null
    window.onunhandledrejection = null
  }
}

// React error boundary support
export function createReactErrorBoundary(overlay: ErrorOverlay) {
  return class ErrorBoundary {
    state = { hasError: false }

    static getDerivedStateFromError() {
      return { hasError: true }
    }

    componentDidCatch(error: Error, errorInfo: { componentStack: string }) {
      overlay.show(error, errorInfo.componentStack)
    }

    render() {
      if (this.state.hasError) {
        return null
      }
      // @ts-ignore
      return this.props.children
    }
  }
}

// Global instance
let globalOverlay: ErrorOverlay | null = null

export function getErrorOverlay(): ErrorOverlay {
  if (!globalOverlay) {
    globalOverlay = new ErrorOverlay()
  }
  return globalOverlay
}

export function showError(error: Error | string): void {
  getErrorOverlay().show(error)
}

export function hideError(): void {
  getErrorOverlay().hide()
}

export default ErrorOverlay
