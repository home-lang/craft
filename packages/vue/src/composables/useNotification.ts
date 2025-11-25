import { useCraft } from '../index';

interface NotificationOptions {
  title: string;
  body?: string;
  icon?: string;
  silent?: boolean;
  tag?: string;
  actions?: Array<{ action: string; title: string }>;
}

export function useNotification() {
  const { craft, isReady } = useCraft();

  const send = async (options: NotificationOptions) => {
    if (!isReady.value || !craft.value) return;
    await craft.value.invoke('notification.send', options);
  };

  const requestPermission = async () => {
    if (!isReady.value || !craft.value) return false;
    const result = await craft.value.requestPermission('notifications');
    return result.granted;
  };

  return {
    send,
    requestPermission,
  };
}
