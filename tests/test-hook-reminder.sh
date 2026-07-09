#!/usr/bin/env bash
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$REPO_ROOT/hooks/pst-voice-reminder"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

export XDG_CONFIG_HOME="$TMP/config"
export CLAUDE_PLUGIN_ROOT="$REPO_ROOT"
export PST_SESSION_ID="hook-session-1"
unset CLAUDE_CODE_SESSION_ID || true

fails=0
contains() { # contains <desc> <needle> <haystack>
  if [[ "$3" == *"$2"* ]]; then printf 'ok   - %s\n' "$1"
  else printf 'FAIL - %s\n     needle: [%s]\n     in:     [%s]\n' "$1" "$2" "$3"; fails=$((fails+1)); fi
}
is_empty() { # is_empty <desc> <value>
  if [[ -z "$2" ]]; then printf 'ok   - %s\n' "$1"
  else printf 'FAIL - %s (got: [%s])\n' "$1" "$2"; fails=$((fails+1)); fi
}
JSON='{"session_id":"hook-session-1","transcript_path":"/x"}'

# off -> no output
"$REPO_ROOT/bin/pst-voice" clear
is_empty "off emits nothing" "$(printf '%s' "$JSON" | "$HOOK")"

# always (terse)
"$REPO_ROOT/bin/pst-voice" set always
out="$(printf '%s' "$JSON" | "$HOOK")"
contains "terse mentions voice mode active" "voice mode" "$out"
contains "terse mentions end-of-turn summary" "end of this turn" "$out"

# always verbose
"$REPO_ROOT/bin/pst-voice" set always verbose
out="$(printf '%s' "$JSON" | "$HOOK")"
contains "verbose mentions narrate" "Narrate" "$out"
contains "verbose mentions opener" "opener" "$out"

# session id parsed from stdin JSON when env var absent
"$REPO_ROOT/bin/pst-voice" set always
out="$(unset PST_SESSION_ID; printf '%s' "$JSON" | "$HOOK")"
contains "session id read from stdin json" "voice mode" "$out"

"$REPO_ROOT/bin/pst-voice" clear
if [[ "$fails" -eq 0 ]]; then echo "ALL PASS"; else echo "$fails FAILED"; exit 1; fi
