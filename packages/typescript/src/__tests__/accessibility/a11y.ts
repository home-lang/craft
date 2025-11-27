/**
 * Craft Accessibility Testing Suite
 * Automated WCAG 2.1 compliance checking
 */

export type WCAGLevel = 'A' | 'AA' | 'AAA'

export interface A11yIssue {
  id: string
  type: 'error' | 'warning' | 'notice'
  message: string
  element?: string
  selector?: string
  wcagCriteria?: string
  level?: WCAGLevel
  fix?: string
}

export interface A11yReport {
  url: string
  timestamp: Date
  issues: A11yIssue[]
  summary: {
    errors: number
    warnings: number
    notices: number
    passed: number
  }
  level: WCAGLevel
}

/**
 * WCAG 2.1 Success Criteria
 */
export const WCAG_CRITERIA = {
  // Level A
  '1.1.1': { level: 'A' as const, name: 'Non-text Content' },
  '1.2.1': { level: 'A' as const, name: 'Audio-only and Video-only' },
  '1.3.1': { level: 'A' as const, name: 'Info and Relationships' },
  '1.3.2': { level: 'A' as const, name: 'Meaningful Sequence' },
  '1.3.3': { level: 'A' as const, name: 'Sensory Characteristics' },
  '1.4.1': { level: 'A' as const, name: 'Use of Color' },
  '1.4.2': { level: 'A' as const, name: 'Audio Control' },
  '2.1.1': { level: 'A' as const, name: 'Keyboard' },
  '2.1.2': { level: 'A' as const, name: 'No Keyboard Trap' },
  '2.1.4': { level: 'A' as const, name: 'Character Key Shortcuts' },
  '2.2.1': { level: 'A' as const, name: 'Timing Adjustable' },
  '2.2.2': { level: 'A' as const, name: 'Pause, Stop, Hide' },
  '2.3.1': { level: 'A' as const, name: 'Three Flashes or Below' },
  '2.4.1': { level: 'A' as const, name: 'Bypass Blocks' },
  '2.4.2': { level: 'A' as const, name: 'Page Titled' },
  '2.4.3': { level: 'A' as const, name: 'Focus Order' },
  '2.4.4': { level: 'A' as const, name: 'Link Purpose' },
  '2.5.1': { level: 'A' as const, name: 'Pointer Gestures' },
  '2.5.2': { level: 'A' as const, name: 'Pointer Cancellation' },
  '2.5.3': { level: 'A' as const, name: 'Label in Name' },
  '2.5.4': { level: 'A' as const, name: 'Motion Actuation' },
  '3.1.1': { level: 'A' as const, name: 'Language of Page' },
  '3.2.1': { level: 'A' as const, name: 'On Focus' },
  '3.2.2': { level: 'A' as const, name: 'On Input' },
  '3.3.1': { level: 'A' as const, name: 'Error Identification' },
  '3.3.2': { level: 'A' as const, name: 'Labels or Instructions' },
  '4.1.1': { level: 'A' as const, name: 'Parsing' },
  '4.1.2': { level: 'A' as const, name: 'Name, Role, Value' },

  // Level AA
  '1.3.4': { level: 'AA' as const, name: 'Orientation' },
  '1.3.5': { level: 'AA' as const, name: 'Identify Input Purpose' },
  '1.4.3': { level: 'AA' as const, name: 'Contrast (Minimum)' },
  '1.4.4': { level: 'AA' as const, name: 'Resize Text' },
  '1.4.5': { level: 'AA' as const, name: 'Images of Text' },
  '1.4.10': { level: 'AA' as const, name: 'Reflow' },
  '1.4.11': { level: 'AA' as const, name: 'Non-text Contrast' },
  '1.4.12': { level: 'AA' as const, name: 'Text Spacing' },
  '1.4.13': { level: 'AA' as const, name: 'Content on Hover/Focus' },
  '2.4.5': { level: 'AA' as const, name: 'Multiple Ways' },
  '2.4.6': { level: 'AA' as const, name: 'Headings and Labels' },
  '2.4.7': { level: 'AA' as const, name: 'Focus Visible' },
  '3.1.2': { level: 'AA' as const, name: 'Language of Parts' },
  '3.2.3': { level: 'AA' as const, name: 'Consistent Navigation' },
  '3.2.4': { level: 'AA' as const, name: 'Consistent Identification' },
  '3.3.3': { level: 'AA' as const, name: 'Error Suggestion' },
  '3.3.4': { level: 'AA' as const, name: 'Error Prevention' },
  '4.1.3': { level: 'AA' as const, name: 'Status Messages' },

  // Level AAA
  '1.2.6': { level: 'AAA' as const, name: 'Sign Language' },
  '1.4.6': { level: 'AAA' as const, name: 'Contrast (Enhanced)' },
  '1.4.8': { level: 'AAA' as const, name: 'Visual Presentation' },
  '1.4.9': { level: 'AAA' as const, name: 'Images of Text (No Exception)' },
  '2.1.3': { level: 'AAA' as const, name: 'Keyboard (No Exception)' },
  '2.2.3': { level: 'AAA' as const, name: 'No Timing' },
  '2.2.4': { level: 'AAA' as const, name: 'Interruptions' },
  '2.2.5': { level: 'AAA' as const, name: 'Re-authenticating' },
  '2.3.2': { level: 'AAA' as const, name: 'Three Flashes' },
  '2.4.8': { level: 'AAA' as const, name: 'Location' },
  '2.4.9': { level: 'AAA' as const, name: 'Link Purpose (Link Only)' },
  '2.4.10': { level: 'AAA' as const, name: 'Section Headings' },
}

