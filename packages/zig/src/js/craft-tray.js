// Craft System Tray JavaScript API
// This file is injected into every webview to provide tray control functionality

window.craft = window.craft || {};

window.craft.tray = {
  /**
   * Update the system tray title/text
   * @param {string} title - Text to show in menubar (e.g., "🍅 25:00")
   * @returns {Promise<void>}
   */
  async setTitle(title) {
    if (typeof title !== 'string') {
      throw new TypeError('Title must be a string');
    }

    // Max 20 characters to avoid menubar overflow
    if (title.length > 20) {
      console.warn('Tray title truncated to 20 characters');
      title = title.substring(0, 20);
    }

    return new Promise((resolve, reject) => {
      try {
        window.webkit.messageHandlers.craft.postMessage({
          type: 'tray',
          action: 'setTitle',
          data: title
        });
        resolve();
      } catch (error) {
        reject(new Error(`Failed to set tray title: ${error.message}`));
      }
    });
  },

  /**
   * Set tooltip text
   * @param {string} tooltip - Tooltip text
   * @returns {Promise<void>}
   */
  async setTooltip(tooltip) {
    if (typeof tooltip !== 'string') {
      throw new TypeError('Tooltip must be a string');
    }

    return new Promise((resolve, reject) => {
      try {
        window.webkit.messageHandlers.craft.postMessage({
          type: 'tray',
          action: 'setTooltip',
          data: tooltip
        });
        resolve();
      } catch (error) {
        reject(new Error(`Failed to set tray tooltip: ${error.message}`));
      }
    });
  },

  /**
   * Register a click handler for tray icon
   * @param {Function} callback - Called when tray icon is clicked
   * @returns {Function} Unregister function
   */
  onClick(callback) {
    if (typeof callback !== 'function') {
      throw new TypeError('Callback must be a function');
    }

    const handler = (event) => {
      callback({
        button: event.detail?.button || 'left',
        timestamp: event.detail?.timestamp || Date.now(),
        modifiers: event.detail?.modifiers || {}
      });
    };

    // Store handler for cleanup
    if (!window.__craft_tray_handlers) {
      window.__craft_tray_handlers = [];
    }
    window.__craft_tray_handlers.push(handler);

    // Listen for native events
    window.addEventListener('craft:tray:click', handler);

    // Return unregister function
    return () => {
      const index = window.__craft_tray_handlers.indexOf(handler);
      if (index > -1) {
        window.__craft_tray_handlers.splice(index, 1);
      }
      window.removeEventListener('craft:tray:click', handler);
    };
  },

  /**
   * Convenience method: toggle window visibility on click
   */
  onClickToggleWindow() {
    return this.onClick(() => {
      window.craft.window.toggle();
    });
  },

  /**
   * Set the context menu for the tray icon
   * @param {Array<MenuItem>} items - Menu items
   * @example
   * window.craft.tray.setMenu([
   *   { label: 'Show Window', action: 'show' },
   *   { type: 'separator' },
   *   { label: 'Quit', action: 'quit' }
   * ])
   */
  async setMenu(items) {
    if (!Array.isArray(items)) {
      throw new TypeError('Menu items must be an array');
    }

    // Validate and transform items
    const menuData = items.map((item, index) => {
      if (item.type === 'separator') {
        return { type: 'separator', id: `sep_${index}` };
      }

      if (!item.label) {
        throw new Error(`Menu item at index ${index} missing label`);
      }

      return {
        id: item.id || `item_${index}`,
        label: item.label,
        type: item.type || 'normal',
        checked: item.checked || false,
        enabled: item.enabled !== false,
        action: item.action || null,
        shortcut: item.shortcut || null,
        submenu: item.submenu || null,
      };
    });

    return new Promise((resolve, reject) => {
      try {
        window.webkit.messageHandlers.craft.postMessage({
          type: 'tray',
          action: 'setMenu',
          data: JSON.stringify(menuData)
        });
        resolve();
      } catch (error) {
        reject(new Error(`Failed to set tray menu: ${error.message}`));
      }
    });
  },

  /**
   * Handle menu item clicks
   * @private
   */
  _handleMenuAction(actionId) {
    // Check for built-in actions
    switch (actionId) {
      case 'show':
        window.craft.window.show();
        break;
      case 'hide':
        window.craft.window.hide();
        break;
      case 'toggle':
        window.craft.window.toggle();
        break;
      case 'quit':
        window.craft.app.quit();
        break;
      default:
        // Dispatch custom event for app to handle
        window.dispatchEvent(new CustomEvent('craft:tray:menu', {
          detail: { action: actionId }
        }));
    }
  }
};

// Listen for menu actions from native
window.addEventListener('craft:tray:menuAction', (event) => {
  window.craft.tray._handleMenuAction(event.detail.action);
});

// Global function that native code can call to deliver pending actions
window.__craftDeliverAction = function(action) {
  if (action && action.length > 0) {
    console.log('[Craft] Received polled action:', action);
    window.dispatchEvent(new CustomEvent('craft:tray:menuAction', {
      detail: { action: action }
    }));
  }
};

// Poll for pending menu actions from native code
// This is needed because evaluateJavaScript doesn't work from menu callbacks
setInterval(() => {
  try {
    // Send a poll request to native code
    // Native will call window.__craftDeliverAction(action) if there's a pending action
    window.webkit.messageHandlers.craft.postMessage({
      type: 'tray',
      action: 'pollActions',
      data: ''
    });
  } catch (error) {
    // Ignore polling errors
  }
}, 100); // Poll every 100ms

console.log('[Craft] System tray API loaded');
