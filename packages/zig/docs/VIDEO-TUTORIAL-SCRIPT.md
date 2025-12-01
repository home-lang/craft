# Craft Native UI - Video Tutorial Script

## Overview
**Duration:** ~10-15 minutes
**Target Audience:** Developers familiar with JavaScript who want to build native macOS apps
**Goal:** Demonstrate how to create a Finder-like file browser using Craft's native UI components

---

## Pre-Recording Checklist

- [ ] Clean desktop background
- [ ] Hide personal files/bookmarks
- [ ] Increase font size in terminal (14-16pt)
- [ ] Increase font size in code editor (14-16pt)
- [ ] Close unnecessary apps
- [ ] Turn off notifications
- [ ] Have example project ready

---

## Script

### INTRO (30 seconds)

```
[Show Craft logo or title card]

"Welcome to this tutorial on Craft's Native UI system.

Today we'll build a Finder-like file browser using truly native macOS
components - not HTML or CSS, but real AppKit views like NSOutlineView
and NSTableView.

By the end, you'll have a working app with:
- A sidebar with collapsible sections
- A file browser with sortable columns
- Keyboard shortcuts including spacebar for Quick Look
- And it all integrates seamlessly with JavaScript."
```

---

### SECTION 1: Project Setup (1-2 minutes)

```
[Show terminal]

"Let's start by creating a new Craft project. First, make sure you have
Zig installed - version 0.14 or later."

[Type command]
$ mkdir my-file-browser && cd my-file-browser

"Now let's create our HTML file. With Craft, your UI logic lives in
JavaScript, while the native components are rendered by Zig."

[Create index.html - show in editor]
```

**index.html to show:**
```html
<!DOCTYPE html>
<html>
<head>
  <title>My File Browser</title>
  <style>
    body {
      font-family: -apple-system, sans-serif;
      margin: 0;
      padding: 20px;
    }
  </style>
</head>
<body>
  <h1>Loading native UI...</h1>

  <script>
    // We'll add our code here
  </script>
</body>
</html>
```

---

### SECTION 2: Creating the Sidebar (2-3 minutes)

```
[Show code editor with index.html]

"The Native UI API is available through window.craft.nativeUI.
Let's wait for it to be ready, then create our sidebar."

[Type/show code]
```

**Code to demonstrate:**
```javascript
document.addEventListener('craft:nativeui:ready', () => {
  console.log('Native UI is ready!');

  // Create the sidebar
  const sidebar = craft.nativeUI.createSidebar({ id: 'main-sidebar' });

  // Add a Favorites section
  sidebar.addSection({
    id: 'favorites',
    header: 'Favorites',
    items: [
      { id: 'desktop', label: 'Desktop', icon: 'desktopcomputer' },
      { id: 'documents', label: 'Documents', icon: 'folder.fill' },
      { id: 'downloads', label: 'Downloads', icon: 'arrow.down.circle.fill' }
    ]
  });

  // Handle selection
  sidebar.onSelect((itemId) => {
    console.log('Selected:', itemId);
  });
});
```

```
[Run the app]

"When we run this, you'll see a native macOS sidebar appear.
Notice how it uses SF Symbols for icons - these are the same icons
you see in Finder and other Apple apps.

The sidebar automatically handles:
- Keyboard navigation with arrow keys
- Proper selection highlighting
- Collapsible section headers
- Dark mode support"

[Demonstrate clicking items, using arrow keys]
```

---

### SECTION 3: Creating the File Browser (2-3 minutes)

```
[Back to code editor]

"Now let's add a file browser. This creates an NSTableView with
four columns: Name, Date Modified, Size, and Kind."

[Add code]
```

**Code to demonstrate:**
```javascript
// Create the file browser
const browser = craft.nativeUI.createFileBrowser({ id: 'main-browser' });

// Add some files
browser.addFiles([
  {
    id: 'file1',
    name: 'README.md',
    icon: 'doc.text',
    dateModified: 'Today, 2:30 PM',
    size: '4 KB',
    kind: 'Markdown'
  },
  {
    id: 'file2',
    name: 'screenshot.png',
    icon: 'photo',
    dateModified: 'Yesterday',
    size: '1.2 MB',
    kind: 'PNG Image'
  },
  {
    id: 'file3',
    name: 'project',
    icon: 'folder.fill',
    dateModified: 'Dec 1, 2024',
    size: '--',
    kind: 'Folder'
  }
]);

// Handle selection
browser.onSelect((fileId) => {
  console.log('File selected:', fileId);
});

// Handle double-click
browser.onDoubleClick((fileId) => {
  console.log('Opening file:', fileId);
});
```

```
[Run the app]

"Now we have a file browser with proper columns. You can:
- Click column headers to sort
- Resize columns by dragging
- Use arrow keys to navigate
- Double-click to open files

This is a real NSTableView, so it performs great even with
thousands of files."

[Demonstrate sorting, resizing columns]
```

---

### SECTION 4: Combining with Split View (1-2 minutes)

```
[Back to code editor]

"Let's combine these into a split view layout, just like Finder."

[Add code]
```

