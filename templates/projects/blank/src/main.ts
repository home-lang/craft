/**
 * {{APP_NAME}} - Built with Craft
 */

import { getPlatform, isDesktop, isMobile } from '@craft-native/craft'

// Initialize app
function init() {
  const app = document.getElementById('app')!

  app.innerHTML = `
    <div style="display: flex; flex-direction: column; align-items: center; justify-content: center; min-height: 100vh; padding: 2rem;">
      <h1 style="font-size: 2.5rem; margin-bottom: 1rem;">{{APP_NAME}}</h1>
      <p style="opacity: 0.7; margin-bottom: 2rem;">Built with Craft</p>
      <p style="font-size: 0.875rem; opacity: 0.5;">Running on ${getPlatform()}</p>
    </div>
  `
}

// Start app
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', init)
} else {
  init()
}
