import { ref } from 'vue';
import { useCraft } from '../index';

interface TrayMenuItem {
  label: string;
  id: string;
  enabled?: boolean;
  checked?: boolean;
  type?: 'normal' | 'separator' | 'checkbox';
  submenu?: TrayMenuItem[];
}

export function useTray() {
  const { craft, isReady } = useCraft();
  const isVisible = ref(false);

  const create = async (icon?: string, tooltip?: string) => {
    if (!isReady.value || !craft.value) return;
    await craft.value.invoke('tray.create', { icon, tooltip });
    isVisible.value = true;
  };

  const destroy = async () => {
    if (!isReady.value || !craft.value) return;
    await craft.value.invoke('tray.destroy');
    isVisible.value = false;
  };

  const setIcon = async (icon: string) => {
    if (!isReady.value || !craft.value) return;
    await craft.value.invoke('tray.setIcon', { icon });
  };

  const setTooltip = async (tooltip: string) => {
    if (!isReady.value || !craft.value) return;
    await craft.value.invoke('tray.setTooltip', { tooltip });
  };

  const setMenu = async (menu: TrayMenuItem[]) => {
    if (!isReady.value || !craft.value) return;
    await craft.value.invoke('tray.setMenu', { menu });
  };

  const setTitle = async (title: string) => {
    if (!isReady.value || !craft.value) return;
    await craft.value.invoke('tray.setTitle', { title });
  };

  return {
    isVisible,
    create,
    destroy,
    setIcon,
    setTooltip,
    setMenu,
    setTitle,
  };
}
