/**
 * Craft Bridge TypeScript Type Definitions
 * Auto-generated type definitions for Craft's native bridge APIs
 */

// ============================================
// Window Bridge Types
// ============================================

export interface WindowBridge {
  show(): Promise<void>;
  hide(): Promise<void>;
  toggle(): Promise<void>;
  focus(): Promise<void>;
  minimize(): Promise<void>;
  maximize(): Promise<void>;
  close(): Promise<void>;
  center(): Promise<void>;
  toggleFullscreen(): Promise<void>;
  setFullscreen(options: { fullscreen: boolean }): Promise<void>;
  setSize(options: { width: number; height: number }): Promise<void>;
  setPosition(options: { x: number; y: number }): Promise<void>;
  setTitle(options: { title: string }): Promise<void>;
  reload(): Promise<void>;
  setVibrancy(options: { vibrancy: VibrancyType }): Promise<void>;
  setAlwaysOnTop(options: { alwaysOnTop: boolean }): Promise<void>;
  setOpacity(options: { opacity: number }): Promise<void>;
  setResizable(options: { resizable: boolean }): Promise<void>;
  setBackgroundColor(options: BackgroundColorOptions): Promise<void>;
  setMinSize(options: { width: number; height: number }): Promise<void>;
  setMaxSize(options: { width: number; height: number }): Promise<void>;
  setMovable(options: { movable: boolean }): Promise<void>;
  setHasShadow(options: { hasShadow: boolean }): Promise<void>;
  setAspectRatio(options: AspectRatioOptions): Promise<void>;
  flashFrame(options: { flash: boolean }): Promise<void>;
  setProgressBar(options: { progress: number }): Promise<void>;
}

export type VibrancyType =
  | 'none'
  | 'sidebar'
  | 'header'
  | 'sheet'
  | 'menu'
  | 'popover'
  | 'fullscreen-ui'
  | 'hud'
  | 'titlebar';

export type BackgroundColorOptions =
  | { color: string } // Hex color "#RRGGBB"
  | { r: number; g: number; b: number; a?: number };

export type AspectRatioOptions =
  | { ratio: number }
  | { width: number; height: number };

// ============================================
// Dialog Bridge Types
// ============================================

export interface DialogBridge {
  showOpenDialog(options: OpenDialogOptions): Promise<OpenDialogResult>;
  showSaveDialog(options: SaveDialogOptions): Promise<SaveDialogResult>;
  showMessageBox(options: MessageBoxOptions): Promise<MessageBoxResult>;
  showColorPicker(options?: ColorPickerOptions): Promise<ColorPickerResult>;
  showFontPicker(options?: FontPickerOptions): Promise<FontPickerResult>;
}

export interface OpenDialogOptions {
  title?: string;
  defaultPath?: string;
  buttonLabel?: string;
  filters?: FileFilter[];
  multiSelections?: boolean;
  showHiddenFiles?: boolean;
  canChooseDirectories?: boolean;
  canChooseFiles?: boolean;
  canCreateDirectories?: boolean;
}

export interface SaveDialogOptions {
  title?: string;
  defaultPath?: string;
  buttonLabel?: string;
  filters?: FileFilter[];
  showHiddenFiles?: boolean;
  canCreateDirectories?: boolean;
}

export interface FileFilter {
  name: string;
  extensions: string[];
}

export interface OpenDialogResult {
  canceled: boolean;
  filePaths: string[];
}

export interface SaveDialogResult {
  canceled: boolean;
  filePath?: string;
}

export interface MessageBoxOptions {
  type?: 'none' | 'info' | 'warning' | 'error' | 'question';
  title?: string;
  message: string;
  detail?: string;
  buttons?: string[];
  defaultButton?: number;
  cancelButton?: number;
}

export interface MessageBoxResult {
  response: number;
}

export interface ColorPickerOptions {
  color?: string;
  showAlpha?: boolean;
}

export interface ColorPickerResult {
  canceled: boolean;
  color?: string;
}

export interface FontPickerOptions {
  fontFamily?: string;
  fontSize?: number;
}

export interface FontPickerResult {
  canceled: boolean;
  fontFamily?: string;
  fontSize?: number;
}

// ============================================
// Clipboard Bridge Types
// ============================================

export interface ClipboardBridge {
  writeText(options: { text: string }): Promise<void>;
  readText(): Promise<{ text: string }>;
  writeHTML(options: { html: string }): Promise<void>;
  readHTML(): Promise<{ html: string }>;
  clear(): Promise<void>;
  hasText(): Promise<{ value: boolean }>;
  hasHTML(): Promise<{ value: boolean }>;
  hasImage(): Promise<{ value: boolean }>;
}

// ============================================
// Notification Bridge Types
// ============================================

export interface NotificationBridge {
  show(options: NotificationOptions): Promise<void>;
  schedule(options: ScheduledNotificationOptions): Promise<void>;
  cancel(options: { id: string }): Promise<void>;
  cancelAll(): Promise<void>;
  setBadge(options: { count: number }): Promise<void>;
  clearBadge(): Promise<void>;
  requestPermission(): Promise<{ granted: boolean }>;
}

