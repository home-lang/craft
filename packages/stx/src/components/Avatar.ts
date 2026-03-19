import { variants, cx } from '../styles'
import { h } from '../component'

export interface AvatarProps {
  src?: string
  alt?: string
  initials?: string
  size?: 'sm' | 'md' | 'lg' | 'xl'
  class?: string
}

export const avatarVariants = variants({
  base: 'inline-flex items-center justify-center rounded-full bg-gray-200 text-gray-600 font-medium overflow-hidden flex-shrink-0',
  variants: {
    size: {
      sm: 'h-8 w-8 text-xs',
      md: 'h-10 w-10 text-sm',
      lg: 'h-12 w-12 text-base',
      xl: 'h-16 w-16 text-lg',
    },
  },
  defaultVariants: {
    size: 'md',
  },
})

export function Avatar(props: AvatarProps = {}): HTMLElement {
  const className = cx(
    avatarVariants({ size: props.size }),
    props.class,
  )

  if (props.src) {
    const img = h('img', {
      src: props.src,
      alt: props.alt ?? '',
      class: 'h-full w-full object-cover',
    })
    return h('span', { class: className }, img)
  }

  const text = props.initials ?? '?'
  return h('span', { class: className }, text)
}
