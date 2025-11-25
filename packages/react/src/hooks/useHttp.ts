import { useCallback, useState } from 'react';
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

/**
 * Hook to make HTTP requests
 */
export function useHttp() {
  const { craft, isReady } = useCraft();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);

  const fetch = useCallback(
    async <T = any>(url: string, options: HttpOptions = {}): Promise<T> => {
      if (!isReady || !craft) throw new Error('Craft not ready');
      setLoading(true);
      setError(null);
      try {
        const result = await craft.invoke('http.fetch', { url, ...options });
        return result;
      } catch (err) {
        setError(err as Error);
        throw err;
      } finally {
        setLoading(false);
      }
    },
    [craft, isReady]
  );

  const download = useCallback(
    async (url: string, path: string, options: DownloadOptions = {}) => {
      if (!isReady || !craft) throw new Error('Craft not ready');
      setLoading(true);
      setError(null);

      // Listen for progress events
      if (options.onProgress) {
        craft.on('download.progress', options.onProgress);
      }

      try {
        await craft.invoke('http.download', { url, path });
      } catch (err) {
        setError(err as Error);
        throw err;
      } finally {
        if (options.onProgress) {
          craft.off('download.progress', options.onProgress);
        }
        setLoading(false);
      }
    },
    [craft, isReady]
  );

  const upload = useCallback(
    async (url: string, filePath: string, options: HttpOptions & DownloadOptions = {}) => {
      if (!isReady || !craft) throw new Error('Craft not ready');
      setLoading(true);
      setError(null);

      // Listen for progress events
      if (options.onProgress) {
        craft.on('upload.progress', options.onProgress);
      }

      try {
        const result = await craft.invoke('http.upload', { url, filePath, ...options });
        return result;
      } catch (err) {
        setError(err as Error);
        throw err;
      } finally {
        if (options.onProgress) {
          craft.off('upload.progress', options.onProgress);
        }
        setLoading(false);
      }
    },
    [craft, isReady]
  );

  return {
    fetch,
    download,
    upload,
    loading,
    error,
  };
}
