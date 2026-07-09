# pst Voice Modes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add toggleable always-on and verbose (medium-narration) voice modes to the pst plugin, controlled through the existing `/pst:tts` command.

**Architecture:** A session-scoped state file records the active mode. A `bin/pst-voice` helper owns the file's path and read/write/clear operations. A plugin `UserPromptSubmit` hook reads that file each turn and injects a reminder into the agent's context (it never speaks — the agent still authors and plays all audio). A `SessionEnd` hook deletes the file so the mode is strictly session-only. The `/pst:tts` skill parses mode arguments and writes/clears the state via the helper.

**Tech Stack:** Bash (`set -euo pipefail`), Claude Code plugin hooks (`hooks/hooks.json`, `${CLAUDE_PLUGIN_ROOT}`), macOS. No new runtime dependencies. Tests are plain bash scripts (the repo has no test framework; stay dependency-light).

## Global Constraints

- Storage prefix: `${XDG_CONFIG_HOME:-$HOME/.config}/pst/` — honor the `$XDG_CONFIG_HOME` override, fall back to `~/.config`.
- State file path: `${XDG_CONFIG_HOME:-$HOME/.config}/pst/voice/<session-id>`.
- Session id source: `$CLAUDE_CODE_SESSION_ID` (a UUID). Helper also accepts a `$PST_SESSION_ID` override (used by hooks and tests); override wins when set.
- **Presence of the state file = always-mode ON.** Absence = OFF. Contents are space-separated tokens: `always` or `always verbose`.
- One-shot `verbose` (no `always`) writes NO state.
- Hooks must never block or crash a turn: on any error (missing session id, unreadable file) they exit 0 and emit nothing.
- All scripts start with `#!/usr/bin/env bash` and `set -euo pipefail`, and must be `chmod +x`.
- `tts` is always invoked with `run_in_background: true` and **no** trailing `&`.
- Pronunciation rules for spoken text: `id` → "eye-dee", `Nutiliti` → "newtility"; avoid file paths, code, markdown in spoken text.

---

### Task 1: `bin/pst-voice` state helper

**Files:**
- Create: `bin/pst-voice`
- Test: `tests/test-pst-voice.sh`

**Interfaces:**
- Produces: a CLI with subcommands
  - `pst-voice set <token...>` — write tokens to the state file (creating dirs).
  - `pst-voice get` — print the file's contents (trimmed) if present, else print nothing.
  - `pst-voice clear` — remove the state file (no error if absent).
  - `pst-voice status` — print tokens if present, else the literal `off`.
- Path resolution: `${XDG_CONFIG_HOME:-$HOME/.config}/pst/voice/<sid>` where `<sid>` is `${PST_SESSION_ID:-$CLAUDE_CODE_SESSION_ID}`. If no session id is resolvable: `set` exits 1 with a message; `get` prints nothing and exits 0; `clear` is a no-op exit 0; `status` prints `off`.

- [ ] **Step 1: Write the failing test**

Create `tests/test-pst-voice.sh`:

```bash
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `chmod +x tests/test-pst-voice.sh && bash tests/test-pst-voice.sh`
Expected: FAIL — `bin/pst-voice` does not exist yet (checks error / non-zero exit).

- [ ] **Step 3: Write minimal implementation**

Create `bin/pst-voice`:

```bash
#!/usr/bin/env bash
# pst-voice — read/write the session-scoped voice-mode state file.
#
# State file: ${XDG_CONFIG_HOME:-$HOME/.config}/pst/voice/<session-id>
#   Presence  = always-on voice mode is ON.
#   Contents  = space-separated tokens: "always" or "always verbose".
#
# Session id comes from $PST_SESSION_ID (override, used by hooks/tests) or
# $CLAUDE_CODE_SESSION_ID (set by Claude Code). Single source of truth for the
# path so the /pst:tts skill and the plugin hooks always agree.
set -euo pipefail

config_root() { printf '%s' "${XDG_CONFIG_HOME:-$HOME/.config}/pst/voice"; }
session_id()  { printf '%s' "${PST_SESSION_ID:-${CLAUDE_CODE_SESSION_ID:-}}"; }

state_file() {
  local sid; sid="$(session_id)"
  [[ -n "$sid" ]] || return 1
  printf '%s/%s' "$(config_root)" "$sid"
}

cmd="${1:-}"; shift || true

