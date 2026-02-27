import { get } from 'svelte/store';
import { craft } from '../stores/craft';

export async function showToast(message: string, duration: 'short' | 'long' = 'short') {
  const _$craft = get(craft);
  if (!_$craft) return;
  await _$craft.showToast(message, duration);
}
