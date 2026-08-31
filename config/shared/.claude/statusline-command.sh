#!/bin/bash
# Status line derived from ~/.bashrc PS1:
#   '${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
# Extended to also show: current git branch, and context-window usage as a
# small bar graph plus a numeric percentage.

input=$(cat)

user=$(whoami)
host=$(hostname -s)

dir=$(echo "$input" | jq -r '.workspace.current_dir // empty' 2>/dev/null)
[ -z "$dir" ] && dir=$(pwd)
dir_display="${dir/#$HOME/\~}"

# --- git branch (degrades silently if not in a repo / git missing) ---
branch=""
if command -v git >/dev/null 2>&1; then
  branch=$(GIT_OPTIONAL_LOCKS=0 git -C "$dir" branch --show-current 2>/dev/null)
  if [ -z "$branch" ]; then
    short_sha=$(GIT_OPTIONAL_LOCKS=0 git -C "$dir" rev-parse --short HEAD 2>/dev/null)
    [ -n "$short_sha" ] && branch="detached:${short_sha}"
  fi
fi

# --- current model ---
model_name=$(echo "$input" | jq -r '.model.display_name // empty' 2>/dev/null)

# --- open PR for the current branch ---
# Fast path: Claude Code already resolves this (mirrors the footer PR badge)
# and hands it to us for free in the payload, no shelling out required.
pr_number=$(echo "$input" | jq -r '.pr.number // empty' 2>/dev/null)

# Fallback path: only used when the fast-path field above is absent. Looks up
# the PR via `gh`, but NEVER blocks the render on a cold/slow network call.
# Result is cached on disk (keyed by repo+branch, few-minute TTL) and a stale
# or missing cache just means "no PR shown this render" while a detached
# background job refreshes the cache for next time. Degrades silently (no
# output, no error) if: `gh` isn't installed, we're not in a git repo, there
# is no GitHub remote, `gh` isn't authenticated, or there's no open PR.
if [ -z "$pr_number" ] && [ -n "$branch" ] && command -v gh >/dev/null 2>&1; then
  repo_owner=$(echo "$input" | jq -r '.workspace.repo.owner // empty' 2>/dev/null)
  repo_name=$(echo "$input" | jq -r '.workspace.repo.name // empty' 2>/dev/null)
  if [ -n "$repo_owner" ] && [ -n "$repo_name" ]; then
    repo_slug="${repo_owner}/${repo_name}"
  else
    origin_url=$(GIT_OPTIONAL_LOCKS=0 git -C "$dir" config --get remote.origin.url 2>/dev/null)
    repo_slug=$(echo "$origin_url" | sed -E 's#.*[:/]([^/]+/[^/]+)(\.git)?$#\1#' 2>/dev/null)
    repo_slug="${repo_slug%.git}"
  fi

  if [ -n "$repo_slug" ]; then
    repo_id=$(echo "$repo_slug" | tr '/' '_')
    safe_branch=$(echo "$branch" | tr -c 'A-Za-z0-9._-' '_')
    cache_dir="$HOME/.cache/claude-statusline/pr"
    mkdir -p "$cache_dir" 2>/dev/null
    cache_file="${cache_dir}/${repo_id}__${safe_branch}.cache"
    lock_file="${cache_dir}/${repo_id}__${safe_branch}.lock"
    ttl_seconds=300
    lock_stale_seconds=30

    now_epoch=$(date +%s 2>/dev/null)
    cache_mtime=0
    if [ -f "$cache_file" ]; then
      cache_mtime=$(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null)
      [ -z "$cache_mtime" ] && cache_mtime=0
    fi
    cache_age=$(( now_epoch - cache_mtime ))

    if [ -f "$cache_file" ] && [ "$cache_age" -lt "$ttl_seconds" ]; then
      cached_val=$(cat "$cache_file" 2>/dev/null)
      [ -n "$cached_val" ] && [ "$cached_val" != "none" ] && pr_number="$cached_val"
    else
      # Cache missing/expired: skip showing a PR this render (fast path,
      # never wait on the network) and refresh in the background, debounced
      # via a short-lived lock file so we don't fork a `gh` call on every
      # single re-render while the lookup is in flight.
      lock_age=999999
      if [ -f "$lock_file" ]; then
        lock_mtime=$(stat -c %Y "$lock_file" 2>/dev/null || stat -f %m "$lock_file" 2>/dev/null)
        [ -n "$lock_mtime" ] && lock_age=$(( now_epoch - lock_mtime ))
      fi
      if [ "$lock_age" -gt "$lock_stale_seconds" ]; then
        touch "$lock_file" 2>/dev/null
        (
          result=$(gh pr view "$branch" --repo "$repo_slug" --json number -q '.number' 2>/dev/null)
          [ -z "$result" ] && result="none"
          echo "$result" > "${cache_file}.tmp" 2>/dev/null && mv "${cache_file}.tmp" "$cache_file" 2>/dev/null
          rm -f "$lock_file" 2>/dev/null
        ) >/dev/null 2>&1 &
        disown 2>/dev/null
      fi
    fi
  fi
fi

# --- context window usage ---
# Prefer the pre-calculated percentage; fall back to computing it from raw
# token counts if that field is absent/null (e.g. before the first API call).
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty' 2>/dev/null)
if [ -z "$used_pct" ]; then
  total_input=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty' 2>/dev/null)
  ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // empty' 2>/dev/null)
  if [ -n "$total_input" ] && [ -n "$ctx_size" ] && [ "$ctx_size" != "0" ]; then
    used_pct=$(awk -v a="$total_input" -v b="$ctx_size" 'BEGIN{printf "%.2f", (a/b)*100}' 2>/dev/null)
  fi
fi

used_int=""
bar=""
if [ -n "$used_pct" ]; then
  used_int=$(awk -v p="$used_pct" 'BEGIN{v=int(p+0.5); if(v<0)v=0; if(v>100)v=100; print v}' 2>/dev/null)
fi

if [ -n "$used_int" ]; then
  bar_len=10
  filled=$(( used_int / (100 / bar_len) ))
  [ "$filled" -gt "$bar_len" ] && filled=$bar_len
  empty=$(( bar_len - filled ))
  i=0
  while [ "$i" -lt "$filled" ]; do bar="${bar}#"; i=$((i + 1)); done
  i=0
  while [ "$i" -lt "$empty" ]; do bar="${bar}-"; i=$((i + 1)); done

  # Color the bar/number by severity: green < 50%, yellow 50-79%, red >= 80%.
  if [ "$used_int" -ge 80 ]; then
    ctx_color='\033[00;31m'
  elif [ "$used_int" -ge 50 ]; then
    ctx_color='\033[00;33m'
  else
    ctx_color='\033[00;32m'
  fi
fi

printf '\033[01;32m%s@%s\033[00m:\033[01;34m%s\033[00m' "$user" "$host" "$dir_display"

if [ -n "$branch" ]; then
  printf ' \033[00;35m(%s)\033[00m' "$branch"
fi

if [ -n "$model_name" ]; then
  printf ' \033[00;36m[%s]\033[00m' "$model_name"
fi

if [ -n "$used_int" ]; then
  printf ' %b[%s] %s%%\033[00m' "$ctx_color" "$bar" "$used_int"
fi

if [ -n "$pr_number" ]; then
  printf ' \033[01;33mPR #%s\033[00m' "$pr_number"
fi
