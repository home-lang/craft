/**
 * Augmentation / fallback for the `ts-maps` package's generated `.d.ts`.
 *
 * The upstream build (`bun-plugin-dtsx`) intermittently emits a few malformed
 * member signatures in the distribution (e.g. `closePopup?: ();` with a
 * missing return type annotation) that TypeScript rejects as *syntax*
 * errors (TS1005) — which `skipLibCheck` cannot suppress.
 *
 * This file is only a type-level safety net; it is not required at runtime
 * and does not override the package's real exports. When the upstream
 * generator is fixed this file can be deleted.
 */

// Intentionally empty runtime ambient — serves as a placeholder hook
// for future augmentation. The current workaround is a post-build patch
// to the few broken declaration lines; see the README for details.
export {}
