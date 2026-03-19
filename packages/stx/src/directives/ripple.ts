/**
 * Ripple effect directive.
 * Adds a material-design style ripple animation on click.
 *
 * Usage: ripple(element)
 */
export function ripple(
  el: HTMLElement,
  options?: { color?: string },
): () => void {
  const color = options?.color ?? 'rgba(255, 255, 255, 0.3)'

  el.style.position = 'relative'
  el.style.overflow = 'hidden'

  const handler = (e: MouseEvent) => {
    const rect = el.getBoundingClientRect()
    const size = Math.max(rect.width, rect.height)
    const x = e.clientX - rect.left - size / 2
    const y = e.clientY - rect.top - size / 2

    const rippleEl = document.createElement('span')
    rippleEl.style.cssText = `
      position: absolute;
      width: ${size}px;
      height: ${size}px;
      left: ${x}px;
      top: ${y}px;
      background: ${color};
      border-radius: 50%;
      transform: scale(0);
      animation: stx-ripple 0.6s ease-out;
      pointer-events: none;
    `

    el.appendChild(rippleEl)
    rippleEl.addEventListener('animationend', () => rippleEl.remove())
  }

  el.addEventListener('click', handler)

  // Inject keyframes if not already present
  if (!document.getElementById('stx-ripple-style')) {
    const styleEl = document.createElement('style')
    styleEl.id = 'stx-ripple-style'
    styleEl.textContent = `
      @keyframes stx-ripple {
        to { transform: scale(4); opacity: 0; }
      }
    `
    document.head.appendChild(styleEl)
  }

  return () => el.removeEventListener('click', handler)
}
