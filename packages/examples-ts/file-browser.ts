/**
 * File Browser Example
 * A Finder-like app with Tahoe-style sidebar
 *
 * Features:
 * - macOS Finder-style sidebar
 * - Translucent vibrancy effect
 * - Section groups (Favorites, iCloud, Tags)
 * - Badge counts
 * - Dark mode support
 */

import { createApp } from '@stacksjs/ts-craft'

const html = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>File Browser</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <style>
    /* Custom scrollbar */
    .scrollbar-thin::-webkit-scrollbar { width: 6px; }
    .scrollbar-thin::-webkit-scrollbar-track { background: transparent; }
    .scrollbar-thin::-webkit-scrollbar-thumb { background: rgba(0,0,0,0.1); border-radius: 3px; }
    .dark .scrollbar-thin::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.1); }

    /* Titlebar drag region */
    .titlebar { -webkit-app-region: drag; }
    .titlebar * { -webkit-app-region: no-drag; }

    /* Selection */
    ::selection { background: rgba(59, 130, 246, 0.3); }
  </style>
</head>
<body class="bg-neutral-100 dark:bg-neutral-900 h-screen flex flex-col overflow-hidden">
  <!-- Titlebar -->
  <div class="titlebar h-12 bg-white/70 dark:bg-neutral-800/70 backdrop-blur-xl border-b border-black/5 dark:border-white/5 flex items-center px-20">
    <div class="flex-1 flex items-center gap-2">
      <button class="p-1.5 rounded hover:bg-black/5 dark:hover:bg-white/5">
        <svg class="w-4 h-4 text-neutral-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"/>
        </svg>
      </button>
      <button class="p-1.5 rounded hover:bg-black/5 dark:hover:bg-white/5">
        <svg class="w-4 h-4 text-neutral-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
        </svg>
      </button>
    </div>
    <div class="text-sm font-medium text-neutral-700 dark:text-neutral-200">Desktop</div>
    <div class="flex-1 flex justify-end gap-2">
      <button class="p-1.5 rounded hover:bg-black/5 dark:hover:bg-white/5">
        <svg class="w-4 h-4 text-neutral-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 10h16M4 14h16M4 18h16"/>
        </svg>
      </button>
      <button class="p-1.5 rounded hover:bg-black/5 dark:hover:bg-white/5">
        <svg class="w-4 h-4 text-neutral-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
        </svg>
      </button>
    </div>
  </div>

  <!-- Main content -->
  <div class="flex-1 flex overflow-hidden">
    <!-- Sidebar (Tahoe style) -->
    <div class="w-56 h-full flex flex-col bg-white/70 dark:bg-neutral-900/70 backdrop-blur-xl backdrop-saturate-150 border-r border-black/5 dark:border-white/5 select-none">
      <!-- Search -->
      <div class="px-2 py-2">
        <div class="relative">
          <svg class="absolute left-2.5 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-neutral-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
          </svg>
          <input type="text" placeholder="Search" class="w-full pl-8 pr-3 py-1.5 rounded-md text-[13px] placeholder:text-neutral-400 bg-black/5 dark:bg-white/5 border border-transparent focus:outline-none focus:border-blue-500/50 focus:bg-white dark:focus:bg-neutral-800 transition-all duration-150">
        </div>
      </div>

      <!-- Scrollable content -->
      <div class="flex-1 overflow-y-auto overflow-x-hidden py-1 px-2 scrollbar-thin">
        <!-- Favorites section -->
        <div class="mb-4">
          <div class="px-2 py-1.5 mb-1 text-[11px] font-semibold uppercase tracking-wider text-neutral-500 dark:text-neutral-400">
            Favorites
          </div>
          <div class="sidebar-item" data-id="airdrop">
            <svg class="w-4 h-4 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.111 16.404a5.5 5.5 0 017.778 0M12 20h.01m-7.08-7.071c3.904-3.905 10.236-3.905 14.14 0M1.394 9.393c5.857-5.857 15.355-5.857 21.213 0"/></svg>
            <span class="flex-1 truncate">AirDrop</span>
          </div>
          <div class="sidebar-item" data-id="recents">
            <svg class="w-4 h-4 text-neutral-500 dark:text-neutral-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
            <span class="flex-1 truncate">Recents</span>
            <span class="badge">12</span>
          </div>
          <div class="sidebar-item" data-id="applications">
            <svg class="w-4 h-4 text-neutral-500 dark:text-neutral-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z"/></svg>
            <span class="flex-1 truncate">Applications</span>
          </div>
          <div class="sidebar-item selected" data-id="desktop">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/></svg>
            <span class="flex-1 truncate">Desktop</span>
          </div>
          <div class="sidebar-item" data-id="documents">
            <svg class="w-4 h-4 text-neutral-500 dark:text-neutral-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z"/></svg>
            <span class="flex-1 truncate">Documents</span>
          </div>
          <div class="sidebar-item" data-id="downloads">
            <svg class="w-4 h-4 text-neutral-500 dark:text-neutral-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"/></svg>
            <span class="flex-1 truncate">Downloads</span>
            <span class="badge">3</span>
          </div>
        </div>

        <!-- iCloud section -->
        <div class="mb-4">
          <div class="px-2 py-1.5 mb-1 text-[11px] font-semibold uppercase tracking-wider text-neutral-500 dark:text-neutral-400 flex items-center gap-1 cursor-pointer hover:text-neutral-700 dark:hover:text-neutral-200">
            <svg class="w-3 h-3 rotate-90" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/></svg>
            iCloud
          </div>
          <div class="sidebar-item" data-id="icloud-drive">
            <svg class="w-4 h-4 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 15a4 4 0 004 4h9a5 5 0 10-.1-9.999 5.002 5.002 0 10-9.78 2.096A4.001 4.001 0 003 15z"/></svg>
            <span class="flex-1 truncate">iCloud Drive</span>
          </div>
          <div class="sidebar-item" data-id="shared">
            <svg class="w-4 h-4 text-neutral-500 dark:text-neutral-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"/></svg>
            <span class="flex-1 truncate">Shared</span>
          </div>
        </div>

        <!-- Tags section -->
        <div class="mb-4">
          <div class="px-2 py-1.5 mb-1 text-[11px] font-semibold uppercase tracking-wider text-neutral-500 dark:text-neutral-400 flex items-center gap-1 cursor-pointer hover:text-neutral-700 dark:hover:text-neutral-200">
            <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/></svg>
            Tags
          </div>
        </div>
      </div>
    </div>

    <!-- Content area -->
    <div class="flex-1 bg-white dark:bg-neutral-800 overflow-auto p-4">
      <div class="grid grid-cols-4 gap-4">
        <!-- Sample files -->
        <div class="file-item">
          <div class="w-16 h-16 mx-auto mb-2 bg-blue-100 dark:bg-blue-900/30 rounded-lg flex items-center justify-center">
            <svg class="w-8 h-8 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z"/></svg>
          </div>
          <div class="text-xs text-center text-neutral-700 dark:text-neutral-300 truncate">Projects</div>
        </div>
        <div class="file-item">
          <div class="w-16 h-16 mx-auto mb-2 bg-purple-100 dark:bg-purple-900/30 rounded-lg flex items-center justify-center">
            <svg class="w-8 h-8 text-purple-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/></svg>
          </div>
          <div class="text-xs text-center text-neutral-700 dark:text-neutral-300 truncate">Notes.md</div>
        </div>
        <div class="file-item">
          <div class="w-16 h-16 mx-auto mb-2 bg-green-100 dark:bg-green-900/30 rounded-lg flex items-center justify-center">
            <svg class="w-8 h-8 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/></svg>
          </div>
          <div class="text-xs text-center text-neutral-700 dark:text-neutral-300 truncate">Screenshot.png</div>
        </div>
        <div class="file-item">
          <div class="w-16 h-16 mx-auto mb-2 bg-orange-100 dark:bg-orange-900/30 rounded-lg flex items-center justify-center">
            <svg class="w-8 h-8 text-orange-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z"/></svg>
          </div>
          <div class="text-xs text-center text-neutral-700 dark:text-neutral-300 truncate">Archive</div>
        </div>
      </div>
    </div>
  </div>

  <style>
    .sidebar-item {
      display: flex;
      align-items: center;
      gap: 0.625rem;
      padding: 0.375rem 0.5rem;
      margin: 0 0.25rem;
      border-radius: 0.375rem;
      font-size: 0.8125rem;
      color: rgb(64 64 64);
      cursor: pointer;
      transition: all 0.15s;
    }
    .dark .sidebar-item { color: rgb(229 229 229); }
    .sidebar-item:hover { background: rgba(0,0,0,0.05); }
    .dark .sidebar-item:hover { background: rgba(255,255,255,0.05); }

    .sidebar-item.selected {
      background: rgb(59 130 246);
      color: white;
      box-shadow: 0 1px 2px rgba(0,0,0,0.1);
    }
    .sidebar-item.selected svg { color: rgba(255,255,255,0.9) !important; }

    .badge {
      padding: 0.125rem 0.375rem;
      border-radius: 9999px;
      font-size: 0.625rem;
      font-weight: 500;
      background: rgb(229 229 229);
      color: rgb(82 82 82);
    }
    .dark .badge { background: rgb(64 64 64); color: rgb(212 212 212); }
    .selected .badge { background: rgba(255,255,255,0.2); color: white; }

    .file-item {
      padding: 0.75rem;
      border-radius: 0.5rem;
      cursor: pointer;
      transition: all 0.15s;
    }
    .file-item:hover { background: rgba(0,0,0,0.05); }
    .dark .file-item:hover { background: rgba(255,255,255,0.05); }
  </style>

  <script>
    // Handle sidebar item clicks
    document.querySelectorAll('.sidebar-item').forEach(item => {
      item.addEventListener('click', () => {
        document.querySelectorAll('.sidebar-item').forEach(i => i.classList.remove('selected'));
        item.classList.add('selected');
        console.log('Selected:', item.dataset.id);
      });
    });

    // Detect dark mode
    if (window.matchMedia('(prefers-color-scheme: dark)').matches) {
      document.documentElement.classList.add('dark');
    }
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', e => {
      document.documentElement.classList.toggle('dark', e.matches);
    });
  </script>
</body>
</html>
`

const app = createApp({
  html,
  window: {
    title: 'File Browser',
    width: 900,
    height: 600,
    resizable: true,
    titlebarHidden: true,
  },
})

await app.show()
