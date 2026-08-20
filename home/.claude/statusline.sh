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
IFS=$'\037' read -r model effort pct cache cost dir session_id dur_ms < <(
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
      (.workspace.current_dir // ""),
      (.session_id // ""),

      # Wall clock since the session began, idle time included. Verified
      # against the first transcript timestamp, not assumed from the name.
      ((.cost.total_duration_ms // 0) | floor | tostring)
    ] | join("\u001f")' <<<"$input"
)

# jq is the only thing that validates these; belt-and-braces so a schema change
# upstream degrades to a dull statusline rather than a printf error.
[[ $pct =~ ^[0-9]+$ ]] || pct=0
[[ $cache =~ ^[0-9]+$ ]] || cache=""
[[ $cost =~ ^[0-9.]+$ ]] || cost=0
[[ $dur_ms =~ ^[0-9]+$ ]] || dur_ms=0

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

# Compact durations: 45s, 12m, 2h14m. Assigns into $FMT_DUR rather than echoing
# because the statusline repaints every 10-45s even while idle, so a command
# substitution here would fork twice a minute for the life of the session.
FMT_DUR=""
fmt_dur() {
  if   [ "$1" -lt 60 ];   then printf -v FMT_DUR '%ds' "$1"
  elif [ "$1" -lt 3600 ]; then printf -v FMT_DUR '%dm' $(( $1 / 60 ))
  else printf -v FMT_DUR '%dh%dm' $(( $1 / 3600 )) $(( $1 % 3600 / 60 ))
  fi
}

# Live gap since the Stop hook last fired. Blank on a session's first turn,
# when no stamp exists yet.
since_turn=""
stamp_file="${HOME}/.claude/turn-end/${session_id}"
if [ -n "$session_id" ] && [ -r "$stamp_file" ] && read -r last_end < "$stamp_file" \
   && [[ $last_end =~ ^[0-9]+$ ]]; then
  elapsed=$(( $(date +%s) - last_end ))
  # A clock change can put the stamp in the future; show nothing over a lie.
  if [ "$elapsed" -ge 0 ]; then
    fmt_dur "$elapsed"
    since_turn="$FMT_DUR"
  fi
fi

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
fmt_dur $(( dur_ms / 1000 ))
segments+=("${DIM}${FMT_DUR}${RESET}")
[ -n "$since_turn" ] && segments+=("${DIM}+${since_turn}${RESET}")
[ -n "$dir" ] && segments+=("${dir##*/}")

# Ask git about the workspace, not about wherever this script happened to run.
if [ -n "$dir" ] && branch=$(git -C "$dir" branch --show-current 2>/dev/null) && [ -n "$branch" ]; then
  segments+=("${GREEN}${branch}${RESET}")
fi

printf '%s' "${segments[0]}"
printf "${DIM} · ${RESET}%s" "${segments[@]:1}"
printf '\n'
