#!/usr/bin/env bash
# Tests for bin/pst-voice. Runs against a temp XDG_CONFIG_HOME + fake session id.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$REPO_ROOT/bin/pst-voice"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export XDG_CONFIG_HOME="$TMP/config"
export PST_SESSION_ID="test-session-123"
unset CLAUDE_CODE_SESSION_ID || true

STATE_FILE="$XDG_CONFIG_HOME/pst/voice/test-session-123"
fails=0
check() { # check <description> <expected> <actual>
  if [[ "$2" == "$3" ]]; then
    printf 'ok   - %s\n' "$1"
  else
    printf 'FAIL - %s\n     expected: [%s]\n     actual:   [%s]\n' "$1" "$2" "$3"
    fails=$((fails + 1))
  fi
}

# get on absent file -> empty
check "get when off is empty" "" "$("$BIN" get)"
# status on absent file -> off
check "status when off is 'off'" "off" "$("$BIN" status)"

# set always
"$BIN" set always
check "state file exists after set" "yes" "$([[ -f "$STATE_FILE" ]] && echo yes || echo no)"
check "get returns 'always'" "always" "$("$BIN" get)"
check "status returns 'always'" "always" "$("$BIN" status)"

# set always verbose (overwrite)
"$BIN" set always verbose
check "get returns 'always verbose'" "always verbose" "$("$BIN" get)"

# clear
"$BIN" clear
check "state file gone after clear" "no" "$([[ -f "$STATE_FILE" ]] && echo yes || echo no)"
check "get empty after clear" "" "$("$BIN" get)"
check "clear again is a no-op (exit 0)" "0" "$("$BIN" clear >/dev/null 2>&1; echo $?)"

# no session id -> set fails, get empty
( unset PST_SESSION_ID; "$BIN" set always >/dev/null 2>&1 )
check "set with no session id exits non-zero" "1" "$(unset PST_SESSION_ID; "$BIN" set always >/dev/null 2>&1; echo $?)"
check "get with no session id is empty" "" "$(unset PST_SESSION_ID; "$BIN" get)"

if [[ "$fails" -eq 0 ]]; then echo "ALL PASS"; else echo "$fails FAILED"; exit 1; fi