case "$cmd" in
  set)
    file="$(state_file)" || { echo "pst-voice: no session id (set \$CLAUDE_CODE_SESSION_ID)" >&2; exit 1; }
    mkdir -p "$(dirname "$file")"
    printf '%s\n' "$*" > "$file"
    ;;
  get)
    file="$(state_file)" 2>/dev/null || exit 0
    [[ -f "$file" ]] || exit 0
    # trim trailing newline/whitespace
    tr -d '\n' < "$file" | sed 's/[[:space:]]*$//'
    ;;
  status)
    file="$(state_file)" 2>/dev/null || { echo off; exit 0; }
    if [[ -f "$file" ]]; then tr -d '\n' < "$file" | sed 's/[[:space:]]*$//'; echo; else echo off; fi
    ;;
  clear)
    file="$(state_file)" 2>/dev/null || exit 0
    rm -f "$file"
    ;;
  *)
    echo "usage: pst-voice {set <tokens...>|get|status|clear}" >&2
    exit 2
    ;;
esac
```

- [ ] **Step 4: Run test to verify it passes**

Run: `chmod +x bin/pst-voice && bash tests/test-pst-voice.sh`
Expected: `ALL PASS`

- [ ] **Step 5: Commit**

```bash
git add bin/pst-voice tests/test-pst-voice.sh
git commit -m "feat: add pst-voice session-scoped state helper"
```

---

### Task 2: `UserPromptSubmit` reminder hook

**Files:**
- Create: `hooks/pst-voice-reminder`
- Test: `tests/test-hook-reminder.sh`

**Interfaces:**
- Consumes: `bin/pst-voice get` (Task 1), `$CLAUDE_PLUGIN_ROOT` (repo root when installed as a plugin).
- Behavior: reads the hook JSON from stdin; resolves session id (prefers `$CLAUDE_CODE_SESSION_ID`, else parses `"session_id"` out of the stdin JSON) and exports it as `PST_SESSION_ID`; runs `pst-voice get`; prints a reminder to stdout (which Claude Code injects into context) — verbose variant if the tokens contain `verbose`, terse variant for bare `always`, nothing when off. Always exits 0.

- [ ] **Step 1: Write the failing test**

Create `tests/test-hook-reminder.sh`:

```bash
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `chmod +x tests/test-hook-reminder.sh && bash tests/test-hook-reminder.sh`
Expected: FAIL — `hooks/pst-voice-reminder` does not exist yet.

- [ ] **Step 3: Write minimal implementation**

Create `hooks/pst-voice-reminder`:

```bash
#!/usr/bin/env bash
# UserPromptSubmit hook — if always-on voice mode is active for this session,
# inject a reminder telling the agent to speak this turn. Never speaks itself.
set -euo pipefail

input="$(cat)"  # drain + capture hook JSON from stdin

# Resolve session id: prefer the env var, else parse it out of the JSON.
sid="${CLAUDE_CODE_SESSION_ID:-}"
if [[ -z "$sid" ]]; then
  sid="$(printf '%s' "$input" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
fi
export PST_SESSION_ID="$sid"

helper="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}/bin/pst-voice"
state="$("$helper" get 2>/dev/null || true)"

[[ -n "$state" ]] || exit 0  # off -> emit nothing

if [[ "$state" == *verbose* ]]; then
  cat <<'EOF'
[pst voice] Always-on voice mode is ACTIVE (verbose). As you work this turn, speak brief narration aloud with the `tts` binary (run it with run_in_background:true and NO trailing &): a one-line spoken opener of your plan, a short spoken note at each significant decision or whenever you change approach, and a one-sentence spoken wrap-up at the end. Keep each utterance to one short, natural sentence. Avoid file paths, code, and markdown in spoken text; say "id" as "eye-dee" and "Nutiliti" as "newtility".
EOF
else
  cat <<'EOF'
[pst voice] Always-on voice mode is ACTIVE (terse). At the end of this turn, speak a concise one-to-three sentence spoken summary of what happened with the `tts` binary (run it with run_in_background:true and NO trailing &). Avoid file paths, code, and markdown in spoken text; say "id" as "eye-dee" and "Nutiliti" as "newtility".
EOF
fi
exit 0
```

- [ ] **Step 4: Run test to verify it passes**

Run: `chmod +x hooks/pst-voice-reminder && bash tests/test-hook-reminder.sh`
Expected: `ALL PASS`

- [ ] **Step 5: Commit**

```bash
git add hooks/pst-voice-reminder tests/test-hook-reminder.sh
git commit -m "feat: add UserPromptSubmit reminder hook for voice mode"
```

---

### Task 3: `SessionEnd` cleanup hook + hook registration

**Files:**
- Create: `hooks/pst-voice-cleanup`
- Create: `hooks/hooks.json`
- Test: `tests/test-hook-cleanup.sh`

