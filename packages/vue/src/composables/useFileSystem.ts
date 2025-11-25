import { ref } from 'vue';
import { useCraft } from '../index';

export function useFileSystem() {
  const { craft, isReady } = useCraft();
  const loading = ref(false);
  const error = ref<Error | null>(null);

  const readFile = async (path: string, encoding: 'utf8' | 'binary' = 'utf8') => {
    if (!isReady.value || !craft.value) throw new Error('Craft not ready');
    loading.value = true;
    error.value = null;
    try {
      const result = await craft.value.invoke('fs.readFile', { path, encoding });
      return result;
    } catch (err) {
      error.value = err as Error;
      throw err;
    } finally {
      loading.value = false;
    }
  };

  const writeFile = async (path: string, data: string | Uint8Array, encoding: 'utf8' | 'binary' = 'utf8') => {
    if (!isReady.value || !craft.value) throw new Error('Craft not ready');
    loading.value = true;
    error.value = null;
    try {
      await craft.value.invoke('fs.writeFile', { path, data, encoding });
    } catch (err) {
      error.value = err as Error;
      throw err;
    } finally {
      loading.value = false;
    }
  };

  const readDir = async (path: string) => {
    if (!isReady.value || !craft.value) throw new Error('Craft not ready');
    loading.value = true;
    error.value = null;
    try {
      const result = await craft.value.invoke('fs.readDir', { path });
      return result;
    } catch (err) {
      error.value = err as Error;
      throw err;
    } finally {
      loading.value = false;
    }
  };

  const mkdir = async (path: string, recursive = false) => {
    if (!isReady.value || !craft.value) throw new Error('Craft not ready');
    loading.value = true;
    error.value = null;
    try {
      await craft.value.invoke('fs.mkdir', { path, recursive });
    } catch (err) {
      error.value = err as Error;
      throw err;
    } finally {
      loading.value = false;
    }
  };

  const remove = async (path: string, recursive = false) => {
    if (!isReady.value || !craft.value) throw new Error('Craft not ready');
    loading.value = true;
    error.value = null;
    try {
      await craft.value.invoke('fs.remove', { path, recursive });
    } catch (err) {
      error.value = err as Error;
      throw err;
    } finally {
      loading.value = false;
    }
  };

  const exists = async (path: string) => {
    if (!isReady.value || !craft.value) throw new Error('Craft not ready');
    try {
      const result = await craft.value.invoke('fs.exists', { path });
      return result;
    } catch (err) {
      error.value = err as Error;
      return false;
    }
  };

  const stat = async (path: string) => {
    if (!isReady.value || !craft.value) throw new Error('Craft not ready');
    loading.value = true;
    error.value = null;
    try {
      const result = await craft.value.invoke('fs.stat', { path });
      return result;
    } catch (err) {
      error.value = err as Error;
      throw err;
    } finally {
      loading.value = false;
    }
  };

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
