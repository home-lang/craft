import { cx } from '../styles'
import { h } from '../component'
import { signal, effect } from '../runtime'
import type { ReadonlySignal, Signal } from '../runtime'

export interface ModalProps {
  open?: Signal<boolean>
  class?: string
  onClose?: () => void
  closeOnBackdrop?: boolean
}

export function Modal(
  props: ModalProps = {},
  ...children: Array<string | HTMLElement | ReadonlySignal<string>>
): HTMLElement {
  const isOpen = props.open ?? signal(false)

  const backdrop = h('div', {
    class: 'fixed inset-0 z-50 flex items-center justify-center bg-black/50 transition-opacity',
    onClick: (e: Event) => {
      if (props.closeOnBackdrop !== false && e.target === backdrop) {
        isOpen.value = false
        props.onClose?.()
      }
    },
  })

  const dialog = h(
    'div',
    {
      class: cx(
        'relative z-50 w-full max-w-lg rounded-lg bg-white p-6 shadow-xl',
        props.class,
      ),
      role: 'dialog',
    },
    ...children,
  )

  const closeBtn = h(
    'button',
    {
      class: 'absolute top-3 right-3 p-1 rounded-md text-gray-400 hover:text-gray-600 transition-colors',
      onClick: () => {
        isOpen.value = false
        props.onClose?.()
      },
    },
    '\u00d7',
  )

  dialog.appendChild(closeBtn)
  backdrop.appendChild(dialog)

  // Reactively show/hide
  effect(() => {
    backdrop.style.display = isOpen.value ? 'flex' : 'none'
  })

  return backdrop
}