/**
 * Accessibility checker
 */
export class A11yChecker {
  private issues: A11yIssue[] = []
  private level: WCAGLevel

  constructor(level: WCAGLevel = 'AA') {
    this.level = level
  }

  /**
   * Run all accessibility checks
   */
  async check(document: Document): Promise<A11yReport> {
    this.issues = []

    // Run checks
    this.checkImages(document)
    this.checkHeadings(document)
    this.checkLinks(document)
    this.checkForms(document)
    this.checkContrast(document)
    this.checkKeyboardAccess(document)
    this.checkAriaAttributes(document)
    this.checkLanguage(document)
    this.checkPageTitle(document)
    this.checkFocusIndicators(document)
    this.checkLandmarks(document)
    this.checkTables(document)

    // Calculate summary
    const errors = this.issues.filter(i => i.type === 'error').length
    const warnings = this.issues.filter(i => i.type === 'warning').length
    const notices = this.issues.filter(i => i.type === 'notice').length

    return {
      url: document.location?.href || 'unknown',
      timestamp: new Date(),
      issues: this.issues,
      summary: {
        errors,
        warnings,
        notices,
        passed: Object.keys(WCAG_CRITERIA).length - errors
      },
      level: this.level
    }
  }

  /**
   * Check images for alt text
   */
  private checkImages(document: Document): void {
    const images = document.querySelectorAll('img')

    images.forEach((img, index) => {
      if (!img.hasAttribute('alt')) {
        this.addIssue({
          id: `img-alt-${index}`,
          type: 'error',
          message: 'Image is missing alt attribute',
          element: img.outerHTML.slice(0, 100),
          selector: this.getSelector(img),
          wcagCriteria: '1.1.1',
          level: 'A',
          fix: 'Add alt="" for decorative images, or descriptive alt text for informative images'
        })
      } else if (img.alt === '' && !img.hasAttribute('role')) {
        this.addIssue({
          id: `img-decorative-${index}`,
          type: 'notice',
          message: 'Image has empty alt - ensure it is decorative',
          element: img.outerHTML.slice(0, 100),
          selector: this.getSelector(img),
          wcagCriteria: '1.1.1',
          level: 'A'
        })
      }
    })
  }

  /**
   * Check heading structure
   */
  private checkHeadings(document: Document): void {
    const headings = document.querySelectorAll('h1, h2, h3, h4, h5, h6')
    let lastLevel = 0

    headings.forEach((heading, index) => {
      const level = parseInt(heading.tagName[1])

      // Check for skipped levels
      if (level > lastLevel + 1 && lastLevel !== 0) {
        this.addIssue({
          id: `heading-skip-${index}`,
          type: 'warning',
          message: `Heading level skipped from H${lastLevel} to H${level}`,
          element: heading.outerHTML.slice(0, 100),
          selector: this.getSelector(heading),
          wcagCriteria: '1.3.1',
          level: 'A',
          fix: 'Ensure heading levels are sequential (H1 → H2 → H3)'
        })
      }

      // Check for empty headings
      if (!heading.textContent?.trim()) {
        this.addIssue({
          id: `heading-empty-${index}`,
          type: 'error',
          message: 'Heading is empty',
          element: heading.outerHTML,
          selector: this.getSelector(heading),
          wcagCriteria: '2.4.6',
          level: 'AA',
          fix: 'Add text content to the heading'
        })
      }

      lastLevel = level
    })

    // Check for multiple H1s
    const h1s = document.querySelectorAll('h1')
    if (h1s.length > 1) {
      this.addIssue({
        id: 'multiple-h1',
        type: 'warning',
        message: `Page has ${h1s.length} H1 elements - consider using only one`,
        wcagCriteria: '1.3.1',
        level: 'A'
      })
    }

    if (h1s.length === 0) {
      this.addIssue({
        id: 'no-h1',
        type: 'warning',
        message: 'Page has no H1 element',
        wcagCriteria: '1.3.1',
        level: 'A',
        fix: 'Add an H1 element to define the main heading'
      })
    }
  }

