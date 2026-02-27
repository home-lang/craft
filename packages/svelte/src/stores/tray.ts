import { writable, get } from 'svelte/store';
import { craft } from './craft';

export const trayVisible = writable(false);

export const trayActions = {
  async create(icon?: string, tooltip?: string) {
    const _$craft = get(craft);
    if (!_$craft) return;
    await _$craft.invoke('tray.create', { icon, tooltip });
    trayVisible.set(true);
  },

  async destroy() {
    const _$craft = get(craft);
    if (!_$craft) return;
    await _$craft.invoke('tray.destroy');
    trayVisible.set(false);
  },

  async setIcon(icon: string) {
    const _$craft = get(craft);
    if (!_$craft) return;
    await _$craft.invoke('tray.setIcon', { icon });
  },
};
