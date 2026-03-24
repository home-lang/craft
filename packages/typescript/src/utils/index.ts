/**
 * Craft Utilities
 * Helper functions and classes for common tasks
 */

export * from './audio'
export * from './storage'
export * from './timer'

// Framework bindings are exported separately to avoid requiring all dependencies
// Import them directly:
// - import { useCraft, useWindow, useTray, useNotification } from '@craft-native/craft/utils/react'
// - import { useCraft, useWindow, useTray, CraftPlugin } from '@craft-native/craft/utils/vue'
// - import { craftStore, windowStore, trayStore, shortcut, fileDrop } from '@craft-native/craft/utils/svelte'
