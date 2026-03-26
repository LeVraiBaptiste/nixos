#!/usr/bin/env bash
# Claude Code statusline script
# Reads JSON from stdin, outputs a colored two-line status bar

set -euo pipefail

# Read JSON from stdin
json=$(cat)

# Colors
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
CYAN='\033[36m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

# Helper: color by threshold (green < 50, yellow < 80, red >= 80)
color_by_pct() {
  local pct=$1
  if (( pct >= 80 )); then
    printf '%b' "$RED"
  elif (( pct >= 50 )); then
    printf '%b' "$YELLOW"
  else
    printf '%b' "$GREEN"
  fi
}

# Helper: build a progress bar
progress_bar() {
  local pct=${1:-0}
  local width=15
  local filled=$(( pct * width / 100 ))
  local empty=$(( width - filled ))
  local bar=""
  for ((i = 0; i < filled; i++)); do bar+="█"; done
  for ((i = 0; i < empty; i++)); do bar+="░"; done
  printf '%b' "$(color_by_pct "$pct")${bar}${RESET}"
}

# Helper: format milliseconds to human-readable duration
format_duration() {
  local ms=${1:-0}
  local total_secs=$(( ms / 1000 ))
  local hrs=$(( total_secs / 3600 ))
  local mins=$(( (total_secs % 3600) / 60 ))
  local secs=$(( total_secs % 60 ))
  if (( hrs > 0 )); then
    printf '%dh%02dm' "$hrs" "$mins"
  elif (( mins > 0 )); then
    printf '%dm%02ds' "$mins" "$secs"
  else
    printf '%ds' "$secs"
  fi
}

# Extract fields via jq
model=$(echo "$json" | jq -r '.model.display_name // "Unknown"')
ctx_pct=$(echo "$json" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
cost=$(echo "$json" | jq -r '.cost.total_cost_usd // 0')
duration_ms=$(echo "$json" | jq -r '.cost.total_duration_ms // 0' | cut -d. -f1)

# Git info (cached to avoid slowness)
cache_file="/tmp/claude-statusline-git-cache"
cache_max_age=10
git_info=""

if command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
  now=$(date +%s)
  if [[ -f "$cache_file" ]] && (( now - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0) < cache_max_age )); then
    git_info=$(cat "$cache_file")
  else
    branch=$(git branch --show-current 2>/dev/null || echo "detached")
    staged=$(git diff --cached --numstat 2>/dev/null | wc -l)
    modified=$(git diff --numstat 2>/dev/null | wc -l)
    untracked=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l)

    git_status=""
    (( staged > 0 )) && git_status+=" +${staged}"
    (( modified > 0 )) && git_status+=" ~${modified}"
    (( untracked > 0 )) && git_status+=" ?${untracked}"

    git_info="${branch}${git_status}"
    echo "$git_info" > "$cache_file"
  fi
fi

# Rate limits (may not be present)
rl_5h=$(echo "$json" | jq -r '.rate_limits.five_hour.used_percentage // empty' 2>/dev/null)
rl_7d=$(echo "$json" | jq -r '.rate_limits.seven_day.used_percentage // empty' 2>/dev/null)

# --- Line 1: Model | Context bar | Cost | Duration ---
line1=""
line1+="${BOLD}${CYAN}${model}${RESET}"
line1+="${DIM} | ${RESET}"
line1+="$(progress_bar "$ctx_pct") ${ctx_pct}%"
line1+="${DIM} | ${RESET}"
line1+="${GREEN}\$$(printf '%.2f' "$cost")${RESET}"
line1+="${DIM} | ${RESET}"
line1+="${DIM}$(format_duration "$duration_ms")${RESET}"

printf '%b\n' "$line1"

# --- Line 2: Git info | Rate limits ---
line2=""
if [[ -n "$git_info" ]]; then
  line2+="${BLUE} ${git_info}${RESET}"
fi

if [[ -n "$rl_5h" || -n "$rl_7d" ]]; then
  [[ -n "$line2" ]] && line2+="${DIM} | ${RESET}"
  if [[ -n "$rl_5h" ]]; then
    rl_5h_int=${rl_5h%.*}
    line2+="$(color_by_pct "$rl_5h_int")5h:${rl_5h_int}%${RESET}"
  fi
  if [[ -n "$rl_7d" ]]; then
    rl_7d_int=${rl_7d%.*}
    [[ -n "$rl_5h" ]] && line2+=" "
    line2+="$(color_by_pct "$rl_7d_int")7d:${rl_7d_int}%${RESET}"
  fi
fi

if [[ -n "$line2" ]]; then
  printf '%b\n' "$line2"
fi
