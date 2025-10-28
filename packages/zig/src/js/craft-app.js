// Craft App Control JavaScript API
// This file provides application-level control functionality

window.craft = window.craft || {};

window.craft.app = {
  /**
   * Hide the dock icon (menubar-only mode)
   * macOS only
   */
  async hideDockIcon() {
    return new Promise((resolve, reject) => {
      try {
        window.webkit.messageHandlers.craft.postMessage({
          type: 'app',
          action: 'hideDockIcon'
        });
        resolve();
      } catch (error) {
        reject(new Error(`Failed to hide dock icon: ${error.message}`));
      }
    });
  },

  /**
   * Show the dock icon (normal mode)
   * macOS only
   */
  async showDockIcon() {
    return new Promise((resolve, reject) => {
      try {
        window.webkit.messageHandlers.craft.postMessage({
          type: 'app',
          action: 'showDockIcon'
        });
        resolve();
      } catch (error) {
        reject(new Error(`Failed to show dock icon: ${error.message}`));
      }
    });
  },

  /**
   * Quit the application
   */
  async quit() {
    return new Promise((resolve, reject) => {
      try {
        window.webkit.messageHandlers.craft.postMessage({
          type: 'app',
          action: 'quit'
        });
        resolve();
      } catch (error) {
        reject(new Error(`Failed to quit: ${error.message}`));
      }
    });
  },

  /**
   * Get application information
   */
  async getInfo() {
    return new Promise((resolve, reject) => {
      try {
        window.webkit.messageHandlers.craft.postMessage({
          type: 'app',
          action: 'getInfo'
        });
        resolve();
      } catch (error) {
        reject(new Error(`Failed to get app info: ${error.message}`));
      }
    });
  }
};

console.log('[Craft] App control API loaded');
