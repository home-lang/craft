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