**Interfaces:**
- Consumes: `bin/pst-voice clear` (Task 1), `$CLAUDE_PLUGIN_ROOT`.
- `hooks/pst-voice-cleanup`: resolves session id like the reminder hook, then runs `pst-voice clear`; always exits 0.
- `hooks/hooks.json`: registers `pst-voice-reminder` on `UserPromptSubmit` and `pst-voice-cleanup` on `SessionEnd`, both via `${CLAUDE_PLUGIN_ROOT}`.

- [ ] **Step 1: Write the failing test**

Create `tests/test-hook-cleanup.sh`:

```bash
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `chmod +x tests/test-hook-cleanup.sh && bash tests/test-hook-cleanup.sh`
Expected: FAIL — `hooks/pst-voice-cleanup` and `hooks/hooks.json` do not exist yet.

- [ ] **Step 3: Write minimal implementation**

Create `hooks/pst-voice-cleanup`:

```bash
#!/usr/bin/env bash
# SessionEnd hook — delete this session's voice-mode state so the mode is
# strictly session-only and never leaks into a future conversation.
set -euo pipefail

input="$(cat)"
sid="${CLAUDE_CODE_SESSION_ID:-}"
if [[ -z "$sid" ]]; then
  sid="$(printf '%s' "$input" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
fi
export PST_SESSION_ID="$sid"

helper="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}/bin/pst-voice"
"$helper" clear 2>/dev/null || true
exit 0
```

Create `hooks/hooks.json`:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/pst-voice-reminder"
          }
        ]
      }
    ],
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/pst-voice-cleanup"
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `chmod +x hooks/pst-voice-cleanup && bash tests/test-hook-cleanup.sh`
Expected: `ALL PASS`

- [ ] **Step 5: Verify the plugin loads the hooks (manual)**

Run (from a Claude Code session with the local plugin installed): `/reload-plugins`, then check `/hooks` lists a `UserPromptSubmit` and `SessionEnd` entry pointing at the pst scripts. If the hooks do not appear, confirm whether this Claude Code version auto-discovers `hooks/hooks.json` or requires a `"hooks": "./hooks/hooks.json"` key in `.claude-plugin/plugin.json`; add that key if needed and re-run.
Expected: both hooks listed.

- [ ] **Step 6: Commit**

```bash
git add hooks/pst-voice-cleanup hooks/hooks.json tests/test-hook-cleanup.sh
git commit -m "feat: add SessionEnd cleanup hook and register plugin hooks"
```

---

### Task 4: Update the `/pst:tts` skill to parse modes

**Files:**
- Modify: `skills/tts/SKILL.md`

**Interfaces:**
- Consumes: `pst-voice set`/`clear` (Task 1), the reminder text emitted by the hook (Task 2).
- Produces: documented behavior for `/pst:tts`, `/pst:tts verbose`, `/pst:tts always`, `/pst:tts always verbose`, `/pst:tts off`, and literal-text passthrough.

- [ ] **Step 1: Rewrite `skills/tts/SKILL.md`**

Replace the file's body (keep the `name`/`description` frontmatter, extending the description to mention modes) with:

```markdown
---
name: tts
description: Summarize conversation feedback and speak it aloud using the local tts binary (Kokoro TTS via mlx-audio), and control always-on / verbose voice modes. Use when the user runs "/pst:tts", says "read this back to me", "summarize and speak", "text to speech", wants an audio summary, or wants the assistant to keep speaking throughout the session. Trigger on any request to hear something spoken aloud.
---

# TTS - Text to Speech

Speak text aloud with the local `tts` binary, and manage two voice-mode dials:
**cadence** (on-demand vs. always) and **style** (terse vs. verbose narration).

## Argument parsing

Recognize these tokens in the arguments, in any order:

- `off` — turn always-mode off: run `pst-voice clear`, confirm, and stop.
- `always` — turn on always-mode. `always verbose` also turns on narration.
- `verbose` **without** `always` — narrate the CURRENT turn only (one-shot);
  write no state.
- No recognized token → treat the whole argument as literal text to speak
  (or, with no argument at all, summarize the recent conversation). This is the
  original behavior.

`pst-voice` is on the plugin's PATH. Set/clear state with:

```bash
pst-voice set always            # always, terse
pst-voice set always verbose    # always + narration
pst-voice clear                 # off
```

After `set`/`clear`, briefly confirm to the user which mode is active, then
behave accordingly for the rest of this turn.

## Speaking (all modes)

Run the summary or narration through `tts` in the background:

```bash
tts "Your spoken message here"
```

