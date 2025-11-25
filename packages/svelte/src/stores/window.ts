import { writable, get } from 'svelte/store';
import { craft } from './craft';

export const isFullscreen = writable(false);
export const isMaximized = writable(false);
export const isMinimized = writable(false);

export const windowActions = {
  async setTitle(title: string) {
    const $craft = get(craft);
    if (!$craft) return;
    await $craft.invoke('window.setTitle', { title });
  },

  async setSize(width: number, height: number) {
    const $craft = get(craft);
    if (!$craft) return;
    await $craft.invoke('window.setSize', { width, height });
  },

  async maximize() {
    const $craft = get(craft);
    if (!$craft) return;
    await $craft.invoke('window.maximize');
    isMaximized.set(true);
  },

  async minimize() {
    const $craft = get(craft);
    if (!$craft) return;
    await $craft.invoke('window.minimize');
    isMinimized.set(true);
  },

  async toggleFullscreen() {
    const $craft = get(craft);
    if (!$craft) return;
    await $craft.invoke('window.toggleFullscreen');
    isFullscreen.update((v) => !v);
  },

  async close() {
    const $craft = get(craft);
    if (!$craft) return;
    await $craft.invoke('window.close');
  },
};
