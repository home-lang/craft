import { ref } from 'vue';
import { useCraft } from '../index';

export function useDatabase(dbPath: string) {
  const { craft, isReady } = useCraft();
  const loading = ref(false);
  const error = ref<Error | null>(null);

  const execute = async (sql: string, params: any[] = []) => {
    if (!isReady.value || !craft.value) throw new Error('Craft not ready');
    loading.value = true;
    error.value = null;
    try {
      const result = await craft.value.invoke('db.execute', { path: dbPath, sql, params });
      return result;
    } catch (err) {
      error.value = err as Error;
      throw err;
    } finally {
      loading.value = false;
    }
  };

  const query = async <T = any>(sql: string, params: any[] = []): Promise<T[]> => {
    if (!isReady.value || !craft.value) throw new Error('Craft not ready');
    loading.value = true;
    error.value = null;
    try {
      const result = await craft.value.invoke('db.query', { path: dbPath, sql, params });
      return result;
    } catch (err) {
      error.value = err as Error;
      throw err;
    } finally {
      loading.value = false;
    }
  };

  const transaction = async (callback: (tx: { execute: (sql: string, params?: any[]) => Promise<any> }) => Promise<void>) => {
    if (!isReady.value || !craft.value) throw new Error('Craft not ready');
    loading.value = true;
    error.value = null;
    try {
      await craft.value.invoke('db.transaction.begin', { path: dbPath });
      try {
        await callback({
          execute: async (sql: string, params: any[] = []) => {
            return await craft.value!.invoke('db.execute', { path: dbPath, sql, params });
          },
        });
        await craft.value.invoke('db.transaction.commit', { path: dbPath });
      } catch (err) {
        await craft.value.invoke('db.transaction.rollback', { path: dbPath });
        throw err;
      }
    } catch (err) {
      error.value = err as Error;
      throw err;
    } finally {
      loading.value = false;
    }
  };

  return {
    execute,
    query,
    transaction,
    loading,
    error,
  };
}
