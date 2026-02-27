import { get } from 'svelte/store';
import { craft } from '../stores/craft';

interface HttpOptions {
  method?: 'GET' | 'POST' | 'PUT' | 'DELETE' | 'PATCH';
  headers?: Record<string, string>;
  body?: any;
  timeout?: number;
}

export const http = {
  async fetch<T = any>(url: string, options: HttpOptions = {}): Promise<T> {
    const _$craft = get(craft);
    if (!_$craft) throw new Error('Craft not ready');
    return await _$craft.invoke('http.fetch', { url, ...options });
  },

  async download(url: string, path: string) {
    const _$craft = get(craft);
    if (!_$craft) throw new Error('Craft not ready');
    await _$craft.invoke('http.download', { url, path });
  },

  async upload(url: string, filePath: string, options: HttpOptions = {}) {
    const _$craft = get(craft);
    if (!_$craft) throw new Error('Craft not ready');
    return await _$craft.invoke('http.upload', { url, filePath, ...options });
  },
};
