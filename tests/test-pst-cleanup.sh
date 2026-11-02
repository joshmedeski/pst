#!/usr/bin/env bash
# Tests for bin/pst-cleanup. Runs against a temp XDG_CONFIG_HOME and fake HF cache.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$REPO_ROOT/bin/pst-cleanup"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export XDG_CONFIG_HOME="$TMP/config"
export HF_HUB_CACHE="$TMP/hub"
unset PST_CLONE_MODEL HF_HOME || true

fails=0
check() { # check <description> <expected> <actual>
  if [[ "$2" == "$3" ]]; then
    printf 'ok   - %s\n' "$1"
  else
    printf 'FAIL - %s\n     expected: [%s]\n     actual:   [%s]\n' "$1" "$2" "$3"
    fails=$((fails + 1))
  fi
}

fake() { for r in "$@"; do mkdir -p "$HF_HUB_CACHE/models--${r//\//--}/blobs"; done; }
present() { [[ -d "$HF_HUB_CACHE/models--${1//\//--}" ]] && echo yes || echo no; }

fake mlx-community/Kokoro-82M-4bit prince-canuma/Kokoro-82M mlx-community/Kokoro-82M-bf16 \
  mlx-community/VoxCPM2-bf16 mlx-community/Qwen3-TTS-12Hz-1.7B-Base-bf16 \
  mlx-community/MOSS-TTS-Nano-100M OpenMOSS-Team/MOSS-Audio-Tokenizer-Nano \
  someone/unrelated-model

echo n | "$BIN" >/dev/null
check "declining the prompt removes nothing" "yes" "$(present mlx-community/Qwen3-TTS-12Hz-1.7B-Base-bf16)"
"$BIN" </dev/null >/dev/null
check "no input and no --yes removes nothing" "yes" "$(present mlx-community/Qwen3-TTS-12Hz-1.7B-Base-bf16)"
check "lists kept models" "1" "$("$BIN" </dev/null | grep -c 'keep    mlx-community/VoxCPM2-bf16')"
check "lists models to delete" "1" "$("$BIN" </dev/null | grep -c 'delete  mlx-community/Qwen3-TTS')"

PST_CLONE_MODEL=moss-nano "$BIN" --yes >/dev/null
check "keeps in-use clone model" "yes" "$(present mlx-community/MOSS-TTS-Nano-100M)"
check "keeps in-use clone model's deps" "yes" "$(present OpenMOSS-Team/MOSS-Audio-Tokenizer-Nano)"
check "removes unused clone model (voxcpm2)" "no" "$(present mlx-community/VoxCPM2-bf16)"
check "removes unused clone model (qwen3)" "no" "$(present mlx-community/Qwen3-TTS-12Hz-1.7B-Base-bf16)"
check "keeps tts Kokoro model" "yes" "$(present mlx-community/Kokoro-82M-4bit)"
check "keeps Kokoro dep" "yes" "$(present prince-canuma/Kokoro-82M)"
check "removes tts-compare Kokoro variant" "no" "$(present mlx-community/Kokoro-82M-bf16)"
check "never touches non-pst models" "yes" "$(present someone/unrelated-model)"

check "rejects unknown options" "1" "$("$BIN" --bogus >/dev/null 2>&1; echo $?)"

"$REPO_ROOT/bin/tts-clone" --set-default-model voxcpm2 >/dev/null
"$BIN" --yes >/dev/null
check "saved default drives cleanup (moss deps removed)" "no" "$(present OpenMOSS-Team/MOSS-Audio-Tokenizer-Nano)"
check "nothing left to remove reports cleanly" "Nothing to remove." "$("$BIN" --yes | tail -1)"

if [[ "$fails" -eq 0 ]]; then echo "ALL PASS"; else echo "$fails FAILED"; exit 1; fi