  /**
   * Check links
   */
  private checkLinks(document: Document): void {
    const links = document.querySelectorAll('a')

    links.forEach((link, index) => {
      const text = link.textContent?.trim()
      const ariaLabel = link.getAttribute('aria-label')
      const title = link.getAttribute('title')

      // Check for accessible name
      if (!text && !ariaLabel && !title) {
        this.addIssue({
          id: `link-name-${index}`,
          type: 'error',
          message: 'Link has no accessible name',
          element: link.outerHTML.slice(0, 100),
          selector: this.getSelector(link),
          wcagCriteria: '2.4.4',
          level: 'A',
          fix: 'Add text content, aria-label, or title to the link'
        })
      }

      // Check for generic link text
      const genericTexts = ['click here', 'read more', 'learn more', 'here', 'more']
      if (text && genericTexts.includes(text.toLowerCase())) {
        this.addIssue({
          id: `link-generic-${index}`,
          type: 'warning',
          message: `Link text "${text}" is not descriptive`,
          element: link.outerHTML.slice(0, 100),
          selector: this.getSelector(link),
          wcagCriteria: '2.4.4',
          level: 'A',
          fix: 'Use descriptive link text that explains the destination'
        })
      }

      // Check for missing href
      if (!link.hasAttribute('href')) {
        this.addIssue({
          id: `link-href-${index}`,
          type: 'warning',
          message: 'Link is missing href attribute',
          element: link.outerHTML.slice(0, 100),
          selector: this.getSelector(link),
          wcagCriteria: '4.1.2',
          level: 'A',
          fix: 'Add href attribute or use a button element'
        })
      }
    })
  }

  /**
   * Check form accessibility
   */
  private checkForms(document: Document): void {
    const inputs = document.querySelectorAll('input, select, textarea')

    inputs.forEach((input, index) => {
      const type = input.getAttribute('type')
      const id = input.id
      const ariaLabel = input.getAttribute('aria-label')
      const ariaLabelledBy = input.getAttribute('aria-labelledby')

      // Skip hidden and submit inputs
      if (type === 'hidden' || type === 'submit' || type === 'button') return

      // Check for label
      const label = id ? document.querySelector(`label[for="${id}"]`) : null

      if (!label && !ariaLabel && !ariaLabelledBy) {
        this.addIssue({
          id: `input-label-${index}`,
          type: 'error',
          message: 'Form input has no associated label',
          element: (input as HTMLElement).outerHTML.slice(0, 100),
          selector: this.getSelector(input as Element),
          wcagCriteria: '3.3.2',
          level: 'A',
          fix: 'Add a label element with for="input-id" or use aria-label'
        })
      }

      // Check for autocomplete on appropriate inputs
      const autocompleteTypes = ['name', 'email', 'tel', 'address', 'password']
      if (type && autocompleteTypes.some(t => type.includes(t))) {
        if (!input.hasAttribute('autocomplete')) {
          this.addIssue({
            id: `input-autocomplete-${index}`,
            type: 'notice',
            message: 'Input may benefit from autocomplete attribute',
            element: (input as HTMLElement).outerHTML.slice(0, 100),
            selector: this.getSelector(input as Element),
            wcagCriteria: '1.3.5',
            level: 'AA'
          })
        }
      }
    })
  }