**Code to demonstrate:**
```javascript
// Create split view combining sidebar and browser
const splitView = craft.nativeUI.createSplitView({
  id: 'main-split',
  sidebar: sidebar,
  browser: browser
});

// The split view automatically:
// - Sets minimum widths (180px sidebar, 400px content)
// - Makes the divider draggable
// - Saves divider position between sessions
```

```
[Run the app]

"Now we have a proper Finder-like layout. The divider between
sidebar and content is draggable, and the positions are
automatically saved."

[Demonstrate dragging divider]
```

---

### SECTION 5: Quick Look with Spacebar (1-2 minutes)

```
[Back to code editor]

"One of the best features of Finder is Quick Look - press spacebar
to preview any file. Let's add that."

[Add code]
```

**Code to demonstrate:**
```javascript
// Enable Quick Look on spacebar
browser.setOnSpacebarCallback(() => {
  const selectedFile = getSelectedFile(); // Your function

  if (selectedFile) {
    craft.nativeUI.toggleQuickLook({
      files: [{
        id: selectedFile.id,
        path: selectedFile.fullPath,
        title: selectedFile.name
      }]
    });
  }
});
```

```
[Run the app with real files]

"Now when you select a file and press spacebar, Quick Look opens
with a preview. This works with images, PDFs, videos, text files -
anything macOS can preview.

Press spacebar again to close it."

[Demonstrate Quick Look with different file types]
```

---

### SECTION 6: Context Menus (1-2 minutes)

```
[Back to code editor]

"Let's add right-click context menus for common file operations."

[Add code]
```

**Code to demonstrate:**
```javascript
// Right-click on files
browser.onContextMenu((menuItemId, fileId) => {
  switch(menuItemId) {
    case 'open':
      openFile(fileId);
      break;
    case 'get_info':
      showInfo(fileId);
      break;
    case 'move_to_trash':
      moveToTrash(fileId);
      break;
  }
});

// Show context menu (typically from a right-click handler)
browser.showContextMenu({
  fileId: 'file1',
  x: event.clientX,
  y: event.clientY,
  items: [
    { id: 'open', title: 'Open', icon: 'arrow.up.forward.square' },
    { id: 'get_info', title: 'Get Info', icon: 'info.circle' },
    { type: 'separator' },
    { id: 'move_to_trash', title: 'Move to Trash', icon: 'trash' }
  ]
});
```

```
[Run the app]

"Right-clicking now shows a native context menu with SF Symbol icons.
These are real NSMenu items, so they support keyboard shortcuts and
behave exactly like system menus."

[Demonstrate right-click menu]
```

---

### SECTION 7: Performance Demo (1 minute)

```
[Show performance test]

"Let's see how this performs with a lot of files."

[Run performance test example]
```

```javascript
// Add 10,000 files
const files = [];
for (let i = 0; i < 10000; i++) {
  files.push({
    id: `file-${i}`,
    name: `Document ${i}.txt`,
    icon: 'doc.text',
    size: `${Math.floor(Math.random() * 100)} KB`
  });
}

console.time('Add 10,000 files');
browser.addFiles(files);
console.timeEnd('Add 10,000 files');
```

```
"Even with 10,000 files, the browser stays responsive. That's because
NSTableView only renders visible rows - it's truly virtualized at
the native level.

Scrolling is smooth at 60fps because we're not fighting against
DOM rendering."

[Scroll through 10,000 files smoothly]
```

---

### SECTION 8: Wrap Up (30 seconds)

```
[Show completed app]

"That's the Craft Native UI system. In just a few minutes, we built
a Finder-like app with:

- Native sidebar with SF Symbol icons
- File browser with sortable columns
- Quick Look preview with spacebar
- Context menus
- Smooth performance with 10,000+ files

All from JavaScript, but rendered with real AppKit components.

Check out the documentation for more examples, including drag and drop,
custom themes, and advanced patterns.

Thanks for watching!"

[Show documentation URL or GitHub link]
```

---

## B-Roll Suggestions

Capture these clips to insert during editing:

1. **Finder comparison** - Show real Finder next to your app
2. **Dark mode** - Toggle system dark mode, show app adapts
3. **Keyboard navigation** - Close-up of arrow keys being pressed
4. **Quick Look** - Preview cycling through multiple file types
5. **Performance** - Activity Monitor showing low CPU during scroll
6. **Code completion** - If your editor supports it, show autocomplete

---

## Common Mistakes to Avoid

1. Don't forget `craft:nativeui:ready` event - API isn't available immediately
2. Don't show paths with personal info in Quick Look demos
3. Don't use copyrighted files in demos
4. Test all code before recording to avoid debugging on camera

---

## Recording Tips

1. **Audio**: Use a good microphone, record in a quiet room
2. **Pacing**: Pause briefly after each concept
3. **Mistakes**: Keep going - minor mistakes can be edited out
4. **Screen**: Record at 1920x1080 for best YouTube quality
5. **Length**: Aim for 10-15 minutes total

---

## Post-Recording

- [ ] Edit out long pauses and mistakes
- [ ] Add chapter markers for YouTube
- [ ] Create thumbnail showing the finished app
- [ ] Write description with timestamps
- [ ] Add links to documentation and source code
