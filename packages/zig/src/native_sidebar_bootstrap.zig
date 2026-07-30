pub const script =
    \\window.__craftNativeSidebar = true;
    \\window.__craftCustomWindowControls = true;
    \\window.__craftWebChromeControls = true;
    \\window.__craftSidebarWidth = window.__craftSidebarWidth || 286;
    \\window.craft = window.craft || {};
    \\window.craft._sidebarSelectHandler = window.craft._sidebarSelectHandler || function(event) {
    \\  console.log('[Craft] Sidebar navigation:', event);
    \\};
    \\(function() {
    \\  function markNativeSidebar() {
    \\    document.documentElement.classList.add('has-native-sidebar', 'has-custom-window-controls');
    \\    document.documentElement.setAttribute('data-craft-native-sidebar', 'true');
    \\    document.documentElement.style.background = 'transparent';
    \\    if (document.body) {
    \\      document.body.dataset.nativeSidebar = 'true';
    \\      document.body.dataset.customWindowControls = 'true';
    \\    }
    \\  }
    \\  markNativeSidebar();
    \\  document.addEventListener('DOMContentLoaded', markNativeSidebar);
    \\  window.dispatchEvent(new Event('craft:ready'));
    \\})();
;
