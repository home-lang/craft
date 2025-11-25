import { get } from 'svelte/store';
import { craft } from '../stores/craft';

export function createDatabase(dbPath: string) {
  return {
    async execute(sql: string, params: any[] = []) {
      const $craft = get(craft);
      if (!$craft) throw new Error('Craft not ready');
      return await $craft.invoke('db.execute', { path: dbPath, sql, params });
    },

    async query<T = any>(sql: string, params: any[] = []): Promise<T[]> {
      const $craft = get(craft);
      if (!$craft) throw new Error('Craft not ready');
      return await $craft.invoke('db.query', { path: dbPath, sql, params });
    },
  };
}
