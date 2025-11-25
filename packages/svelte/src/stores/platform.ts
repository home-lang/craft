import { writable } from 'svelte/store';
import { craft } from './craft';

export function createPlatformStore() {
  const { subscribe, set } = writable<{ platform: string; version: string } | null>(null);

  craft.subscribe(async ($craft) => {
    if ($craft) {
      const info = await $craft.getPlatform();
      set(info);
    }
  });

  return { subscribe };
}

export const platform = createPlatformStore();
