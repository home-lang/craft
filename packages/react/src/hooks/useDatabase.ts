import { useCallback, useState } from 'react';
import { useCraft } from '../index';

/**
 * Hook to interact with SQLite database
 */
export function useDatabase(dbPath: string) {
  const { craft, isReady } = useCraft();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);

  const execute = useCallback(
    async (sql: string, params: any[] = []) => {
      if (!isReady || !craft) throw new Error('Craft not ready');
      setLoading(true);
      setError(null);
      try {
        const result = await craft.invoke('db.execute', { path: dbPath, sql, params });
        return result;
      } catch (err) {
        setError(err as Error);
        throw err;
      } finally {
        setLoading(false);
      }
    },
    [craft, isReady, dbPath]
  );

  const query = useCallback(
    async <T = any>(sql: string, params: any[] = []): Promise<T[]> => {
      if (!isReady || !craft) throw new Error('Craft not ready');
      setLoading(true);
      setError(null);
      try {
        const result = await craft.invoke('db.query', { path: dbPath, sql, params });
        return result;
      } catch (err) {
        setError(err as Error);
        throw err;
      } finally {
        setLoading(false);
      }
    },
    [craft, isReady, dbPath]
  );

  const transaction = useCallback(
    async (callback: (tx: { execute: (sql: string, params?: any[]) => Promise<any> }) => Promise<void>) => {
      if (!isReady || !craft) throw new Error('Craft not ready');
      setLoading(true);
      setError(null);
      try {
        await craft.invoke('db.transaction.begin', { path: dbPath });
        try {
          await callback({
            execute: async (sql: string, params: any[] = []) => {
              return await craft.invoke('db.execute', { path: dbPath, sql, params });
            },
          });
          await craft.invoke('db.transaction.commit', { path: dbPath });
        } catch (err) {
          await craft.invoke('db.transaction.rollback', { path: dbPath });
          throw err;
        }
      } catch (err) {
        setError(err as Error);
        throw err;
      } finally {
        setLoading(false);
      }
    },
    [craft, isReady, dbPath]
  );

  return {
    execute,
    query,
    transaction,
    loading,
    error,
  };
}
