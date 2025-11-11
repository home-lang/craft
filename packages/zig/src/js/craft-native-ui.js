/**
 * Craft Native UI JavaScript API
 *
 * Provides a clean interface for creating native macOS UI components
 * from JavaScript. Components are truly native AppKit elements, not HTML/CSS.
 */

(function() {
  'use strict';

  // Ensure craft namespace exists
  if (!window.craft) {
    window.craft = {};
  }

  /**
   * Send a message to the native bridge
   */
  function sendMessage(action, data) {
    if (!window.webkit?.messageHandlers?.craft) {
      throw new Error('Craft bridge not available');
    }

    // Note: WKWebView automatically serializes the entire message object to JSON
    // So we pass data as-is and let WKWebView handle the serialization
    // The Zig side will receive it as a string that needs JSON parsing
    window.webkit.messageHandlers.craft.postMessage({
      type: 'nativeUI',
      action: action,
      data: data
    });
  }

  /**
   * Sidebar component class
   */
  class Sidebar {
    constructor(id) {
      this.id = id;
      this._selectCallbacks = [];
    }

    /**
     * Add a section to the sidebar
     * @param {Object} section - Section configuration
     * @param {string} section.id - Section identifier
     * @param {string} [section.header] - Optional section header text
     * @param {Array} section.items - Array of sidebar items
     */
    addSection(section) {
      sendMessage('addSidebarSection', {
        sidebarId: this.id,
        section: section
      });
      return this;
    }

    /**
     * Set the selected item programmatically
     * @param {string} itemId - Item identifier to select
     */
    setSelectedItem(itemId) {
      sendMessage('setSelectedItem', {
        sidebarId: this.id,
        itemId: itemId
      });
      return this;
    }

    /**
     * Register a callback for selection events
     * @param {Function} callback - Function called when item is selected
     */
    onSelect(callback) {
      this._selectCallbacks.push(callback);
      return this;
    }

    /**
     * Destroy this sidebar component
     */
    destroy() {
      sendMessage('destroyComponent', {
        id: this.id,
        type: 'sidebar'
      });
    }
  }

  /**
   * File Browser component class
   */
  class FileBrowser {
    constructor(id) {
      this.id = id;
      this._selectCallbacks = [];
      this._doubleClickCallbacks = [];
    }

    /**
     * Add a single file to the browser
     * @param {Object} file - File configuration
     * @param {string} file.id - File identifier
     * @param {string} file.name - File name
     * @param {string} [file.icon] - SF Symbol icon name
     * @param {string} [file.dateModified] - Date modified string
     * @param {string} [file.size] - File size string
     * @param {string} [file.kind] - File kind/type string
     */
    addFile(file) {
      sendMessage('addFile', {
        browserId: this.id,
        file: file
      });
      return this;
    }

    /**
     * Add multiple files to the browser
     * @param {Array} files - Array of file configurations
     */
    addFiles(files) {
      sendMessage('addFiles', {
        browserId: this.id,
        files: files
      });
      return this;
    }

    /**
     * Clear all files from the browser
     */
    clearFiles() {
      sendMessage('clearFiles', {
        browserId: this.id
      });
      return this;
    }

    /**
     * Register a callback for selection events
     * @param {Function} callback - Function called when file is selected
     */
    onSelect(callback) {
      this._selectCallbacks.push(callback);
      return this;
    }

    /**
     * Register a callback for double-click events
     * @param {Function} callback - Function called when file is double-clicked
     */
    onDoubleClick(callback) {
      this._doubleClickCallbacks.push(callback);
      return this;
    }

    /**
     * Destroy this file browser component
     */
    destroy() {
      sendMessage('destroyComponent', {
        id: this.id,
        type: 'fileBrowser'
      });
    }
  }

  /**
   * Split View component class
   */
  class SplitView {
    constructor(id, sidebar, browser) {
      this.id = id;
      this.sidebar = sidebar;
      this.browser = browser;
    }

    /**
     * Set the divider position
     * @param {number} position - Divider position in pixels
     */
    setDividerPosition(position) {
      sendMessage('setDividerPosition', {
        splitViewId: this.id,
        position: position
      });
      return this;
    }

    /**
     * Destroy this split view component
     */
    destroy() {
      sendMessage('destroyComponent', {
        id: this.id,
        type: 'splitView'
      });
    }
  }

  /**
   * Native UI API namespace
   */
  window.craft.nativeUI = {
    /**
     * Create a new native sidebar component
     * @param {Object} options - Sidebar configuration
     * @param {string} [options.id] - Optional custom identifier
     * @returns {Sidebar} Sidebar instance
     */
    createSidebar(options = {}) {
      const id = options.id || `sidebar-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;

      sendMessage('createSidebar', { id });

      return new Sidebar(id);
    },

    /**
     * Create a new native file browser component
     * @param {Object} options - File browser configuration
     * @param {string} [options.id] - Optional custom identifier
     * @returns {FileBrowser} FileBrowser instance
     */
    createFileBrowser(options = {}) {
      const id = options.id || `browser-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;

      sendMessage('createFileBrowser', { id });

      return new FileBrowser(id);
    },

    /**
     * Create a new split view combining sidebar and file browser
     * @param {Object} options - Split view configuration
     * @param {string} [options.id] - Optional custom identifier
     * @param {Sidebar} options.sidebar - Sidebar component
     * @param {FileBrowser} options.browser - File browser component
     * @returns {SplitView} SplitView instance
     */
    createSplitView(options) {
      if (!options.sidebar || !options.browser) {
        throw new Error('createSplitView requires both sidebar and browser options');
      }

      const id = options.id || `splitview-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;

      sendMessage('createSplitView', {
        id: id,
        sidebarId: options.sidebar.id,
        browserId: options.browser.id
      });

      return new SplitView(id, options.sidebar, options.browser);
    }
  };

  // Fire ready event
  const event = new CustomEvent('craft:nativeui:ready');
  document.dispatchEvent(event);

  console.log('[Craft Native UI] API initialized');
})();
