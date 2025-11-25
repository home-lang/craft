import { get } from 'svelte/store';
import { craft } from '../stores/craft';

export function haptic(node: HTMLElement, type: string = 'selection') {
  const handleClick = async () => {
    const $craft = get(craft);
    if (!$craft) return;
    await $craft.haptic(type);
  };

  node.addEventListener('click', handleClick);

  return {
    destroy() {
      node.removeEventListener('click', handleClick);
    },
  };
}
