import { useCallback } from 'react';
import { useCraft } from '../index';

interface NotificationOptions {
  title: string;
  body?: string;
  icon?: string;
  silent?: boolean;
  tag?: string;
  actions?: Array<{ action: string; title: string }>;
}

/**
 * Hook to send system notifications
 */
export function useNotification() {
  const { craft, isReady } = useCraft();

  const send = useCallback(
    async (options: NotificationOptions) => {
      if (!isReady || !craft) return;
      await craft.invoke('notification.send', options);
    },
    [craft, isReady]
  );

  const requestPermission = useCallback(async () => {
    if (!isReady || !craft) return false;
    const result = await craft.requestPermission('notifications');
    return result.granted;
  }, [craft, isReady]);

  return {
    send,
    requestPermission,
  };
}
