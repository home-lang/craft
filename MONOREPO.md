# Zyte Monorepo Structure

This is a monorepo containing all Zyte packages and tools.

## Package Structure

```
zyte/
├── packages/
│   ├── ts-zyte/          # TypeScript SDK (zero dependencies)
│   ├── zig/              # Zig core (native implementation)
│   └── examples-ts/      # TypeScript examples
├── benchmarks/           # Performance benchmarks
├── package.json          # Workspace configuration
└── build.zig             # Root build wrapper
```

## Packages

### 1. `ts-zyte` - TypeScript SDK

**Location**: `packages/ts-zyte/`

The recommended way to build Zyte apps. Zero dependencies, just pure Node.js APIs.

```bash
bun add ts-zyte
```

See [ts-zyte README](./packages/ts-zyte/README.md) for documentation.

### 2. `zig` - Zig Core

**Location**: `packages/zig/`

The native Zig implementation that powers the TypeScript SDK.

**For advanced users only** - most developers should use `ts-zyte` instead.

See [zig README](./packages/zig/README.md) for documentation.

### 3. `examples-ts` - TypeScript Examples

**Location**: `packages/examples-ts/`

Example applications built with the TypeScript SDK:
- `minimal.ts` - Simplest possible app
- `hello-world.ts` - Modern styled app
- `todo-app.ts` - Interactive todo list

### 4. `benchmarks` - Performance Benchmarks

**Location**: `benchmarks/`

Comprehensive performance benchmarks comparing Zyte to Electron and Tauri.

See [benchmarks README](./benchmarks/README.md) for details.

## Development

### Install Dependencies

```bash
bun install
```

### Build Everything

```bash
# Build both Zig core and TypeScript SDK
bun run build

# Or build individually
bun run build:core  # Zig core
bun run build:sdk   # TypeScript SDK
```

### Run Tests

```bash
# Run all tests
bun run test       # Zig tests
bun run test:sdk   # TypeScript SDK tests
```

### Run Examples

```bash
# Zig examples
bun run run
bun run run:minimal

# TypeScript examples
cd packages/examples-ts
bun run minimal
bun run hello-world
bun run todo-app
```

### Development Workflow

1. **TypeScript SDK development**:
   ```bash
   cd packages/ts-zyte
   bun run dev  # Watch mode
   ```

2. **Zig core development**:
   ```bash
   cd packages/zig
   zig build  # Development build
   zig fmt src/ build.zig  # Format code
   zig build test  # Run tests
   ```

3. **Running benchmarks**:
   ```bash
   cd benchmarks
   bun run bench  # All benchmarks
   bun run bench:memory  # Memory benchmarks
   bun run bench:cpu  # CPU benchmarks
   ```

## Publishing

### Publish TypeScript SDK

```bash
bun run publish:sdk
```

This will:
1. Build the SDK
2. Publish to npm

### Versioning

All packages share the same version number defined in the root `package.json`.

To bump versions:
1. Update version in root `package.json`
2. Update version in `packages/ts-zyte/package.json`
3. Update version in `packages/zig/package.json`
4. Create a git tag: `git tag v0.0.2`
5. Push: `git push --tags`

## Workspace Commands

From the monorepo root:

| Command | Description |
|---------|-------------|
| `bun run build` | Build everything (core + SDK) |
| `bun run build:core` | Build Zig core only |
| `bun run build:sdk` | Build TypeScript SDK only |
| `bun run test` | Run Zig tests |
| `bun run test:sdk` | Run TypeScript SDK tests |
| `bun run clean` | Clean all build artifacts |
| `bun run fmt` | Format Zig code |
| `bun run dev` | SDK watch mode |

## Adding New Packages

To add a new package to the monorepo:

1. Create directory in `packages/`:
   ```bash
   mkdir packages/my-package
   ```

2. Create `package.json`:
   ```json
   {
     "name": "my-package",
     "version": "0.0.1",
     "private": true
   }
   ```

3. Add to workspace in root `package.json`:
   ```json
   "workspaces": [
     "packages/*",
     "benchmarks"
   ]
   ```

4. Install dependencies:
   ```bash
   bun install
   ```

## Best Practices

1. **Use workspace dependencies**: Reference packages using `workspace:*`
2. **Share tooling**: Use root-level dev dependencies when possible
3. **Consistent naming**: Follow `ts-*` for TypeScript packages
4. **Document changes**: Update package READMEs when APIs change
5. **Test before publish**: Always run tests before publishing

## Troubleshooting

### Binary not found

If you get "Zyte binary not found", build the core:
```bash
bun run build:core
```

### Workspace dependency issues

```bash
bun install --force
```

### Clean build

```bash
bun run clean
bun install
bun run build
```

## License

MIT © [Chris Breuer](https://github.com/chrisbbreuer)
