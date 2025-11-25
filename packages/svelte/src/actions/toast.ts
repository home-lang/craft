import { get } from 'svelte/store';
import { craft } from '../stores/craft';

export async function showToast(message: string, duration: 'short' | 'long' = 'short') {
  const $craft = get(craft);
  if (!$craft) return;
  await $craft.showToast(message, duration);
}
