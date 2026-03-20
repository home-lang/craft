import { effect } from '../runtime'

interface HeadConfig {
  title?: string
  meta?: Array<Record<string, string>>
  link?: Array<Record<string, string>>
  script?: Array<Record<string, string> & { textContent?: string }>
  htmlAttrs?: Record<string, string>
  bodyAttrs?: Record<string, string>
}

interface SeoMetaConfig {
  title?: string
  description?: string
  ogTitle?: string
  ogDescription?: string
  ogImage?: string
  ogUrl?: string
  twitterCard?: 'summary' | 'summary_large_image'
  twitterTitle?: string
  twitterDescription?: string
  twitterImage?: string
}

/**
 * Manage document head tags reactively.
 *
 * @example
 * useHead({
 *   title: 'My Page',
 *   meta: [
 *     { name: 'description', content: 'Page description' }
 *   ]
 * })
 */
export function useHead(config: HeadConfig | (() => HeadConfig)): void {
  const managed: Element[] = []

  const apply = () => {
    // Remove previously managed elements
    for (const el of managed) el.remove()
    managed.length = 0

    const resolved = typeof config === 'function' ? config() : config

    if (typeof document === 'undefined') return

    // Title
    if (resolved.title) {
      document.title = resolved.title
    }

    // Meta tags
    if (resolved.meta) {
      for (const attrs of resolved.meta) {
        const el = document.createElement('meta')
        for (const [k, v] of Object.entries(attrs)) {
          el.setAttribute(k, v)
        }
        document.head.appendChild(el)
        managed.push(el)
      }
    }

    // Link tags
    if (resolved.link) {
      for (const attrs of resolved.link) {
        const el = document.createElement('link')
        for (const [k, v] of Object.entries(attrs)) {
          el.setAttribute(k, v)
        }
        document.head.appendChild(el)
        managed.push(el)
      }
    }

    // HTML attributes
    if (resolved.htmlAttrs) {
      for (const [k, v] of Object.entries(resolved.htmlAttrs)) {
        document.documentElement.setAttribute(k, v)
      }
    }

    // Body attributes
    if (resolved.bodyAttrs) {
      for (const [k, v] of Object.entries(resolved.bodyAttrs)) {
        document.body.setAttribute(k, v)
      }
    }
  }

  if (typeof config === 'function') {
    effect(apply)
  }
  else {
    apply()
  }
}

/**
 * Simplified SEO meta tags. Auto-generates OG and Twitter tags.
 *
 * @example
 * useSeoMeta({
 *   title: 'My App',
 *   description: 'An awesome app',
 *   ogImage: '/og-image.png'
 * })
 */
export function useSeoMeta(config: SeoMetaConfig): void {
  const meta: Array<Record<string, string>> = []

  if (config.description) {
    meta.push({ name: 'description', content: config.description })
  }

  // Open Graph
  const ogTitle = config.ogTitle ?? config.title
  const ogDesc = config.ogDescription ?? config.description
  if (ogTitle) meta.push({ property: 'og:title', content: ogTitle })
  if (ogDesc) meta.push({ property: 'og:description', content: ogDesc })
  if (config.ogImage) meta.push({ property: 'og:image', content: config.ogImage })
  if (config.ogUrl) meta.push({ property: 'og:url', content: config.ogUrl })

  // Twitter
  const twCard = config.twitterCard ?? 'summary_large_image'
  meta.push({ name: 'twitter:card', content: twCard })
  const twTitle = config.twitterTitle ?? config.title
  const twDesc = config.twitterDescription ?? config.description
  if (twTitle) meta.push({ name: 'twitter:title', content: twTitle })
  if (twDesc) meta.push({ name: 'twitter:description', content: twDesc })
  if (config.twitterImage ?? config.ogImage) {
    meta.push({ name: 'twitter:image', content: config.twitterImage ?? config.ogImage! })
  }

  useHead({ title: config.title, meta })
}
