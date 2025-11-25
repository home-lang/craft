# @craft/react

React bindings for the Craft framework. Provides hooks to access native functionality in your React applications.

## Installation

```bash
npm install @craft/react
# or
yarn add @craft/react
# or
pnpm add @craft/react
```

## Usage

### Core Hooks

#### useCraft

Access the Craft API:

```tsx
import { useCraft } from '@craft/react';

function App() {
  const { craft, isReady } = useCraft();

  if (!isReady) {
    return <div>Loading...</div>;
  }

  return <div>Craft is ready!</div>;
}
```

#### usePlatform

Get platform information:

```tsx
import { usePlatform } from '@craft/react';

function PlatformInfo() {
  const { platform, loading } = usePlatform();

  if (loading) return <div>Loading...</div>;

  return (
    <div>
      Platform: {platform?.platform}
      Version: {platform?.version}
    </div>
  );
}
```

#### useDeviceInfo

Get device information:

```tsx
import { useDeviceInfo } from '@craft/react';

function DeviceInfo() {
  const { deviceInfo } = useDeviceInfo();

  return (
    <div>
      Model: {deviceInfo?.model}
      OS: {deviceInfo?.os_version}
    </div>
  );
}
```

### UI Hooks

#### useToast

Show toast notifications:

```tsx
import { useToast } from '@craft/react';

function ToastExample() {
  const { showToast } = useToast();

  return (
    <button onClick={() => showToast('Hello!', 'short')}>
      Show Toast
    </button>
  );
}
```

#### useHaptic

Trigger haptic feedback:

```tsx
import { useHaptic } from '@craft/react';

function HapticButton() {
  const { haptic } = useHaptic();

  return (
    <button onClick={() => haptic('impact_medium')}>
      Tap Me
    </button>
  );
}
```

#### usePermission

Request permissions:

```tsx
import { usePermission } from '@craft/react';

function CameraPermission() {
  const { granted, request, loading } = usePermission('camera');

  return (
    <div>
      {granted === null && (
        <button onClick={request} disabled={loading}>
          Request Camera Access
        </button>
      )}
      {granted && <div>Camera access granted!</div>}
      {granted === false && <div>Camera access denied</div>}
    </div>
  );
}
```

### Window Management

#### useWindow

Manage the application window:

```tsx
import { useWindow } from '@craft/react';

function WindowControls() {
  const { maximize, minimize, toggleFullscreen, isFullscreen } = useWindow();

  return (
    <div>
      <button onClick={maximize}>Maximize</button>
      <button onClick={minimize}>Minimize</button>
      <button onClick={toggleFullscreen}>
        {isFullscreen ? 'Exit' : 'Enter'} Fullscreen
      </button>
    </div>
  );
}
```

### System Integration

#### useTray

Manage system tray icon:

```tsx
import { useTray } from '@craft/react';

function TrayManager() {
  const { create, setMenu } = useTray();

  useEffect(() => {
    create('/path/to/icon.png', 'My App');
    setMenu([
      { id: 'show', label: 'Show Window' },
      { id: 'quit', label: 'Quit', type: 'normal' },
    ]);
  }, []);

  return null;
}
```

#### useNotification

Send system notifications:

```tsx
import { useNotification } from '@craft/react';

function NotificationExample() {
  const { send } = useNotification();

  const notify = () => {
    send({
      title: 'Hello!',
      body: 'This is a notification',
    });
  };

  return <button onClick={notify}>Notify</button>;
}
```

### File System

#### useFileSystem

Interact with the file system:

```tsx
import { useFileSystem } from '@craft/react';

function FileEditor() {
  const { readFile, writeFile, loading, error } = useFileSystem();
  const [content, setContent] = useState('');

  const load = async () => {
    const data = await readFile('/path/to/file.txt');
    setContent(data);
  };

  const save = async () => {
    await writeFile('/path/to/file.txt', content);
  };

  return (
    <div>
      <textarea value={content} onChange={(e) => setContent(e.target.value)} />
      <button onClick={load}>Load</button>
      <button onClick={save}>Save</button>
      {loading && <div>Loading...</div>}
      {error && <div>Error: {error.message}</div>}
    </div>
  );
}
```

### Database

#### useDatabase

Work with SQLite databases:

```tsx
import { useDatabase } from '@craft/react';

function TodoList() {
  const { query, execute } = useDatabase('/path/to/db.sqlite');
  const [todos, setTodos] = useState([]);

  useEffect(() => {
    loadTodos();
  }, []);

  const loadTodos = async () => {
    const results = await query('SELECT * FROM todos');
    setTodos(results);
  };

  const addTodo = async (title: string) => {
    await execute('INSERT INTO todos (title) VALUES (?)', [title]);
    await loadTodos();
  };

  return (
    <ul>
      {todos.map((todo) => (
        <li key={todo.id}>{todo.title}</li>
      ))}
    </ul>
  );
}
```

### HTTP Requests

#### useHttp

Make HTTP requests:

```tsx
import { useHttp } from '@craft/react';

function ApiExample() {
  const { fetch, loading } = useHttp();
  const [data, setData] = useState(null);

  const loadData = async () => {
    const result = await fetch('https://api.example.com/data');
    setData(result);
  };

  return (
    <div>
      <button onClick={loadData} disabled={loading}>
        Load Data
      </button>
      {data && <pre>{JSON.stringify(data, null, 2)}</pre>}
    </div>
  );
}
```

### Event Handling

#### useCraftEvent

Listen to Craft events:

```tsx
import { useCraftEvent } from '@craft/react';

function EventListener() {
  useCraftEvent('app.ready', () => {
    console.log('App is ready!');
  });

  useCraftEvent('window.close', () => {
    console.log('Window is closing');
  });

  return <div>Listening to events...</div>;
}
```

### Utility Hooks

#### useIsMobile

Check if running on mobile:

```tsx
import { useIsMobile } from '@craft/react';

function ResponsiveComponent() {
  const isMobile = useIsMobile();

  return <div>{isMobile ? 'Mobile View' : 'Desktop View'}</div>;
}
```

#### useIsDesktop

Check if running on desktop:

```tsx
import { useIsDesktop } from '@craft/react';

function DesktopOnly() {
  const isDesktop = useIsDesktop();

  if (!isDesktop) return null;

  return <div>Desktop-only features</div>;
}
```

## API Reference

See the [TypeScript definitions](./dist/index.d.ts) for complete API documentation.

## License

MIT
