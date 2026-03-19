/**
 * STX Router
 *
 * Client-side router that fetches page fragments and swaps content.
 * Detects fragments via X-STX-Fragment response header.
 * Uses View Transitions API when available, CSS fallback otherwise.
 */

import { state, effect } from '../runtime'
import type { State } from '../runtime'

export interface Route {
  path: string
  params: Record<string, string>
  query: Record<string, string>
  hash: string
}

export interface RouterOptions {
  /** CSS selector for the content container */
  outlet?: string
  /** Base path prefix to strip */
  base?: string
  /** Callback before navigation */
  onBefore?: (to: Route, from: Route) => boolean | void
  /** Callback after navigation */
  onAfter?: (to: Route) => void
}

let routerState: State<Route> | null = null
let routerOptions: RouterOptions = {}

function parseRoute(url: string, base: string = ''): Route {
  const parsed = new URL(url, window.location.origin)
  let path = parsed.pathname
  if (base && path.startsWith(base)) {
    path = path.slice(base.length) || '/'
  }

  const query: Record<string, string> = {}
  parsed.searchParams.forEach((v, k) => { query[k] = v })

  return {
    path,
    params: {},
    query,
    hash: parsed.hash.slice(1),
  }
}

/**
 * Get the current route state.
 */
export function getCurrentRoute(): State<Route> {
  if (!routerState) {
    routerState = state(parseRoute(window.location.href))
  }
  return routerState
}

/**
 * Navigate to a new path.
 * Fetches fragment HTML and swaps content using View Transitions.
 */
export async function navigate(to: string, opts?: { replace?: boolean }): Promise<void> {
  const currentRoute = getCurrentRoute()
  const newRoute = parseRoute(to, routerOptions.base)

  // onBefore guard
  if (routerOptions.onBefore) {
    const result = routerOptions.onBefore(newRoute, currentRoute())
    if (result === false) return
  }

  // Update browser history
  if (opts?.replace) {
    history.replaceState(null, '', to)
  }
  else {
    history.pushState(null, '', to)
  }

  // Fetch the page fragment
  try {
    const response = await fetch(to, {
      headers: { 'X-STX-Fragment': 'true' },
    })

    const isFragment = response.headers.get('X-STX-Fragment') === 'true'
    const html = await response.text()

    // Swap content
    const outlet = document.querySelector(routerOptions.outlet || '#app')
    if (outlet) {
      await swapContent(outlet, html, isFragment)
    }

    // Update route state
    currentRoute.set(newRoute)

    // onAfter callback
    routerOptions.onAfter?.(newRoute)

    // Scroll to top or hash
    if (newRoute.hash) {
      document.getElementById(newRoute.hash)?.scrollIntoView()
    }
    else {
      window.scrollTo(0, 0)
    }
  }
  catch (err) {
    console.error('[stx-router] Navigation failed:', err)
  }
}

/**
 * Swap content into the outlet, extracting scripts and styles from fragment.
 * Uses View Transitions API when available.
 */
async function swapContent(outlet: Element, html: string, isFragment: boolean): Promise<void> {
  const content = isFragment ? html : stripDocumentWrapper(html)

  const doSwap = () => {
    // Parse the fragment to extract styles and scripts
    const temp = document.createElement('div')
    temp.innerHTML = content

    // Extract and inject styles into <head>
    const styles = temp.querySelectorAll('style, link[rel="stylesheet"]')
    styles.forEach((style) => {
      const clone = style.cloneNode(true) as Element
      document.head.appendChild(clone)
      style.remove()
    })

    // Swap HTML
    outlet.innerHTML = temp.innerHTML

    // Extract and re-execute scripts
    const scripts = outlet.querySelectorAll('script')
    scripts.forEach((oldScript) => {
      const newScript = document.createElement('script')
      for (const attr of oldScript.attributes) {
        newScript.setAttribute(attr.name, attr.value)
      }
      newScript.textContent = oldScript.textContent
      oldScript.replaceWith(newScript)
    })
  }

  // Use View Transitions API if available
  if ('startViewTransition' in document) {
    await (document as unknown as { startViewTransition: (cb: () => void) => { finished: Promise<void> } })
      .startViewTransition(doSwap).finished
  }
  else {
    // CSS fallback: fade transition
    outlet.classList.add('stx-transition-leave')
    await new Promise(resolve => setTimeout(resolve, 150))
    doSwap()
    outlet.classList.remove('stx-transition-leave')
    outlet.classList.add('stx-transition-enter')
    await new Promise(resolve => setTimeout(resolve, 150))
    outlet.classList.remove('stx-transition-enter')
  }
}

/**
 * Strip document wrapper from a full HTML page to extract body content.
 * Used when server returns full page instead of fragment in shell mode.
 */
function stripDocumentWrapper(html: string): string {
  const bodyMatch = html.match(/<body[^>]*>([\s\S]*?)<\/body>/i)
  return bodyMatch ? bodyMatch[1] : html
}

/**
 * Initialize the router.
 */
export function createRouter(options: RouterOptions = {}): State<Route> {
  routerOptions = options
  const route = getCurrentRoute()

  // Listen for popstate (back/forward navigation)
  window.addEventListener('popstate', () => {
    const newRoute = parseRoute(window.location.href, options.base)
    route.set(newRoute)

    // Re-fetch and swap content
    navigate(window.location.href, { replace: true })
  })

  return route
}
