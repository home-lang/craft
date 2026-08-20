# GitHub Actions

This folder contains the following GitHub Actions:

- [CI][CI] - all CI jobs for the project
  - lints the code
  - `typecheck`s the code
  - runs test suite
  - runs on `ubuntu-latest`
- [Release][Release] - automates the release process & changelog generation

[CI]: ./workflows/ci.yml
[Release]: ./workflows/release.yml

## Pinned actions

`pantry-pm/pantry/packages/action` is pinned to a commit, not to `@main`.

`@main` means an unrelated push to another repository decides whether every
job here runs, and on 2026-08-20 that happened twice in one night: first the
action stopped shipping its built `dist/index.js`, so every job failed at step
one with `File not found`; then, after that was fixed upstream, the setup step
began hanging — every job on both Linux and macOS sat on **Setup Pantry** until
GitHub killed it at the six-hour ceiling.

The pin is `ef37fca8440cdb483fb355fefa5ae3cc6e669a69` (pantry 0.11.36), the
revision the last fully green run on `main` used.

To bump it: change the SHA everywhere it appears under `.github/workflows/`,
in one commit, and let CI prove the new revision before it lands. The same
reasoning applies to the first-party Zig dependencies — see
[`.github/actions/first-party-zig-deps/pins.env`](../actions/first-party-zig-deps/pins.env).

