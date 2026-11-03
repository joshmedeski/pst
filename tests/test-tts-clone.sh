#!/usr/bin/env bash
# Tests for bin/tts-clone model selection. Runs against a temp XDG_CONFIG_HOME.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$REPO_ROOT/bin/tts-clone"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export XDG_CONFIG_HOME="$TMP/config"
unset PST_CLONE_MODEL PST_CLONE_VOICE || true

fails=0
check() { # check <description> <expected> <actual>
  if [[ "$2" == "$3" ]]; then
    printf 'ok   - %s\n' "$1"
  else
    printf 'FAIL - %s\n     expected: [%s]\n     actual:   [%s]\n' "$1" "$2" "$3"
    fails=$((fails + 1))
  fi
}

in_use() { "$BIN" "$@" --models | awk '$1 == "*" { print $2 }'; }

check "built-in default is voxcpm2" "voxcpm2" "$(in_use)"
check "--models lists all three" "3" "$("$BIN" --models | wc -l | tr -d ' ')"

"$BIN" --set-default-model qwen3 >/dev/null
check "--set-default-model writes config" "qwen3" "$(cat "$XDG_CONFIG_HOME/pst/clone-model")"
check "saved default is used" "qwen3" "$(in_use)"
check "env overrides saved default" "moss-nano" "$(PST_CLONE_MODEL=moss-nano in_use)"
check "--model overrides env" "voxcpm2" "$(PST_CLONE_MODEL=moss-nano in_use --model voxcpm2)"

check "--set-default-model rejects unknown" "1" "$("$BIN" --set-default-model nope >/dev/null 2>&1; echo $?)"
check "unknown default left untouched" "qwen3" "$(cat "$XDG_CONFIG_HOME/pst/clone-model")"
check "--model rejects unknown before speaking" "1" "$("$BIN" --model nope "hi" >/dev/null 2>&1; echo $?)"

check "--design forces voxcpm2" "voxcpm2" "$(in_use --design calm)"
check "--design needs no installed voice" "tts-clone: no text provided." "$("$BIN" --design calm 2>&1 | head -1)"
check "--design with --voice still checks the voice" "tts-clone: no such voice 'ghost' (expected $XDG_CONFIG_HOME/pst/voices/ghost.wav)" "$("$BIN" --design calm --voice ghost hi 2>&1 | head -1)"

if [[ "$fails" -eq 0 ]]; then echo "ALL PASS"; else echo "$fails FAILED"; exit 1; fi