export interface NotificationOptions {
  id?: string;
  title: string;
  body?: string;
  subtitle?: string;
  sound?: string | boolean;
  badge?: number;
  threadId?: string;
  actions?: NotificationAction[];
}

export interface ScheduledNotificationOptions extends NotificationOptions {
  triggerAt: number; // Unix timestamp in seconds
  repeats?: boolean;
}

export interface NotificationAction {
  id: string;
  title: string;
  destructive?: boolean;
}

// ============================================
// Menu Bridge Types
// ============================================

export interface MenuBridge {
  setAppMenu(options: { menus: MenuDefinition[] }): Promise<void>;
  setDockMenu(options: { items: MenuItemDefinition[] }): Promise<void>;
  addMenuItem(options: AddMenuItemOptions): Promise<void>;
  removeMenuItem(options: { id: string }): Promise<void>;
  enableMenuItem(options: { id: string }): Promise<void>;
  disableMenuItem(options: { id: string }): Promise<void>;
  checkMenuItem(options: { id: string }): Promise<void>;
  uncheckMenuItem(options: { id: string }): Promise<void>;
  setMenuItemLabel(options: { id: string; label: string }): Promise<void>;
  clearDockMenu(): Promise<void>;
}

export interface MenuDefinition {
  label: string;
  items: MenuItemDefinition[];
}

export interface MenuItemDefinition {
  id: string;
  label: string;
  type?: 'normal' | 'separator' | 'checkbox' | 'radio';
  checked?: boolean;
  enabled?: boolean;
  action?: string;
  shortcut?: string;
  icon?: string; // Icon name from icons.zig
  submenu?: MenuItemDefinition[];
}

export interface AddMenuItemOptions {
  menuId: string;
  item: MenuItemDefinition;
  position?: number;
}

// ============================================
// Tray Bridge Types
// ============================================

export interface TrayBridge {
  create(options: TrayOptions): Promise<void>;
  destroy(): Promise<void>;
  setIcon(options: { icon: string }): Promise<void>;
  setTitle(options: { title: string }): Promise<void>;
  setTooltip(options: { tooltip: string }): Promise<void>;
  setMenu(options: { items: MenuItemDefinition[] }): Promise<void>;
}

export interface TrayOptions {
  icon: string;
  title?: string;
  tooltip?: string;
  menu?: MenuItemDefinition[];
}

// ============================================
// Power Bridge Types
// ============================================

export interface PowerBridge {
  getBatteryLevel(): Promise<{ level: number }>; // -1 if no battery
  isCharging(): Promise<{ charging: boolean }>;
  isPluggedIn(): Promise<{ pluggedIn: boolean }>;
  getBatteryState(): Promise<{ state: BatteryState }>;
  getTimeRemaining(): Promise<{ minutes: number }>; // -1 if N/A
  preventSleep(options?: { reason?: string }): Promise<void>;
  allowSleep(): Promise<void>;
  isLowPowerMode(): Promise<{ enabled: boolean }>;
  getThermalState(): Promise<{ state: ThermalState }>;
  getUptimeSeconds(): Promise<{ seconds: number }>;
}

export type BatteryState = 'unknown' | 'unplugged' | 'charging' | 'charged' | 'noBattery';
export type ThermalState = 'nominal' | 'fair' | 'serious' | 'critical' | 'unknown';

// ============================================
// Bluetooth Bridge Types
// ============================================

export interface BluetoothBridge {
  isAvailable(): Promise<{ available: boolean }>;
  isEnabled(): Promise<{ enabled: boolean }>;
  getPowerState(): Promise<{ state: BluetoothPowerState }>;
  getConnectedDevices(): Promise<{ devices: BluetoothDevice[] }>;
  getPairedDevices(): Promise<{ devices: BluetoothDevice[] }>;
  startDiscovery(): Promise<void>;
  stopDiscovery(): Promise<void>;
  isDiscovering(): Promise<{ discovering: boolean }>;
  connectDevice(options: { address: string }): Promise<void>;
  disconnectDevice(options: { address: string }): Promise<void>;
  openBluetoothPreferences(): Promise<void>;
}

export type BluetoothPowerState = 'off' | 'on' | 'initializing' | 'unknown';

export interface BluetoothDevice {
  name: string;
  address: string;
  connected: boolean;
}

// ============================================
// System Bridge Types
// ============================================

export interface SystemBridge {
  getOSVersion(): Promise<{ version: string }>;
  getHostname(): Promise<{ hostname: string }>;
  getUsername(): Promise<{ username: string }>;
  getHomeDirectory(): Promise<{ path: string }>;
  getTempDirectory(): Promise<{ path: string }>;
  getLocale(): Promise<{ locale: string }>;
  getTimezone(): Promise<{ timezone: string }>;
  isDarkMode(): Promise<{ darkMode: boolean }>;
  openUrl(options: { url: string }): Promise<void>;
  openPath(options: { path: string }): Promise<void>;
  showItemInFolder(options: { path: string }): Promise<void>;
  beep(): Promise<void>;
}

