# @craft/svelte

Svelte bindings for the Craft framework using stores and actions.

## Installation

```bash
npm install @craft/svelte
```

## Usage

### Stores

```svelte
<script>
  import { craft, isReady, platform } from '@craft/svelte';
</script>

{#if $isReady}
  <p>Platform: {$platform?.platform}</p>
{/if}
```

### Window Management

```svelte
<script>
  import { windowActions, isFullscreen } from '@craft/svelte';
</script>

<button on:click={windowActions.maximize}>Maximize</button>
<button on:click={windowActions.toggleFullscreen}>
  {$isFullscreen ? 'Exit' : 'Enter'} Fullscreen
</button>
```

### Haptic Action

```svelte
<script>
  import { haptic } from '@craft/svelte';
</script>

<button use:haptic={'impact_medium'}>Tap Me</button>
```

### Toast

```svelte
<script>
  import { showToast } from '@craft/svelte';
</script>

<button on:click={() => showToast('Hello!')}>Show Toast</button>
```

### File System

```svelte
<script>
  import { filesystem } from '@craft/svelte';

  let content = '';

  async function load() {
    content = await filesystem.readFile('/path/to/file.txt');
  }

  async function save() {
    await filesystem.writeFile('/path/to/file.txt', content);
  }
</script>

<textarea bind:value={content} />
<button on:click={load}>Load</button>
<button on:click={save}>Save</button>
```

### Database

```svelte
<script>
  import { onMount } from 'svelte';
  import { createDatabase } from '@craft/svelte';

  const db = createDatabase('/path/to/db.sqlite');
  let todos = [];

  onMount(async () => {
    todos = await db.query('SELECT * FROM todos');
  });
</script>

<ul>
  {#each todos as todo}
    <li>{todo.title}</li>
  {/each}
</ul>
```

### HTTP

```svelte
<script>
  import { http } from '@craft/svelte';

  let data = null;

  async function loadData() {
    data = await http.fetch('https://api.example.com/data');
  }
</script>

<button on:click={loadData}>Load Data</button>
{#if data}
  <pre>{JSON.stringify(data, null, 2)}</pre>
{/if}
```

## License

MIT