ALWAYS run `tts` via the Bash tool with `run_in_background: true` and **no**
trailing `&`. A trailing `&` is redundant, trips a command-safety prompt, and
fires the completion notification before the audio finishes playing.

## Cadence and style behavior

- **On-demand (default):** speak once when invoked, then stop.
- **always (terse):** at the end of each turn, speak a concise 1-3 sentence
  spoken summary of what happened.
- **always verbose / one-shot verbose (medium narration):** speak a one-line
  opener of the plan at the start, a short note at each significant decision or
  when you change approach, and a one-sentence wrap-up at the end.

While always-mode is on, a plugin hook injects a `[pst voice]` reminder into
your context at the start of each turn. Treat that reminder as the signal to
speak this turn per the active style. (You do not need to re-read state
yourself — the hook does it.)

## Guidelines

- Keep spoken text conversational and natural — it will be spoken aloud.
- Focus on actionable takeaways: what was decided, what changed, what to do next.
- Avoid technical syntax, file paths, code snippets, or markdown in spoken text.
- If the user provides literal text (e.g. `/pst:tts "custom message"`), speak
  that directly instead of summarizing.
- Escape any quotes or special shell characters before passing to the command.
- Say "id" as "eye-dee" (e.g. "click up id" → "click up eye-dee").
- Say "Nutiliti" as "newtility" (a play on "new utility", new-TIL-ih-tee).
- The `tts` binary streams audio live as it generates — nothing is saved to
  disk, so there is no file management.
```

- [ ] **Step 2: Verify manually (skill has no automated test)**

Run these and confirm each behaves as documented:
- `/pst:tts always verbose` → confirms mode on; `pst-voice get` returns `always verbose`.
- next turn → the `[pst voice]` reminder appears and audio narration plays.
- `/pst:tts off` → confirms off; `pst-voice get` returns empty.
- `/pst:tts "hello there"` → speaks the literal text, no state change.

Expected: all four behave as described.

- [ ] **Step 3: Commit**

```bash
git add skills/tts/SKILL.md
git commit -m "feat: parse always/verbose/off modes in the tts skill"
```

---

### Task 5: Document voice modes and bump version

**Files:**
- Modify: `README.md`
- Modify: `.claude-plugin/plugin.json`

**Interfaces:**
- Consumes: everything above. Documentation only.

- [ ] **Step 1: Add a "Voice modes" subsection to `README.md`**

Under the "Main feature: text-to-speech with mlx-audio" section (after the
`tts` usage block, before "Comparing model quality"), add:

```markdown
### Voice modes: always-on and verbose

`/pst:tts` takes optional mode arguments so the assistant can keep talking
throughout a session instead of only when asked:

| Command | What it does |
|---|---|
| `/pst:tts` | Summarize + speak once (default). |
| `/pst:tts verbose` | Narrate the current task aloud (one-shot). |
| `/pst:tts always` | Speak a short summary at the end of every turn. |
| `/pst:tts always verbose` | Continuous spoken companion — narrates as it works. |
| `/pst:tts off` | Turn always-mode off. |

Always-mode is **session-scoped**: it applies to the current conversation only
and is cleared automatically when the session ends. State lives in
`${XDG_CONFIG_HOME:-~/.config}/pst/voice/`. A `UserPromptSubmit` hook keeps the
mode active each turn (it never speaks — the assistant authors all audio), so
existing installs must run `/reload-plugins` once to pick up the hooks.
```

- [ ] **Step 2: Bump the plugin version**

In `.claude-plugin/plugin.json`, change `"version": "0.1.0"` to `"version": "0.2.0"`.

- [ ] **Step 3: Run the full test suite**

Run: `for t in tests/test-*.sh; do echo "== $t =="; bash "$t" || exit 1; done`
Expected: every script ends with `ALL PASS`.

- [ ] **Step 4: Commit**

```bash
git add README.md .claude-plugin/plugin.json
git commit -m "docs: document voice modes and bump plugin to 0.2.0"
```

---

## Notes for the implementer

- The repo had no test framework before this plan; the `tests/*.sh` scripts are
  self-contained and runnable with plain `bash`. Keep them dependency-free
  (only `python3` is used, and only to validate `hooks.json` — swap for a grep
  check if `python3` is unavailable).
- `bin/` and `hooks/` scripts must be executable (`chmod +x`) and committed with
  that bit set (`git update-index --chmod=+x <file>` if needed).
- Do not add a trailing `&` to any `tts` invocation anywhere in the skill or
  docs — background it via the Bash tool's `run_in_background` instead.
