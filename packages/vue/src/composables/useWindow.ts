import { ref } from 'vue';
import { useCraft } from '../index';

export function useWindow() {
  const { craft, isReady } = useCraft();
  const isFullscreen = ref(false);
  const isMaximized = ref(false);
  const isMinimized = ref(false);

  const setTitle = async (title: string) => {
    if (!isReady.value || !craft.value) return;
    await craft.value.invoke('window.setTitle', { title });
  };

  const setSize = async (width: number, height: number) => {
    if (!isReady.value || !craft.value) return;
    await craft.value.invoke('window.setSize', { width, height });
  };

  const setPosition = async (x: number, y: number) => {
    if (!isReady.value || !craft.value) return;
    await craft.value.invoke('window.setPosition', { x, y });
  };

  const maximize = async () => {
    if (!isReady.value || !craft.value) return;
    await craft.value.invoke('window.maximize');
    isMaximized.value = true;
  };

  const minimize = async () => {
    if (!isReady.value || !craft.value) return;
    await craft.value.invoke('window.minimize');
    isMinimized.value = true;
  };

  const restore = async () => {
    if (!isReady.value || !craft.value) return;
    await craft.value.invoke('window.restore');
    isMaximized.value = false;
    isMinimized.value = false;
  };

  const toggleFullscreen = async () => {
    if (!isReady.value || !craft.value) return;
    await craft.value.invoke('window.toggleFullscreen');
    isFullscreen.value = !isFullscreen.value;
  };

  const close = async () => {
    if (!isReady.value || !craft.value) return;
    await craft.value.invoke('window.close');
  };

  const center = async () => {
    if (!isReady.value || !craft.value) return;
    await craft.value.invoke('window.center');
  };

  const setAlwaysOnTop = async (alwaysOnTop: boolean) => {
    if (!isReady.value || !craft.value) return;
    await craft.value.invoke('window.setAlwaysOnTop', { alwaysOnTop });
  };

  return {
    isFullscreen,
    isMaximized,
    isMinimized,
    setTitle,
    setSize,
    setPosition,
    maximize,
    minimize,
    restore,
    toggleFullscreen,
    close,
    center,
    setAlwaysOnTop,
  };
}