  /**
   * Check color contrast
   */
  private checkContrast(document: Document): void {
    const elements = document.querySelectorAll('*')

    elements.forEach((el, index) => {
      const style = window.getComputedStyle(el)
      const color = style.color
      const bgColor = style.backgroundColor

      if (color && bgColor && color !== 'rgba(0, 0, 0, 0)' && bgColor !== 'rgba(0, 0, 0, 0)') {
        const contrast = this.calculateContrast(color, bgColor)

        const fontSize = parseFloat(style.fontSize)
        const fontWeight = style.fontWeight
        const isLargeText = fontSize >= 18 || (fontSize >= 14 && parseInt(fontWeight) >= 700)

        const minContrast = isLargeText ? 3 : 4.5
        const enhancedContrast = isLargeText ? 4.5 : 7

        if (contrast < minContrast) {
          this.addIssue({
            id: `contrast-${index}`,
            type: 'error',
            message: `Insufficient color contrast: ${contrast.toFixed(2)}:1 (minimum ${minContrast}:1)`,
            element: (el as HTMLElement).outerHTML.slice(0, 100),
            selector: this.getSelector(el),
            wcagCriteria: '1.4.3',
            level: 'AA',
            fix: 'Increase the contrast between text and background colors'
          })
        } else if (this.level === 'AAA' && contrast < enhancedContrast) {
          this.addIssue({
            id: `contrast-enhanced-${index}`,
            type: 'warning',
            message: `Color contrast ${contrast.toFixed(2)}:1 does not meet AAA (${enhancedContrast}:1)`,
            element: (el as HTMLElement).outerHTML.slice(0, 100),
            selector: this.getSelector(el),
            wcagCriteria: '1.4.6',
            level: 'AAA'
          })
        }
      }
    })
  }

  /**
   * Check keyboard accessibility
   */
  private checkKeyboardAccess(document: Document): void {
    const interactiveElements = document.querySelectorAll(
      'a, button, input, select, textarea, [tabindex], [onclick]'
    )

    interactiveElements.forEach((el, index) => {
      const tabindex = el.getAttribute('tabindex')

      // Check for positive tabindex
      if (tabindex && parseInt(tabindex) > 0) {
        this.addIssue({
          id: `tabindex-positive-${index}`,
          type: 'warning',
          message: `Element has positive tabindex="${tabindex}" - avoid using positive tabindex`,
          element: (el as HTMLElement).outerHTML.slice(0, 100),
          selector: this.getSelector(el),
          wcagCriteria: '2.4.3',
          level: 'A',
          fix: 'Use tabindex="0" or remove tabindex and rely on DOM order'
        })
      }

      // Check for onclick without keyboard handler
      if (el.hasAttribute('onclick') && !el.hasAttribute('onkeypress') && !el.hasAttribute('onkeydown')) {
        const role = el.getAttribute('role')
        if (el.tagName !== 'A' && el.tagName !== 'BUTTON' && role !== 'button' && role !== 'link') {
          this.addIssue({
            id: `keyboard-${index}`,
            type: 'error',
            message: 'Element has onclick but no keyboard handler',
            element: (el as HTMLElement).outerHTML.slice(0, 100),
            selector: this.getSelector(el),
            wcagCriteria: '2.1.1',
            level: 'A',
            fix: 'Add keyboard event handlers or use native interactive elements'
          })
        }
      }
    })
  }

  /**
   * Check ARIA attributes
   */
  private checkAriaAttributes(document: Document): void {
    const ariaElements = document.querySelectorAll('[role], [aria-label], [aria-labelledby], [aria-describedby]')

    ariaElements.forEach((el, index) => {
      const role = el.getAttribute('role')
      const ariaLabelledBy = el.getAttribute('aria-labelledby')
      const ariaDescribedBy = el.getAttribute('aria-describedby')

      // Check if referenced IDs exist
      if (ariaLabelledBy) {
        const ids = ariaLabelledBy.split(' ')
        ids.forEach(id => {
          if (!document.getElementById(id)) {
            this.addIssue({
              id: `aria-labelledby-${index}`,
              type: 'error',
              message: `aria-labelledby references non-existent ID: ${id}`,
              element: (el as HTMLElement).outerHTML.slice(0, 100),
              selector: this.getSelector(el),
              wcagCriteria: '4.1.2',
              level: 'A'
            })
          }
        })
      }

      if (ariaDescribedBy) {
        const ids = ariaDescribedBy.split(' ')
        ids.forEach(id => {
          if (!document.getElementById(id)) {
            this.addIssue({
              id: `aria-describedby-${index}`,
              type: 'error',
              message: `aria-describedby references non-existent ID: ${id}`,
              element: (el as HTMLElement).outerHTML.slice(0, 100),
              selector: this.getSelector(el),
              wcagCriteria: '4.1.2',
              level: 'A'
            })
          }
        })
      }

      // Check for valid roles
      const validRoles = [
        'alert', 'alertdialog', 'application', 'article', 'banner', 'button',
        'cell', 'checkbox', 'columnheader', 'combobox', 'complementary', 'contentinfo',
        'definition', 'dialog', 'directory', 'document', 'feed', 'figure', 'form',
        'grid', 'gridcell', 'group', 'heading', 'img', 'link', 'list', 'listbox',
        'listitem', 'log', 'main', 'marquee', 'math', 'menu', 'menubar', 'menuitem',
        'menuitemcheckbox', 'menuitemradio', 'navigation', 'none', 'note', 'option',
        'presentation', 'progressbar', 'radio', 'radiogroup', 'region', 'row',
        'rowgroup', 'rowheader', 'scrollbar', 'search', 'searchbox', 'separator',
        'slider', 'spinbutton', 'status', 'switch', 'tab', 'table', 'tablist',
        'tabpanel', 'term', 'textbox', 'timer', 'toolbar', 'tooltip', 'tree',
        'treegrid', 'treeitem'
      ]

      if (role && !validRoles.includes(role)) {
        this.addIssue({
          id: `aria-role-${index}`,
          type: 'error',
          message: `Invalid ARIA role: ${role}`,
          element: (el as HTMLElement).outerHTML.slice(0, 100),
          selector: this.getSelector(el),
          wcagCriteria: '4.1.2',
          level: 'A'
        })
      }
    })
  }

