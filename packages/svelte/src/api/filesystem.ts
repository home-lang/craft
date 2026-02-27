import { get } from 'svelte/store';
import { craft } from '../stores/craft';

export const filesystem = {
  async readFile(path: string, encoding: 'utf8' | 'binary' = 'utf8') {
    const _$craft = get(craft);
    if (!_$craft) throw new Error('Craft not ready');
    return await _$craft.invoke('fs.readFile', { path, encoding });
  },

  async writeFile(path: string, data: string | Uint8Array, encoding: 'utf8' | 'binary' = 'utf8') {
    const _$craft = get(craft);
    if (!_$craft) throw new Error('Craft not ready');
    await _$craft.invoke('fs.writeFile', { path, data, encoding });
  },

  async readDir(path: string) {
    const _$craft = get(craft);
    if (!_$craft) throw new Error('Craft not ready');
    return await _$craft.invoke('fs.readDir', { path });
  },

  async mkdir(path: string, recursive = false) {
    const _$craft = get(craft);
    if (!_$craft) throw new Error('Craft not ready');
    await _$craft.invoke('fs.mkdir', { path, recursive });
  },

  async remove(path: string, recursive = false) {
    const _$craft = get(craft);
    if (!_$craft) throw new Error('Craft not ready');
    await _$craft.invoke('fs.remove', { path, recursive });
  },

  async exists(path: string) {
    const _$craft = get(craft);
    if (!_$craft) throw new Error('Craft not ready');
    return await _$craft.invoke('fs.exists', { path });
  },
};
