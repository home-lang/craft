import { writable, get } from 'svelte/store';
import { craft } from './craft';

export const isFullscreen = writable(false);
export const isMaximized = writable(false);
export const isMinimized = writable(false);

export const windowActions = {
  async setTitle(title: string) {
    const _$craft = get(craft);
    if (!_$craft) return;
    await _$craft.invoke('window.setTitle', { title });
  },

  async setSize(width: number, height: number) {
    const _$craft = get(craft);
    if (!_$craft) return;
    await _$craft.invoke('window.setSize', { width, height });
  },

  async maximize() {
    const _$craft = get(craft);
    if (!_$craft) return;
    await _$craft.invoke('window.maximize');
    isMaximized.set(true);
  },

  async minimize() {
    const _$craft = get(craft);
    if (!_$craft) return;
    await _$craft.invoke('window.minimize');
    isMinimized.set(true);
  },

  async toggleFullscreen() {
    const _$craft = get(craft);
    if (!_$craft) return;
    await _$craft.invoke('window.toggleFullscreen');
    isFullscreen.update((v) => !v);
  },

  async close() {
    const _$craft = get(craft);
    if (!_$craft) return;
    await _$craft.invoke('window.close');
  },
};