  /**
   * Check page language
   */
  private checkLanguage(document: Document): void {
    const html = document.documentElement
    const lang = html.getAttribute('lang')

    if (!lang) {
      this.addIssue({
        id: 'lang-missing',
        type: 'error',
        message: 'HTML element is missing lang attribute',
        wcagCriteria: '3.1.1',
        level: 'A',
        fix: 'Add lang attribute to html element, e.g., lang="en"'
      })
    } else if (!/^[a-z]{2}(-[A-Z]{2})?$/.test(lang)) {
      this.addIssue({
        id: 'lang-invalid',
        type: 'warning',
        message: `Language code "${lang}" may not be valid`,
        wcagCriteria: '3.1.1',
        level: 'A',
        fix: 'Use valid BCP 47 language tags (e.g., "en", "en-US")'
      })
    }
  }

  /**
   * Check page title
   */
  private checkPageTitle(document: Document): void {
    const title = document.title

    if (!title || !title.trim()) {
      this.addIssue({
        id: 'title-missing',
        type: 'error',
        message: 'Page is missing title',
        wcagCriteria: '2.4.2',
        level: 'A',
        fix: 'Add a descriptive title element to the head'
      })
    }
  }

  /**
   * Check focus indicators
   */
  private checkFocusIndicators(document: Document): void {
    const focusableElements = document.querySelectorAll(
      'a, button, input, select, textarea, [tabindex="0"]'
    )

    focusableElements.forEach((el, index) => {
      const style = window.getComputedStyle(el)
      const focusStyle = window.getComputedStyle(el, ':focus')

      if (style.outline === 'none' || style.outline === '0') {
        const hasFocusStyles = focusStyle.boxShadow !== 'none' ||
          focusStyle.border !== style.border ||
          focusStyle.backgroundColor !== style.backgroundColor

        if (!hasFocusStyles) {
          this.addIssue({
            id: `focus-indicator-${index}`,
            type: 'warning',
            message: 'Element may not have visible focus indicator',
            element: (el as HTMLElement).outerHTML.slice(0, 100),
            selector: this.getSelector(el),
            wcagCriteria: '2.4.7',
            level: 'AA',
            fix: 'Ensure focus is visible with outline, box-shadow, or other visual indicator'
          })
        }
      }
    })
  }

  /**
   * Check landmark regions
   */
  private checkLandmarks(document: Document): void {
    const main = document.querySelector('main, [role="main"]')
    const nav = document.querySelector('nav, [role="navigation"]')

    if (!main) {
      this.addIssue({
        id: 'landmark-main',
        type: 'notice',
        message: 'Page has no main landmark',
        wcagCriteria: '2.4.1',
        level: 'A',
        fix: 'Wrap main content in <main> element or use role="main"'
      })
    }

    // Check for multiple nav without labels
    const navs = document.querySelectorAll('nav, [role="navigation"]')
    if (navs.length > 1) {
      navs.forEach((nav, index) => {
        const label = nav.getAttribute('aria-label') || nav.getAttribute('aria-labelledby')
        if (!label) {
          this.addIssue({
            id: `landmark-nav-${index}`,
            type: 'warning',
            message: 'Multiple navigation landmarks should have unique labels',
            element: (nav as HTMLElement).outerHTML.slice(0, 100),
            selector: this.getSelector(nav),
            wcagCriteria: '2.4.1',
            level: 'A',
            fix: 'Add aria-label to distinguish navigation regions'
          })
        }
      })
    }
  }

