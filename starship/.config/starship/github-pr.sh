#!/usr/bin/env bash
# Cached GitHub PR number for starship (per repo + branch, 10m TTL)

readonly TTL_MINUTES=10
readonly CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/starship/github-pr"

root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
branch=$(git branch --show-current 2>/dev/null) || exit 0
[[ -n "$branch" ]] || exit 0

mkdir -p "$CACHE_DIR"
key=$(printf '%s:%s' "$root" "$branch" | shasum -a 256 2>/dev/null | awk '{print $1}')
[[ -n "$key" ]] || exit 0
cache="$CACHE_DIR/$key"

if [[ -f "$cache" ]] && find "$cache" -mmin "-$TTL_MINUTES" -print -quit 2>/dev/null | grep -q .; then
  cat "$cache"
  exit 0
fi

number=$(gh pr view --json number -q .number 2>/dev/null || true)
printf '%s' "$number" >"$cache"
[[ -n "$number" ]] && printf '%s' "$number"
