# Native UI Examples

## Example 1: Simple Sidebar

Basic sidebar with two sections.

```javascript
document.addEventListener('craft:nativeui:ready', () => {
    const sidebar = window.craft.nativeUI.createSidebar({ id: 'main' });

    sidebar.addSection({
        id: 'favorites',
        header: 'FAVORITES',
        items: [
            { id: 'home', label: 'Home', icon: 'house' },
            { id: 'docs', label: 'Documents', icon: 'folder' }
        ]
    });

    sidebar.addSection({
        id: 'tags',
        header: 'TAGS',
        items: [
            { id: 'work', label: 'Work', icon: 'circle.fill' },
            { id: 'personal', label: 'Personal', icon: 'circle.fill' }
        ]
    });

    sidebar.onSelect((id) => {
        document.getElementById('content').textContent = `Selected: ${id}`;
    });
});
```

---

## Example 2: File Browser with Selection

File browser with selection and double-click handling.

```javascript
const browser = window.craft.nativeUI.createFileBrowser({ id: 'files' });

// Add some files
browser.addFiles([
    {
        id: '1',
        name: 'Project Proposal.pdf',
        icon: 'doc.richtext',
        dateModified: 'Today',
        size: '2.4 MB',
        kind: 'PDF Document'
    },
    {
        id: '2',
        name: 'Budget.xlsx',
        icon: 'tablecells',
        dateModified: 'Yesterday',
        size: '156 KB',
        kind: 'Spreadsheet'
    },
    {
        id: '3',
        name: 'Photos',
        icon: 'folder.fill',
        dateModified: 'Dec 1',
        size: '--',
        kind: 'Folder'
    }
]);

// Handle selection
browser.onSelect((fileId) => {
    console.log('Selected:', fileId);
    showFileInfo(fileId);
});

// Handle double-click (open file)
browser.onDoubleClick((fileId) => {
    console.log('Opening:', fileId);
    openFile(fileId);
});
```

---

## Example 3: Finder-like Layout

Complete Finder-style interface with sidebar and file browser.

```javascript
function createFinderUI() {
    const { nativeUI } = window.craft;

    // Create sidebar
    const sidebar = nativeUI.createSidebar({ id: 'finder-sidebar' });

    // Favorites
    sidebar.addSection({
        id: 'favorites',
        header: 'FAVORITES',
        items: [
            { id: 'airdrop', label: 'AirDrop', icon: 'antenna.radiowaves.left.and.right' },
            { id: 'recents', label: 'Recents', icon: 'clock' },
            { id: 'applications', label: 'Applications', icon: 'square.grid.2x2' },
            { id: 'desktop', label: 'Desktop', icon: 'menubar.dock.rectangle' },
            { id: 'documents', label: 'Documents', icon: 'doc.on.doc' },
            { id: 'downloads', label: 'Downloads', icon: 'arrow.down.circle' }
        ]
    });

    // iCloud
    sidebar.addSection({
        id: 'icloud',
        header: 'ICLOUD',
        items: [
            { id: 'icloud-drive', label: 'iCloud Drive', icon: 'icloud' },
            { id: 'shared', label: 'Shared', icon: 'person.2' }
        ]
    });

    // Locations
    sidebar.addSection({
        id: 'locations',
        header: 'LOCATIONS',
        items: [
            { id: 'macbook', label: 'MacBook Pro', icon: 'laptopcomputer' },
            { id: 'network', label: 'Network', icon: 'network' }
        ]
    });

    // Create file browser
    const browser = nativeUI.createFileBrowser({ id: 'finder-browser' });

    // Connect sidebar selection to file loading
    sidebar.onSelect((locationId) => {
        loadFilesForLocation(locationId, browser);
    });

    // Handle file operations
    browser.onDoubleClick((fileId) => {
        const file = getFileById(fileId);
        if (file.kind === 'Folder') {
            navigateToFolder(file);
        } else {
            openFile(file);
        }
    });

    return { sidebar, browser };
}
```

---

## Example 4: Dynamic File Loading

Loading files from an API with progress indication.