// ============================================
// Shortcuts Bridge Types
// ============================================

export interface ShortcutsBridge {
  register(options: ShortcutOptions): Promise<{ success: boolean }>;
  unregister(options: { accelerator: string }): Promise<void>;
  unregisterAll(): Promise<void>;
  isRegistered(options: { accelerator: string }): Promise<{ registered: boolean }>;
}

export interface ShortcutOptions {
  accelerator: string; // e.g., "CommandOrControl+Shift+P"
  callback: string; // JS callback name
}

// ============================================
// File System Bridge Types
// ============================================

export interface FSBridge {
  readFile(options: { path: string; encoding?: string }): Promise<{ content: string }>;
  writeFile(options: { path: string; content: string; encoding?: string }): Promise<void>;
  appendFile(options: { path: string; content: string }): Promise<void>;
  deleteFile(options: { path: string }): Promise<void>;
  exists(options: { path: string }): Promise<{ exists: boolean }>;
  stat(options: { path: string }): Promise<FileStats>;
  mkdir(options: { path: string; recursive?: boolean }): Promise<void>;
  rmdir(options: { path: string; recursive?: boolean }): Promise<void>;
  readdir(options: { path: string }): Promise<{ entries: DirEntry[] }>;
  copyFile(options: { source: string; destination: string }): Promise<void>;
  moveFile(options: { source: string; destination: string }): Promise<void>;
  watch(options: { path: string; callback: string }): Promise<void>;
  unwatch(options: { path: string }): Promise<void>;
}

export interface FileStats {
  size: number;
  isFile: boolean;
  isDirectory: boolean;
  isSymlink: boolean;
  created: number;
  modified: number;
  accessed: number;
}

export interface DirEntry {
  name: string;
  isFile: boolean;
  isDirectory: boolean;
  isSymlink: boolean;
}

// ============================================
// Updater Bridge Types (macOS Sparkle)
// ============================================

export interface UpdaterBridge {
  configure(options: UpdaterConfig): Promise<void>;
  checkForUpdates(): Promise<void>;
  checkForUpdatesInBackground(): Promise<void>;
  setAutomaticChecks(options: { enabled: boolean }): Promise<void>;
  setCheckInterval(options: { seconds: number }): Promise<void>;
  setFeedURL(options: { url: string }): Promise<void>;
  getLastUpdateCheckDate(): Promise<{ date: string | null }>;
  getUpdateInfo(): Promise<UpdateInfo | null>;
}

export interface UpdaterConfig {
  feedURL: string;
  automaticChecks?: boolean;
  checkInterval?: number; // seconds
}

export interface UpdateInfo {
  version: string;
  releaseNotes?: string;
  pubDate?: string;
}

// ============================================
// Icon Types (Cross-platform)
// ============================================

export type IconName =
  // Navigation
  | 'chevron_left' | 'chevron_right' | 'chevron_up' | 'chevron_down'
  | 'arrow_left' | 'arrow_right' | 'arrow_up' | 'arrow_down'
  | 'home' | 'menu' | 'more_horizontal' | 'more_vertical'
  // Actions
  | 'plus' | 'minus' | 'close' | 'check' | 'search' | 'refresh'
  | 'edit' | 'delete' | 'copy' | 'paste' | 'cut' | 'undo' | 'redo'
  | 'share' | 'download' | 'upload' | 'print' | 'save'
  // Media
  | 'play' | 'pause' | 'stop' | 'skip_forward' | 'skip_back'
  | 'volume_up' | 'volume_down' | 'volume_mute' | 'mic' | 'mic_off'
  // Files
  | 'file' | 'folder' | 'folder_open' | 'document' | 'image' | 'video' | 'audio'
  // Communication
  | 'mail' | 'message' | 'phone' | 'video_call' | 'send'
  // System
  | 'settings' | 'help' | 'info' | 'warning' | 'error'
  | 'lock' | 'unlock' | 'user' | 'users' | 'wifi' | 'bluetooth'
  // Status
  | 'star' | 'star_filled' | 'heart' | 'heart_filled' | 'bookmark' | 'flag';

// ============================================
// Main Craft Bridge Interface
// ============================================

export interface CraftBridge {
  window: WindowBridge;
  dialog: DialogBridge;
  clipboard: ClipboardBridge;
  notification: NotificationBridge;
  menu: MenuBridge;
  tray: TrayBridge;
  power: PowerBridge;
  bluetooth: BluetoothBridge;
  system: SystemBridge;
  shortcuts: ShortcutsBridge;
  fs: FSBridge;
  updater: UpdaterBridge;
}

declare global {
  interface Window {
    craft: CraftBridge;
  }
}

export {};
