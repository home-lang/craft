#!/usr/bin/env bash

# Source this file to make Craft's pantry-managed toolchain available:
#
#   source scripts/pantry-env.sh
#   craft_pantry_use
#
# The resolver intentionally works from subdirectories. It prefers a shared
# pantry checkout/cache, then falls back to this repository's local pantry dir.

craft_repo_root() {
  if [ -n "${CRAFT_ROOT:-}" ] && [ -d "$CRAFT_ROOT" ]; then
    printf '%s\n' "$CRAFT_ROOT"
    return 0
  fi

  local git_root
  if git_root="$(git rev-parse --show-toplevel 2>/dev/null)" && [ -d "$git_root" ]; then
    printf '%s\n' "$git_root"
    return 0
  fi

  local script_dir source_path
  source_path="${BASH_SOURCE[0]:-$0}"
  script_dir="$(cd "$(dirname "$source_path")" && pwd)"
  (cd "$script_dir/.." && pwd)
}

craft_pantry_candidate_roots() {
  local repo_root parent
  repo_root="$(craft_repo_root)"
  parent="$(dirname "$repo_root")"

  local candidates=()

  if [ -n "${CRAFT_PANTRY_ROOT:-}" ]; then
    candidates+=("$CRAFT_PANTRY_ROOT")
  fi

  if [ -n "${PANTRY_ROOT:-}" ]; then
    candidates+=("$PANTRY_ROOT")
  fi

  candidates+=(
    "$HOME/Code/Tools/pantry/pantry"
    "$parent/pantry/pantry"
    "$repo_root/pantry"
    "$HOME/Code/Tools/pantry"
    "$parent/pantry"
  )

  printf '%s\n' "${candidates[@]}"
}

craft_pantry_root() {
  local candidate
  while IFS= read -r candidate; do
    [ -n "$candidate" ] || continue
    if [ -d "$candidate" ]; then
      printf '%s\n' "$(cd "$candidate" && pwd)"
      return 0
    fi
  done < <(craft_pantry_candidate_roots)

  printf 'Unable to find pantry dependencies. Run `pantry install`, or set CRAFT_PANTRY_ROOT.\n' >&2
  return 1
}

craft_pantry_package_dir() {
  if [ "$#" -ne 1 ]; then
    printf 'usage: craft_pantry_package_dir <package>/<version>\n' >&2
    return 2
  fi

  local candidate package_dir
  while IFS= read -r candidate; do
    [ -n "$candidate" ] || continue
    package_dir="$candidate/$1"
    if [ -d "$package_dir" ]; then
      printf '%s\n' "$(cd "$package_dir" && pwd)"
      return 0
    fi
  done < <(craft_pantry_candidate_roots)

  while IFS= read -r candidate; do
    [ -n "$candidate" ] || continue
    for package_dir in "$candidate/$1"*; do
      [ -d "$package_dir" ] || continue
      printf '%s\n' "$(cd "$package_dir" && pwd)"
      return 0
    done
  done < <(craft_pantry_candidate_roots)

  printf 'Missing pantry package: %s\n' "$1" >&2
  printf 'Run `pantry install`, or set CRAFT_PANTRY_ROOT to the dependency cache.\n' >&2
  return 1
}

craft_pantry_use() {
  local pantry_root
  pantry_root="$(craft_pantry_root)" || return 1

  local path_parts=()
  local package package_dir

  if [ "$#" -eq 0 ]; then
    set -- "ziglang.org/v0.17.0-dev"
  fi

  for package in "$@"; do
    package_dir="$(craft_pantry_package_dir "$package")"
    path_parts+=("$package_dir")
    if [ -d "$package_dir/bin" ]; then
      path_parts+=("$package_dir/bin")
    fi
  done

  path_parts+=("$pantry_root/.bin")

  local joined
  joined="$(IFS=:; printf '%s' "${path_parts[*]}")"

  export CRAFT_PANTRY_ROOT="$pantry_root"
  export PATH="$joined:$PATH"
}
