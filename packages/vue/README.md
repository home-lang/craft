# @craft/vue

Vue 3 Composition API bindings for the Craft framework.

## Installation

```bash
npm install @craft/vue
# or
yarn add @craft/vue
# or
pnpm add @craft/vue
```

## Usage

### Core Composables

#### useCraft

```vue
<script setup>
import { useCraft } from '@craft/vue';

const { craft, isReady } = useCraft();
</script>

<template>
  <div v-if="isReady">Craft is ready!</div>
</template>
```

#### usePlatform

```vue
<script setup>
import { usePlatform } from '@craft/vue';

const { platform, loading } = usePlatform();
</script>

<template>
  <div v-if="!loading">
    <p>Platform: {{ platform?.platform }}</p>
    <p>Version: {{ platform?.version }}</p>
  </div>
</template>
```

#### useToast

```vue
<script setup>
import { useToast } from '@craft/vue';

const { showToast } = useToast();

const handleClick = () => {
  showToast('Hello from Vue!', 'short');
};
</script>

<template>
  <button @click="handleClick">Show Toast</button>
</template>
```

### Window Management

```vue
<script setup>
import { useWindow } from '@craft/vue';

const { maximize, minimize, toggleFullscreen, isFullscreen } = useWindow();
</script>

<template>
  <div>
    <button @click="maximize">Maximize</button>
    <button @click="minimize">Minimize</button>
    <button @click="toggleFullscreen">
      {{ isFullscreen ? 'Exit' : 'Enter' }} Fullscreen
    </button>
  </div>
</template>
```

### File System

```vue
<script setup>
import { ref } from 'vue';
import { useFileSystem } from '@craft/vue';

const { readFile, writeFile, loading } = useFileSystem();
const content = ref('');

const load = async () => {
  content.value = await readFile('/path/to/file.txt');
};

const save = async () => {
  await writeFile('/path/to/file.txt', content.value);
};
</script>

<template>
  <div>
    <textarea v-model="content" />
    <button @click="load">Load</button>
    <button @click="save">Save</button>
    <div v-if="loading">Loading...</div>
  </div>
</template>
```

### Database

```vue
<script setup>
import { ref, onMounted } from 'vue';
import { useDatabase } from '@craft/vue';

const { query, execute } = useDatabase('/path/to/db.sqlite');
const todos = ref([]);

onMounted(async () => {
  todos.value = await query('SELECT * FROM todos');
});

const addTodo = async (title) => {
  await execute('INSERT INTO todos (title) VALUES (?)', [title]);
  todos.value = await query('SELECT * FROM todos');
};
</script>

<template>
  <ul>
    <li v-for="todo in todos" :key="todo.id">{{ todo.title }}</li>
  </ul>
</template>
```

### HTTP Requests

```vue
<script setup>
import { ref } from 'vue';
import { useHttp } from '@craft/vue';

const { fetch: httpFetch, loading } = useHttp();
const data = ref(null);

const loadData = async () => {
  data.value = await httpFetch('https://api.example.com/data');
};
</script>

<template>
  <div>
    <button @click="loadData" :disabled="loading">Load Data</button>
    <pre v-if="data">{{ JSON.stringify(data, null, 2) }}</pre>
  </div>
</template>
```

### Events

```vue
<script setup>
import { useCraftEvent } from '@craft/vue';

useCraftEvent('app.ready', () => {
  console.log('App is ready!');
});

useCraftEvent('window.close', () => {
  console.log('Window is closing');
});
</script>
```

### Utilities

```vue
<script setup>
import { useIsMobile, useIsDesktop } from '@craft/vue';

const isMobile = useIsMobile();
const isDesktop = useIsDesktop();
</script>

<template>
  <div>
    <div v-if="isMobile">Mobile View</div>
    <div v-if="isDesktop">Desktop View</div>
  </div>
</template>
```

## API Reference

All composables are built using Vue 3's Composition API. They return reactive refs and can be used in any Vue 3 component.

See the [TypeScript definitions](./dist/index.d.ts) for complete API documentation.

## License

MIT
