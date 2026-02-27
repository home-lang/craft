import { writable } from 'svelte/store';
import { craft } from './craft';

export function createPlatformStore() {
  const { subscribe, set } = writable<{ platform: string; version: string } | null>(null);

  craft.subscribe(async (_$craft) => {
    if (_$craft) {
      const info = await _$craft.getPlatform();
      set(info);
    }
  });

  return { subscribe };
}

export const platform = createPlatformStore();
