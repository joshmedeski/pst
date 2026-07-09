#!/usr/bin/env bash
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$REPO_ROOT/hooks/pst-voice-cleanup"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

export XDG_CONFIG_HOME="$TMP/config"
export CLAUDE_PLUGIN_ROOT="$REPO_ROOT"
export PST_SESSION_ID="cleanup-session-1"
unset CLAUDE_CODE_SESSION_ID || true

fails=0
check() { if [[ "$2" == "$3" ]]; then printf 'ok   - %s\n' "$1"; else printf 'FAIL - %s expected [%s] got [%s]\n' "$1" "$2" "$3"; fails=$((fails+1)); fi; }

"$REPO_ROOT/bin/pst-voice" set always verbose
check "state on before cleanup" "always verbose" "$("$REPO_ROOT/bin/pst-voice" get)"

printf '%s' '{"session_id":"cleanup-session-1","reason":"exit"}' | "$HOOK"
check "state cleared after cleanup" "" "$("$REPO_ROOT/bin/pst-voice" get)"
check "cleanup exits 0" "0" "$(printf '%s' '{"session_id":"cleanup-session-1"}' | "$HOOK"; echo $?)"

# hooks.json is valid JSON and references both hooks
check "hooks.json is valid json" "0" "$(python3 -c 'import json,sys;json.load(open(sys.argv[1]))' "$REPO_ROOT/hooks/hooks.json" >/dev/null 2>&1; echo $?)"
check "hooks.json names reminder hook" "yes" "$(grep -q pst-voice-reminder "$REPO_ROOT/hooks/hooks.json" && echo yes || echo no)"
check "hooks.json names cleanup hook" "yes" "$(grep -q pst-voice-cleanup "$REPO_ROOT/hooks/hooks.json" && echo yes || echo no)"

if [[ "$fails" -eq 0 ]]; then echo "ALL PASS"; else echo "$fails FAILED"; exit 1; fi