  /**
   * Check tables
   */
  private checkTables(document: Document): void {
    const tables = document.querySelectorAll('table')

    tables.forEach((table, index) => {
      const caption = table.querySelector('caption')
      const headers = table.querySelectorAll('th')

      if (!caption && !table.getAttribute('aria-label') && !table.getAttribute('aria-labelledby')) {
        this.addIssue({
          id: `table-caption-${index}`,
          type: 'notice',
          message: 'Table should have a caption or aria-label',
          element: table.outerHTML.slice(0, 100),
          selector: this.getSelector(table),
          wcagCriteria: '1.3.1',
          level: 'A',
          fix: 'Add <caption> element or aria-label to describe the table'
        })
      }

      if (headers.length === 0) {
        this.addIssue({
          id: `table-headers-${index}`,
          type: 'warning',
          message: 'Table has no header cells (<th>)',
          element: table.outerHTML.slice(0, 100),
          selector: this.getSelector(table),
          wcagCriteria: '1.3.1',
          level: 'A',
          fix: 'Use <th> elements for column/row headers'
        })
      }
    })
  }

  /**
   * Get a unique selector for an element
   */
  private getSelector(el: Element): string {
    if (el.id) return `#${el.id}`

    let selector = el.tagName.toLowerCase()

    if (el.className) {
      const classes = Array.from(el.classList).slice(0, 2).join('.')
      selector += `.${classes}`
    }

    return selector
  }

  /**
   * Calculate contrast ratio between two colors
   */
  private calculateContrast(color1: string, color2: string): number {
    const lum1 = this.getLuminance(this.parseColor(color1))
    const lum2 = this.getLuminance(this.parseColor(color2))

    const lighter = Math.max(lum1, lum2)
    const darker = Math.min(lum1, lum2)

    return (lighter + 0.05) / (darker + 0.05)
  }

  /**
   * Parse a CSS color string to RGB values
   */
  private parseColor(color: string): [number, number, number] {
    // Handle rgb/rgba format
    const rgbMatch = color.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)/)
    if (rgbMatch) {
      return [parseInt(rgbMatch[1]), parseInt(rgbMatch[2]), parseInt(rgbMatch[3])]
    }

    // Handle hex format
    const hexMatch = color.match(/^#([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})/i)
    if (hexMatch) {
      return [parseInt(hexMatch[1], 16), parseInt(hexMatch[2], 16), parseInt(hexMatch[3], 16)]
    }

    return [0, 0, 0]
  }

  /**
   * Calculate relative luminance
   */
  private getLuminance([r, g, b]: [number, number, number]): number {
    const [rs, gs, bs] = [r, g, b].map(c => {
      c = c / 255
      return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4)
    })
    return 0.2126 * rs + 0.7152 * gs + 0.0722 * bs
  }

  /**
   * Add an issue to the report
   */
  private addIssue(issue: A11yIssue): void {
    // Filter by level
    if (issue.level) {
      const levelOrder = { A: 1, AA: 2, AAA: 3 }
      if (levelOrder[issue.level] > levelOrder[this.level]) {
        return // Skip issues above our target level
      }
    }

    this.issues.push(issue)
  }
}

/**
 * Run accessibility check on current document
 */
export async function checkAccessibility(level: WCAGLevel = 'AA'): Promise<A11yReport> {
  const checker = new A11yChecker(level)
  return checker.check(document)
}

/**
 * Format report as text
 */
export function formatReport(report: A11yReport): string {
  let output = `
Accessibility Report
====================
URL: ${report.url}
Level: WCAG 2.1 ${report.level}
Date: ${report.timestamp.toISOString()}

Summary
-------
Errors: ${report.summary.errors}
Warnings: ${report.summary.warnings}
Notices: ${report.summary.notices}
`

  if (report.issues.length === 0) {
    output += '\nNo issues found!'
  } else {
    output += '\nIssues\n------\n'

    for (const issue of report.issues) {
      output += `\n[${issue.type.toUpperCase()}] ${issue.message}\n`
      if (issue.wcagCriteria) output += `  WCAG: ${issue.wcagCriteria} (Level ${issue.level})\n`
      if (issue.selector) output += `  Selector: ${issue.selector}\n`
      if (issue.fix) output += `  Fix: ${issue.fix}\n`
    }
  }

  return output
}
