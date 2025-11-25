import { writable, get } from 'svelte/store';
import { craft } from './craft';

export const trayVisible = writable(false);

export const trayActions = {
  async create(icon?: string, tooltip?: string) {
    const $craft = get(craft);
    if (!$craft) return;
    await $craft.invoke('tray.create', { icon, tooltip });
    trayVisible.set(true);
  },

  async destroy() {
    const $craft = get(craft);
    if (!$craft) return;
    await $craft.invoke('tray.destroy');
    trayVisible.set(false);
  },

  async setIcon(icon: string) {
    const $craft = get(craft);
    if (!$craft) return;
    await $craft.invoke('tray.setIcon', { icon });
  },
};
