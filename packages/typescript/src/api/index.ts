/**
 * Craft API Modules
 * Native APIs available in Craft applications
 */

// File System API
export { fs, readBinaryFile, writeBinaryFile, stat, copy, move, watch } from './fs'
export type { FileStats } from './fs'

// Database API
export { db, openDatabase, Database, KeyValueStore } from './db'
export type { ExecuteResult, TableColumn } from './db'

// HTTP Client API
export { http, HttpClient, WebSocketClient, createClient, HttpError } from './http'
export type { HttpClientOptions, RequestOptions, HttpResponse, WebSocketOptions } from './http'

// Crypto API
export {
  crypto,
  uuid,
  randomString,
  hmac,
  timingSafeEqual,
  hashPassword,
  verifyPassword
} from './crypto'

// Process API
export {
  env,
  getPlatform,
  isDesktop,
  isMobile,
  isCraft,
  getSystemInfo,
  exec,
  spawn,
  ChildProcess,
  cwd,
  homeDir,
  tempDir,
  exit,
  argv,
  open
} from './process'
export type { Platform, SystemInfo, ExecOptions, ExecResult, SpawnOptions } from './process'

// Mobile API - Unified cross-platform mobile features
export {
  device,
  haptics,
  permissions,
  camera,
  biometrics,
  secureStorage,
  location,
  share,
  lifecycle,
  notifications
} from './mobile'
export type {
  DeviceInfo,
  DeviceCapabilities,
  HapticStyle,
  HapticNotificationType,
  PermissionType,
  PermissionStatus,
  CameraOptions,
  PhotoResult,
  BiometricType,
  Location,
  LocationOptions,
  ShareOptions,
  AppState,
  NotificationOptions
} from './mobile'

// iOS Advanced Features
export {
  carplay,
  appClips,
  liveActivities,
  sharePlay,
  storeKit,
  appIntents,
  tipKit,
  focusFilters
} from './ios-advanced'
export type {
  CarPlayTemplateType,
  CarPlayListItem,
  CarPlayGridItem,
  CarPlayTemplate,
  AppClipInvocation,
  LiveActivityContentState,
  LiveActivityAttributes,
  LiveActivityConfig,
  SharePlaySessionState,
  SharePlayParticipant,
  SharePlayActivity,
  ProductType,
  Product,
  Transaction,
  IntentParameterType,
  IntentParameter,
  AppIntent,
  TipDisplayFrequency,
  Tip,
  FocusStatus,
  FocusFilter
} from './ios-advanced'

// Android Advanced Features
export {
  materialYou,
  photoPicker,
  workManager,
  foregroundService,
  predictiveBack,
  appLanguage,
  widgets as androidWidgets,
  playBilling
} from './android-advanced'
export type {
  MaterialYouColors,
  PhotoPickerMediaType,
  PhotoPickerResult,
  WorkConstraints,
  WorkRequest,
  WorkInfo,
  ForegroundServiceType,
  ForegroundNotification,
  BackEvent,
  WidgetSizeClass,
  WidgetConfig,
  WidgetData,
  PlayProduct,
  PlayPurchase
} from './android-advanced'

// macOS Advanced Features
export {
  touchBar,
  desktopWidgets,
  stageManager,
  handoff,
  sidecar,
  spotlight,
  quickActions,
  shareExtension,
  windowManagement
} from './macos-advanced'
export type {
  TouchBarItemType,
  TouchBarButton,
  TouchBarLabel,
  TouchBarSlider,
  TouchBarColorPicker,
  TouchBarScrubber,
  TouchBarSegmentedControl,
  TouchBarPopover,
  TouchBarSpacer,
  TouchBarGroup,
  TouchBarItem,
  WidgetFamily,
  WidgetTimelineEntry,
  WidgetConfiguration,
  UserActivity,
  SidecarDevice,
  SpotlightItem,
  QuickAction,
  WindowTabGroup
} from './macos-advanced'

// Windows Advanced Features
export {
  jumpList,
  taskbarProgress,
  toastNotifications,
  windowsHello,
  windowsWidgets,
  msixUpdate,
  shareTarget,
  startupTask,
  secondaryTiles
} from './windows-advanced'
export type {
  JumpListTask,
  JumpListCategory,
  TaskbarProgressState,
  ToastAction,
  ToastInput,
  ToastContent,
  WindowsHelloAvailability,
  WidgetTemplateType,
  WindowsWidgetContent,
  PackageVersion,
  UpdateInfo,
  SharedDataItem,
  SecondaryTile
} from './windows-advanced'
