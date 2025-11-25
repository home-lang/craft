import { useCallback, useState } from 'react';
import { useCraft } from '../index';

/**
 * Hook to interact with the file system
 */
export function useFileSystem() {
  const { craft, isReady } = useCraft();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);

  const readFile = useCallback(
    async (path: string, encoding: 'utf8' | 'binary' = 'utf8') => {
      if (!isReady || !craft) throw new Error('Craft not ready');
      setLoading(true);
      setError(null);
      try {
        const result = await craft.invoke('fs.readFile', { path, encoding });
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

  const writeFile = useCallback(
    async (path: string, data: string | Uint8Array, encoding: 'utf8' | 'binary' = 'utf8') => {
      if (!isReady || !craft) throw new Error('Craft not ready');
      setLoading(true);
      setError(null);
      try {
        await craft.invoke('fs.writeFile', { path, data, encoding });
      } catch (err) {
        setError(err as Error);
        throw err;
      } finally {
        setLoading(false);
      }
    },
    [craft, isReady]
  );

  const readDir = useCallback(
    async (path: string) => {
      if (!isReady || !craft) throw new Error('Craft not ready');
      setLoading(true);
      setError(null);
      try {
        const result = await craft.invoke('fs.readDir', { path });
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

  const mkdir = useCallback(
    async (path: string, recursive = false) => {
      if (!isReady || !craft) throw new Error('Craft not ready');
      setLoading(true);
      setError(null);
      try {
        await craft.invoke('fs.mkdir', { path, recursive });
      } catch (err) {
        setError(err as Error);
        throw err;
      } finally {
        setLoading(false);
      }
    },
    [craft, isReady]
  );

  const remove = useCallback(
    async (path: string, recursive = false) => {
      if (!isReady || !craft) throw new Error('Craft not ready');
      setLoading(true);
      setError(null);
      try {
        await craft.invoke('fs.remove', { path, recursive });
      } catch (err) {
        setError(err as Error);
        throw err;
      } finally {
        setLoading(false);
      }
    },
    [craft, isReady]
  );

  const exists = useCallback(
    async (path: string) => {
      if (!isReady || !craft) throw new Error('Craft not ready');
      try {
        const result = await craft.invoke('fs.exists', { path });
        return result;
      } catch (err) {
        setError(err as Error);
        return false;
      }
    },
    [craft, isReady]
  );

  const stat = useCallback(
    async (path: string) => {
      if (!isReady || !craft) throw new Error('Craft not ready');
      setLoading(true);
      setError(null);
      try {
        const result = await craft.invoke('fs.stat', { path });
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

  return {
    readFile,
    writeFile,
    readDir,
    mkdir,
    remove,
    exists,
    stat,
    loading,
    error,
  };
}
