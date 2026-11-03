#!/usr/bin/env bash
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TTS="$REPO_ROOT/bin/tts"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

export XDG_CONFIG_HOME="$TMP/config"
unset PST_TTS_MODEL PST_TTS_VOICE || true

fails=0
check() { if [[ "$2" == "$3" ]]; then printf 'ok   - %s\n' "$1"; else printf 'FAIL - %s expected [%s] got [%s]\n' "$1" "$2" "$3"; fails=$((fails+1)); fi; }
in_use() { "$TTS" --model-repos "$@" | awk '$1 == "*" { print $2 }'; }
voice_in_use() { "$TTS" --voices "$@" | awk '/Voice in use:/ { print $NF }'; }

check "default model" "kokoro" "$(in_use)"
check "default voice" "af_heart" "$(voice_in_use)"
check "--model wins" "pocket" "$(in_use --model pocket)"
check "env model" "voxtral" "$(PST_TTS_MODEL=voxtral in_use)"
check "--model beats env" "melo" "$(PST_TTS_MODEL=voxtral in_use --model melo)"
check "model default voice" "alba" "$(voice_in_use --model pocket)"
check "env voice" "javert" "$(PST_TTS_VOICE=javert voice_in_use --model pocket)"

"$TTS" --set-default-model qwen3-1.7b >/dev/null
check "saved default model" "qwen3-1.7b" "$(in_use)"
check "env beats saved model" "kokoro" "$(PST_TTS_MODEL=kokoro in_use)"

"$TTS" --set-default aiden >/dev/null
check "saved voice per model" "aiden" "$(voice_in_use)"
check "saved voice ignored by other model" "af_heart" "$(voice_in_use --model kokoro)"

check "unknown model fails" "1" "$("$TTS" --model nope hi >/dev/null 2>&1; echo $?)"
check "voice from other model fails" "1" "$("$TTS" --model pocket --voice af_heart hi >/dev/null 2>&1; echo $?)"
check "bad --set-default fails" "1" "$("$TTS" --model pocket --set-default af_heart >/dev/null 2>&1; echo $?)"
check "unknown flag fails" "1" "$("$TTS" --tempo 2 hi >/dev/null 2>&1; echo $?)"
check "say default voice" "Samantha" "$(voice_in_use --model say)"
check "say short voice name" "Eddy" "$(voice_in_use --model say --voice Eddy)"
check "say full voice name" "Eddy (English (US))" "$("$TTS" --model say --voice "Eddy (English (US))" --voices | sed -n 's/.*Voice in use: //p')"
check "say unknown voice fails" "1" "$("$TTS" --model say --voice Nope hi >/dev/null 2>&1; echo $?)"
check "model-repos lists every model" "11" "$("$TTS" --model-repos | wc -l | tr -d ' ')"
check "kokoro keeps its voice dep" "prince-canuma/Kokoro-82M" "$("$TTS" --model-repos | awk '$1 == "kokoro" { print $3 }')"

if [[ "$fails" -eq 0 ]]; then echo "ALL PASS"; else echo "$fails FAILED"; exit 1; fi