```javascript
async function loadFilesFromAPI(folderId) {
    const browser = window.craft.nativeUI.createFileBrowser({ id: 'api-browser' });

    // Show loading state
    updateStatus('Loading...');

    try {
        // Fetch files from API
        const response = await fetch(`/api/files/${folderId}`);
        const files = await response.json();

        // Clear existing files
        browser.clearFiles();

        // Add files in batches for smooth loading
        const batchSize = 50;
        for (let i = 0; i < files.length; i += batchSize) {
            const batch = files.slice(i, i + batchSize).map(f => ({
                id: f.id,
                name: f.name,
                icon: getIconForType(f.type),
                dateModified: formatDate(f.modified),
                size: formatSize(f.size),
                kind: f.type
            }));

            browser.addFiles(batch);

            // Update progress
            updateStatus(`Loaded ${Math.min(i + batchSize, files.length)} of ${files.length}`);

            // Small delay for UI responsiveness
            await new Promise(r => setTimeout(r, 10));
        }

        updateStatus(`${files.length} items`);
    } catch (error) {
        updateStatus('Failed to load files');
        console.error(error);
    }
}

function getIconForType(type) {
    const icons = {
        'folder': 'folder.fill',
        'document': 'doc.text',
        'image': 'photo',
        'video': 'film',
        'audio': 'music.note',
        'archive': 'doc.zipper',
        'code': 'chevron.left.forwardslash.chevron.right'
    };
    return icons[type] || 'doc';
}
```

---

## Example 5: Notes App Sidebar

Sidebar for a notes application with notebooks and tags.

```javascript
function createNotesUI() {
    const sidebar = window.craft.nativeUI.createSidebar({ id: 'notes' });

    // Smart folders
    sidebar.addSection({
        id: 'smart',
        header: 'SMART FOLDERS',
        items: [
            { id: 'all', label: 'All Notes', icon: 'doc.text' },
            { id: 'recent', label: 'Recently Edited', icon: 'clock' },
            { id: 'shared', label: 'Shared with Me', icon: 'person.2' },
            { id: 'trash', label: 'Recently Deleted', icon: 'trash' }
        ]
    });

    // Notebooks
    sidebar.addSection({
        id: 'notebooks',
        header: 'NOTEBOOKS',
        items: [
            { id: 'work', label: 'Work', icon: 'book.closed' },
            { id: 'personal', label: 'Personal', icon: 'book.closed' },
            { id: 'ideas', label: 'Ideas', icon: 'lightbulb' },
            { id: 'journal', label: 'Journal', icon: 'book' }
        ]
    });

    // Tags
    sidebar.addSection({
        id: 'tags',
        header: 'TAGS',
        items: [
            { id: 'important', label: 'Important', icon: 'star.fill' },
            { id: 'todo', label: 'To-Do', icon: 'checklist' },
            { id: 'reference', label: 'Reference', icon: 'bookmark' }
        ]
    });

    sidebar.onSelect((id) => {
        loadNotesForFolder(id);
    });

    return sidebar;
}
```

---

## Example 6: Project Browser

File browser for a development project.

```javascript
function createProjectBrowser(projectPath) {
    const browser = window.craft.nativeUI.createFileBrowser({ id: 'project' });

    // Simulated project files
    const projectFiles = [
        { id: '1', name: 'package.json', icon: 'curlybraces', kind: 'JSON' },
        { id: '2', name: 'tsconfig.json', icon: 'curlybraces', kind: 'JSON' },
        { id: '3', name: 'README.md', icon: 'doc.text', kind: 'Markdown' },
        { id: '4', name: 'src/', icon: 'folder.fill', kind: 'Folder' },
        { id: '5', name: 'src/index.ts', icon: 'chevron.left.forwardslash.chevron.right', kind: 'TypeScript' },
        { id: '6', name: 'src/app.ts', icon: 'chevron.left.forwardslash.chevron.right', kind: 'TypeScript' },
        { id: '7', name: 'src/utils/', icon: 'folder.fill', kind: 'Folder' },
        { id: '8', name: 'tests/', icon: 'folder.fill', kind: 'Folder' },
        { id: '9', name: '.gitignore', icon: 'gearshape', kind: 'Config' },
        { id: '10', name: '.env', icon: 'lock.fill', kind: 'Environment' }
    ];

    browser.addFiles(projectFiles.map(f => ({
        ...f,
        dateModified: 'Today',
        size: f.kind === 'Folder' ? '--' : `${Math.floor(Math.random() * 100)} KB`
    })));

    browser.onDoubleClick((fileId) => {
        const file = projectFiles.find(f => f.id === fileId);
        if (file.kind === 'Folder') {
            // Navigate into folder
            navigateToFolder(file.name);
        } else {
            // Open in editor
            openInEditor(file.name);
        }
    });

    return browser;
}
```

