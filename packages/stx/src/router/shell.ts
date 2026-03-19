/**
 * App Shell (v2 Phase 3c)
 *
 * Supports app.stx as a layout shell with <slot /> for page content.
 * - Direct requests get full shell + page pre-rendered
 * - SPA navigation gets page fragments only
 * - Shell scripts, styles, and router persist across navigations
 */

/**
 * Load and initialize the app shell.
 * Called once on initial page load.
 *
 * @param shellHtml - The rendered app.stx shell HTML
 * @param outlet - CSS selector for the slot/content area within the shell
 */
export function loadShell(shellHtml: string, outlet: string = '[data-stx-outlet]'): Element | null {
  const app = document.querySelector('#app')
  if (!app) return null

  app.innerHTML = shellHtml

  const outletEl = app.querySelector(outlet)
  if (!outletEl) {
    console.warn('[stx-shell] No outlet found with selector:', outlet)
  }

  return outletEl
}

/**
 * Inject page content into the shell outlet.
 * Used for both initial render and SPA navigation.
 */
export function injectPage(outlet: Element, pageHtml: string): void {
  // Parse fragment
  const temp = document.createElement('div')
  temp.innerHTML = pageHtml

  // Extract page styles
  const styles = temp.querySelectorAll('style, link[rel="stylesheet"]')
  styles.forEach((style) => {
    const id = style.getAttribute('data-stx-scope') || style.textContent?.slice(0, 50)
    // Avoid duplicate styles
    if (id && document.querySelector(`[data-stx-scope="${id}"]`)) {
      style.remove()
      return
    }
    document.head.appendChild(style.cloneNode(true))
    style.remove()
  })

  // Swap content
  outlet.innerHTML = temp.innerHTML

  // Re-execute scripts
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
