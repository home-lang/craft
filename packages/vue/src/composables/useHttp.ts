import { ref } from 'vue';
import { useCraft } from '../index';

interface HttpOptions {
  method?: 'GET' | 'POST' | 'PUT' | 'DELETE' | 'PATCH';
  headers?: Record<string, string>;
  body?: any;
  timeout?: number;
}

interface DownloadOptions {
  onProgress?: (progress: number) => void;
}

export function useHttp() {
  const { craft, isReady } = useCraft();
  const loading = ref(false);
  const error = ref<Error | null>(null);

  const fetch = async <T = any>(url: string, options: HttpOptions = {}): Promise<T> => {
    if (!isReady.value || !craft.value) throw new Error('Craft not ready');
    loading.value = true;
    error.value = null;
    try {
      const result = await craft.value.invoke('http.fetch', { url, ...options });
      return result;
    } catch (err) {
      error.value = err as Error;
      throw err;
    } finally {
      loading.value = false;
    }
  };

  const download = async (url: string, path: string, options: DownloadOptions = {}) => {
    if (!isReady.value || !craft.value) throw new Error('Craft not ready');
    loading.value = true;
    error.value = null;

    if (options.onProgress) {
      craft.value.on('download.progress', options.onProgress);
    }

    try {
      await craft.value.invoke('http.download', { url, path });
    } catch (err) {
      error.value = err as Error;
      throw err;
    } finally {
      if (options.onProgress) {
        craft.value.off('download.progress', options.onProgress);
      }
      loading.value = false;
    }
  };

  const upload = async (url: string, filePath: string, options: HttpOptions & DownloadOptions = {}) => {
    if (!isReady.value || !craft.value) throw new Error('Craft not ready');
    loading.value = true;
    error.value = null;

    if (options.onProgress) {
      craft.value.on('upload.progress', options.onProgress);
    }

    try {
      const result = await craft.value.invoke('http.upload', { url, filePath, ...options });
      return result;
    } catch (err) {
      error.value = err as Error;
      throw err;
    } finally {
      if (options.onProgress) {
        craft.value.off('upload.progress', options.onProgress);
      }
      loading.value = false;
    }
  };

  return {
    fetch,
    download,
    upload,
    loading,
    error,
  };
}
