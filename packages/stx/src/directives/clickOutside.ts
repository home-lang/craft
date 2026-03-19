/**
 * Click-outside directive.
 * Calls handler when a click occurs outside the element.
 *
 * Usage: clickOutside(element, () => closeMenu())
 */
export function clickOutside(
  el: HTMLElement,
  handler: () => void,
): () => void {
  const listener = (e: MouseEvent) => {
    if (!el.contains(e.target as Node)) {
      handler()
    }
  }

  document.addEventListener('click', listener, { capture: true })

  return () => document.removeEventListener('click', listener, { capture: true })
}
