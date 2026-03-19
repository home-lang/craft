/**
 * Tooltip directive.
 * Adds a tooltip that appears on hover.
 *
 * Usage: tooltip(element, { text: 'Hello', position: 'top' })
 */
export function tooltip(
  el: HTMLElement,
  options: { text: string; position?: 'top' | 'bottom' | 'left' | 'right' },
): () => void {
  const pos = options.position ?? 'top'

  const tooltipEl = document.createElement('div')
  tooltipEl.textContent = options.text
  tooltipEl.style.cssText = `
    position: absolute;
    z-index: 9999;
    padding: 4px 8px;
    font-size: 12px;
    color: white;
    background: #1f2937;
    border-radius: 4px;
    white-space: nowrap;
    pointer-events: none;
    opacity: 0;
    transition: opacity 0.15s;
  `

  el.style.position = 'relative'

  const show = () => {
    el.appendChild(tooltipEl)

    const elRect = el.getBoundingClientRect()
    const ttRect = tooltipEl.getBoundingClientRect()

    switch (pos) {
      case 'top':
        tooltipEl.style.bottom = `${elRect.height + 6}px`
        tooltipEl.style.left = `${(elRect.width - ttRect.width) / 2}px`
        break
      case 'bottom':
        tooltipEl.style.top = `${elRect.height + 6}px`
        tooltipEl.style.left = `${(elRect.width - ttRect.width) / 2}px`
        break
      case 'left':
        tooltipEl.style.right = `${elRect.width + 6}px`
        tooltipEl.style.top = `${(elRect.height - ttRect.height) / 2}px`
        break
      case 'right':
        tooltipEl.style.left = `${elRect.width + 6}px`
        tooltipEl.style.top = `${(elRect.height - ttRect.height) / 2}px`
        break
    }

    requestAnimationFrame(() => {
      tooltipEl.style.opacity = '1'
    })
  }

  const hide = () => {
    tooltipEl.style.opacity = '0'
    setTimeout(() => tooltipEl.remove(), 150)
  }

  el.addEventListener('mouseenter', show)
  el.addEventListener('mouseleave', hide)

  return () => {
    el.removeEventListener('mouseenter', show)
    el.removeEventListener('mouseleave', hide)
    tooltipEl.remove()
  }
}
