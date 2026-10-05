#!/usr/bin/env bash
# Claude Code statusline: model, cwd, repo, branch, session name, context usage bar, 5h/7d rate limit bars
input=$(cat)

# Colors (terminal-safe; DIM only for separators)
DIM='\033[2m'
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
MAGENTA='\033[35m'
BLUE='\033[34m'
RED='\033[31m'
RESET='\033[0m'

model=$(echo "$input" | jq -r '.model.display_name // empty')

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
cwd_display=$(basename "$cwd" 2>/dev/null)

repo=$(echo "$input" | jq -r '.workspace.repo | if . then .owner + "/" + .name else empty end')

session_name=$(echo "$input" | jq -r '.session_name // empty')

used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
five_hour_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
seven_day_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

# Branch name: prefer worktree branch, else ask git directly (skip optional locks)
branch=$(echo "$input" | jq -r '.worktree.branch // empty')
if [ -z "$branch" ] && [ -n "$cwd" ]; then
  branch=$(git --no-optional-locks -C "$cwd" branch --show-current 2>/dev/null)
fi

parts=()

if [ -n "$model" ]; then
  parts+=("$(printf "${BLUE}%s${RESET}" "$model")")
fi

parts+=("$(printf "${CYAN}%s${RESET}" "$cwd_display")")

if [ -n "$repo" ]; then
  parts+=("$(printf "${MAGENTA}%s${RESET}" "$repo")")
fi

if [ -n "$branch" ]; then
  parts+=("$(printf "${GREEN}%s${RESET}" "$branch")")
fi

if [ -n "$session_name" ]; then
  parts+=("$(printf "${YELLOW}%s${RESET}" "$session_name")")
fi

# Render a 10-char progress bar like "[###-------] 30%", colored by fullness:
# green < 50%, yellow < 80%, red >= 80%
make_bar() {
  local pct=$1 bar_width=10 filled empty bar="" i color
  color=$(awk -v p="$pct" -v g="$GREEN" -v y="$YELLOW" -v r="$RED" 'BEGIN { print (p < 50 ? g : (p < 80 ? y : r)) }')
  filled=$(awk -v p="$pct" -v w="$bar_width" 'BEGIN { f = int((p / 100) * w + 0.5); if (f > w) f = w; print f }')
  empty=$((bar_width - filled))
  for ((i = 0; i < filled; i++)); do bar="${bar}#"; done
  for ((i = 0; i < empty; i++)); do bar="${bar}-"; done
  printf "${color}[%s] %.0f%%${RESET}" "$bar" "$pct"
}

if [ -n "$used_pct" ]; then
  parts+=("$(printf "%s" "$(make_bar "$used_pct")")")
fi

if [ -n "$five_hour_pct" ]; then
  parts+=("5h $(make_bar "$five_hour_pct")")
fi

if [ -n "$seven_day_pct" ]; then
  parts+=("7d $(make_bar "$seven_day_pct")")
fi

IFS=' | '
out=""
for i in "${!parts[@]}"; do
  if [ "$i" -eq 0 ]; then
    out="${parts[$i]}"
  else
    out="${out} ${DIM}|${RESET} ${parts[$i]}"
  fi
done

printf "%b\n" "$out"
