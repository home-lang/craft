// Craft Window Control JavaScript API
// This file provides window control functionality from JavaScript

window.craft = window.craft || {};

window.craft.window = {
  /**
   * Show the window
   */
  async show() {
    return new Promise((resolve, reject) => {
      try {
        window.webkit.messageHandlers.craft.postMessage({
          type: 'window',
          action: 'show'
        });
        resolve();
      } catch (error) {
        reject(new Error(`Failed to show window: ${error.message}`));
      }
    });
  },

  /**
   * Hide the window
   */
  async hide() {
    return new Promise((resolve, reject) => {
      try {
        window.webkit.messageHandlers.craft.postMessage({
          type: 'window',
          action: 'hide'
        });
        resolve();
      } catch (error) {
        reject(new Error(`Failed to hide window: ${error.message}`));
      }
    });
  },

  /**
   * Toggle window visibility
   */
  async toggle() {
    return new Promise((resolve, reject) => {
      try {
        window.webkit.messageHandlers.craft.postMessage({
          type: 'window',
          action: 'toggle'
        });
        resolve();
      } catch (error) {
        reject(new Error(`Failed to toggle window: ${error.message}`));
      }
    });
  },

  /**
   * Minimize the window
   */
  async minimize() {
    return new Promise((resolve, reject) => {
      try {
        window.webkit.messageHandlers.craft.postMessage({
          type: 'window',
          action: 'minimize'
        });
        resolve();
      } catch (error) {
        reject(new Error(`Failed to minimize window: ${error.message}`));
      }
    });
  },

  /**
   * Close the window
   */
  async close() {
    return new Promise((resolve, reject) => {
      try {
        window.webkit.messageHandlers.craft.postMessage({
          type: 'window',
          action: 'close'
        });
        resolve();
      } catch (error) {
        reject(new Error(`Failed to close window: ${error.message}`));
      }
    });
  }
};

console.log('[Craft] Window control API loaded');
