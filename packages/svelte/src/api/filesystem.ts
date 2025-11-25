import { get } from 'svelte/store';
import { craft } from '../stores/craft';

export const filesystem = {
  async readFile(path: string, encoding: 'utf8' | 'binary' = 'utf8') {
    const $craft = get(craft);
    if (!$craft) throw new Error('Craft not ready');
    return await $craft.invoke('fs.readFile', { path, encoding });
  },

  async writeFile(path: string, data: string | Uint8Array, encoding: 'utf8' | 'binary' = 'utf8') {
    const $craft = get(craft);
    if (!$craft) throw new Error('Craft not ready');
    await $craft.invoke('fs.writeFile', { path, data, encoding });
  },

  async readDir(path: string) {
    const $craft = get(craft);
    if (!$craft) throw new Error('Craft not ready');
    return await $craft.invoke('fs.readDir', { path });
  },

  async mkdir(path: string, recursive = false) {
    const $craft = get(craft);
    if (!$craft) throw new Error('Craft not ready');
    await $craft.invoke('fs.mkdir', { path, recursive });
  },

  async remove(path: string, recursive = false) {
    const $craft = get(craft);
    if (!$craft) throw new Error('Craft not ready');
    await $craft.invoke('fs.remove', { path, recursive });
  },

  async exists(path: string) {
    const $craft = get(craft);
    if (!$craft) throw new Error('Craft not ready');
    return await $craft.invoke('fs.exists', { path });
  },
};