---

## Example 7: Search Results

Displaying search results in file browser.

```javascript
async function searchFiles(query) {
    const browser = window.craft.nativeUI.createFileBrowser({ id: 'search' });

    browser.clearFiles();

    // Perform search
    const results = await performSearch(query);

    if (results.length === 0) {
        // Show empty state in your HTML
        showEmptyState(`No results for "${query}"`);
        return;
    }

    // Map search results to file browser format
    const files = results.map((result, index) => ({
        id: `result-${index}`,
        name: result.filename,
        icon: getIconForFile(result.filename),
        dateModified: result.lastModified,
        size: formatSize(result.size),
        kind: result.type
    }));

    browser.addFiles(files);
    showResultCount(results.length);

    browser.onSelect((id) => {
        const index = parseInt(id.replace('result-', ''));
        highlightResult(results[index]);
    });

    browser.onDoubleClick((id) => {
        const index = parseInt(id.replace('result-', ''));
        openResult(results[index]);
    });
}
```

---

## Example 8: Multi-Select with Shift/Cmd

Handling keyboard modifiers for multi-selection.

```javascript
// Note: Multi-select is handled natively by NSTableView
// The callbacks receive the currently focused item

let selectedFiles = new Set();

browser.onSelect((fileId) => {
    // For single selection mode
    selectedFiles.clear();
    selectedFiles.add(fileId);

    updateSelectionUI();
});

function updateSelectionUI() {
    document.getElementById('selection-count').textContent =
        `${selectedFiles.size} item${selectedFiles.size !== 1 ? 's' : ''} selected`;
}
```

---

## Example 9: Refresh on Focus

Refreshing file list when window gains focus.

```javascript
let browser;
let currentPath = '/';

function initFileBrowser() {
    browser = window.craft.nativeUI.createFileBrowser({ id: 'files' });
    loadFiles(currentPath);

    // Refresh when window gains focus
    window.addEventListener('focus', () => {
        refreshFiles();
    });
}

async function refreshFiles() {
    const files = await fetchFiles(currentPath);
    browser.clearFiles();
    browser.addFiles(files);
}
```

---

## Example 10: Drag and Drop Ready

Structure for when drag and drop is implemented.

```javascript
// Future API (not yet implemented)
browser.onDragStart((fileIds) => {
    console.log('Dragging:', fileIds);
});

browser.onDrop((fileIds, targetId, position) => {
    console.log('Dropped:', fileIds, 'onto:', targetId, 'at:', position);
    // Reorder or move files
});

sidebar.onDrop((items, sectionId) => {
    console.log('Dropped onto section:', sectionId);
    // Add items to section
});
```

---

## Complete HTML Template

```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>My Native App</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, sans-serif;
            margin: 0;
            padding: 0;
            /* Leave space for native sidebar */
            padding-left: 250px;
        }
        .content {
            padding: 20px;
        }
    </style>
</head>
<body>
    <div class="content">
        <h1>My App Content</h1>
        <p id="status">Loading...</p>
    </div>

    <script>
        function init() {
            if (!window.craft?.nativeUI) {
                setTimeout(init, 100);
                return;
            }

            const { nativeUI } = window.craft;

            // Create UI
            const sidebar = nativeUI.createSidebar({ id: 'main' });
            const browser = nativeUI.createFileBrowser({ id: 'files' });

            // Setup sidebar
            sidebar.addSection({
                id: 'nav',
                header: 'NAVIGATION',
                items: [
                    { id: 'home', label: 'Home', icon: 'house' },
                    { id: 'files', label: 'Files', icon: 'folder' }
                ]
            });

            // Handle events
            sidebar.onSelect((id) => {
                document.getElementById('status').textContent = `Selected: ${id}`;
            });

            document.getElementById('status').textContent = 'Ready!';
        }

        document.addEventListener('DOMContentLoaded', init);
    </script>
</body>
</html>
```
