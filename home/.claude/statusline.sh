#!/usr/bin/env bash
#
# Claude Code statusline. Reads the session JSON on stdin, prints one line.
#
# Deliberately not `set -e`: this renders on every turn, and a hard exit paints
# an empty statusline with no hint as to why. Missing fields degrade to blank
# segments instead.
set -u

input=$(cat)

# One jq pass, not one per field. This runs on every render, so process spawns
# are the only cost here that scales with how often you look at it.
# Unit separator, not tab: tab is an IFS *whitespace* character, so bash would
# collapse consecutive tabs and shift every field left of a missing one.
IFS=$'\037' read -r model effort pct cache cost dir < <(
  jq -r '
    [ (.model.display_name // .model.id // "?"),
      (.effort.level // ""),
      ((.context_window.used_percentage // 0) | floor | tostring),

      # Share of the last request that was served from prompt cache. Invisible
      # otherwise, and it is the number that explains a surprising bill.
      ( .context_window.current_usage
        | if . == null then ""
          else (.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens) as $total
            | if $total == 0 then ""
              else (.cache_read_input_tokens * 100 / $total | round | tostring)
              end
          end ),

      ((.cost.total_cost_usd // 0) | tostring),
      (.workspace.current_dir // "")
    ] | join("\u001f")' <<<"$input"
)

# jq is the only thing that validates these; belt-and-braces so a schema change
# upstream degrades to a dull statusline rather than a printf error.
[[ $pct =~ ^[0-9]+$ ]] || pct=0
[[ $cache =~ ^[0-9]+$ ]] || cache=""
[[ $cost =~ ^[0-9.]+$ ]] || cost=0

# Month-to-date cost: sum of completed sessions from the log + current session.
monthly_total=""
monthly_log="${HOME}/.claude/session-costs.jsonl"
if [[ -s "$monthly_log" ]]; then
  month_prefix=$(date +%Y-%m)
  prev=$(jq -rs --arg m "$month_prefix" \
    '[.[] | select(.date | startswith($m)) | .cost] | add // 0' \
    "$monthly_log" 2>/dev/null)
  if [[ "$prev" =~ ^[0-9.]+$ ]]; then
    monthly_total=$(awk "BEGIN { printf \"%.2f\", $prev + $cost }")
  fi
fi

DIM=$'\033[2m' CYAN=$'\033[36m' GREEN=$'\033[32m' YELLOW=$'\033[33m' RED=$'\033[31m' ORANGE=$'\033[38;2;255;183;102m' RESET=$'\033[0m'

# Thresholds run opposite ways: high context is bad, high cache hit is good.
ramp_up() { if [ "$1" -ge 90 ]; then echo "$RED"; elif [ "$1" -ge 70 ]; then echo "$YELLOW"; else echo "$GREEN"; fi; }
ramp_down() { if [ "$1" -ge 80 ]; then echo "$GREEN"; elif [ "$1" -ge 50 ]; then echo "$YELLOW"; else echo "$RED"; fi; }

segments=("${CYAN}${model}${RESET}")
[ -n "$effort" ] && segments+=("${DIM}${effort}${RESET}")
segments+=("$(ramp_up "$pct")ctx ${pct}%${RESET}")
[ -n "$cache" ] && segments+=("$(ramp_down "$cache")cache ${cache}%${RESET}")
segments+=("${YELLOW}$(printf '$%.2f' "$cost")${RESET}")
if [ -n "$monthly_total" ]; then
  budget_file="${HOME}/.claude/.statusline.local"
  budget=$(grep -E '^MONTHLY_BUDGET=' "$budget_file" 2>/dev/null | cut -d= -f2 | tr -d '[:space:]')
  if [[ "$budget" =~ ^[0-9.]+$ ]]; then
    mtd_pct=$(awk "BEGIN { printf \"%d\", ($monthly_total / $budget) * 100 + 0.5 }")
    segments+=("${ORANGE}MTD ${mtd_pct}%${RESET}")
  else
    segments+=("${ORANGE}MTD $(printf '$%.2f' "$monthly_total")${RESET}")
  fi
fi
[ -n "$dir" ] && segments+=("${dir##*/}")

# Ask git about the workspace, not about wherever this script happened to run.
if [ -n "$dir" ] && branch=$(git -C "$dir" branch --show-current 2>/dev/null) && [ -n "$branch" ]; then
  segments+=("${GREEN}${branch}${RESET}")
fi

printf '%s' "${segments[0]}"
printf "${DIM} · ${RESET}%s" "${segments[@]:1}"
printf '\n'
