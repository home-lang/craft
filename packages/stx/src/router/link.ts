/**
 * <StxLink> Component
 *
 * Navigation link with active class management.
 * Intercepts clicks for SPA navigation.
 */

import { h } from '../component'
import { effect } from '../runtime'
import { navigate, getCurrentRoute } from './router'

export interface StxLinkProps {
  to: string
  class?: string
  activeClass?: string
  exactActiveClass?: string
  replace?: boolean
}

/**
 * Create a navigation link that uses the stx router.
 *
 * @example
 * StxLink({ to: '/about', activeClass: 'text-blue-500' }, 'About')
 */
export function StxLink(
  props: StxLinkProps,
  ...children: Array<string | HTMLElement>
): HTMLElement {
  const activeClass = props.activeClass ?? 'stx-link-active'
  const exactActiveClass = props.exactActiveClass ?? 'stx-link-exact-active'

  const link = h('a', {
    href: props.to,
    class: props.class ?? '',
    onClick: (e: Event) => {
      e.preventDefault()
      navigate(props.to, { replace: props.replace })
    },
  }, ...children)

  // Reactive active class management
  const route = getCurrentRoute()
  effect(() => {
    const currentPath = route().path
    const isExact = currentPath === props.to
    const isActive = currentPath.startsWith(props.to) && props.to !== '/'
      || isExact

    link.classList.toggle(activeClass, isActive)
    link.classList.toggle(exactActiveClass, isExact)
  })

  return link
}
