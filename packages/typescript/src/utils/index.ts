/**
 * Craft Utilities
 * Helper functions and classes for common tasks
 */

export * from './audio'
export * from './storage'
export * from './timer'

// Framework bindings are exported separately to avoid requiring all dependencies
// Import them directly:
// - import { useCraft, useWindow, useTray, useNotification } from 'ts-craft/utils/react'
// - import { useCraft, useWindow, useTray, CraftPlugin } from 'ts-craft/utils/vue'
// - import { craftStore, windowStore, trayStore, shortcut, fileDrop } from 'ts-craft/utils/svelte'
