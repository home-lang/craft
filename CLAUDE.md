# Claude Code Guidelines

## About

A lightweight, high-performance cross-platform application framework built with Zig. It creates native desktop apps (macOS, Linux, Windows), mobile apps (iOS, Android), and menubar/system tray apps using web technologies, with a ~297KB binary and ~168ms startup time. It includes 35 native UI components, advanced GPU rendering (Vulkan/Metal/Direct3D), WebSocket support, a JavaScript bridge, system integration (notifications, clipboard, file dialogs), and a TypeScript SDK (`ts-craft`) for building apps without writing Zig directly.

## Linting

- Use **pickier** for linting — never use eslint directly
- Run `bunx --bun pickier .` to lint, `bunx --bun pickier . --fix` to auto-fix
- When fixing unused variable warnings, prefer `// eslint-disable-next-line` comments over prefixing with `_`

## Frontend

- Use **stx** for templating — never write vanilla JS (`var`, `document.*`, `window.*`) in stx templates
- Use **crosswind** as the default CSS framework which enables standard Tailwind-like utility classes
- stx `<script>` tags should only contain stx-compatible code (signals, composables, directives)

## Dependencies

- **buddy-bot** handles dependency updates — not renovatebot
- **better-dx** provides shared dev tooling as peer dependencies — do not install its peers (e.g., `typescript`, `pickier`, `bun-plugin-dtsx`) separately if `better-dx` is already in `package.json`
- If `better-dx` is in `package.json`, ensure `bunfig.toml` includes `linker = "hoisted"`

## Commits

- Use conventional commit messages (e.g., `fix:`, `feat:`, `chore:`)
