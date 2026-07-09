# pst Voice Modes — Design

**Date:** 2026-07-08
**Status:** Approved (design), pending implementation plan

## Problem

Today `/pst:tts` is a *pull* model: the user asks, and the agent summarizes the
conversation and speaks it once. The user wants a *push / always-on* mode they
can toggle for the rest of a session, and separately wants the agent to narrate
what it's doing as it works so they stay in sync.

## Concept: two independent dials

Voice behavior is described by two orthogonal dials:

- **Cadence** — *when* the agent speaks.
  - `on-demand` (default): speak only when `/pst:tts` is invoked.
  - `always`: speak every turn for the rest of the session.
- **Style** — *what* the agent speaks.
  - `terse` (default): a concise end-of-turn summary (today's behavior).
  - `verbose` (**medium** narration): the agent explains its work as it goes.

The dials compose. `always + verbose` is a continuous spoken companion;
`always` alone is a spoken summary each turn; `verbose` alone is a one-shot
narration of a single task.

### What "verbose = medium" means

When style is verbose, within a turn the agent speaks:

1. **Opener** — one line on the plan at the start of the turn/task
   (e.g. "I'll explore the project first, then figure out the design").
2. **Decision notes** — a short spoken note at real forks: when something fails
   or the agent switches approach (e.g. "that didn't work, trying another way").
3. **Wrap-up** — a brief spoken summary at the end.

Each utterance is a single short sentence, spoken in the background
(non-blocking), and follows the existing pronunciation rules (`id` →
"eye-dee", `Nutiliti` → "newtility"). It avoids file paths, code, and markdown.

## Command surface

The existing `/pst:tts` skill parses optional mode arguments — **no new
commands**:

| Invocation | Cadence | Style | Persists? | Effect |
|---|---|---|---|---|
| `/pst:tts` | on-demand | terse | no | One-shot summary (**unchanged**) |
| `/pst:tts "text"` | on-demand | — | no | Speak the given text (**unchanged**) |
| `/pst:tts verbose` | on-demand | verbose | no | Narrate **this task** aloud, then stop |
| `/pst:tts always` | always | terse | yes | Speak a wrap-up every turn |
| `/pst:tts always verbose` | always | verbose | yes | Continuous spoken companion |
| `/pst:tts off` | on-demand | terse | clears | Turn off always-mode |

Argument parsing: the tokens `always`, `verbose`, and `off` are recognized in
any order. Anything else (quoted or not) is treated as literal text to speak
(current behavior). `verbose` without `always` is a one-shot: the agent narrates
the current turn but writes **no** state, so it does not persist.

## Mechanism: how `always` survives the whole session

A plain "remember to speak each turn" instruction decays on long sessions and is
lost after context compaction — which defeats the core requirement ("rest of the
conversation"). The reliable design has three parts:

### 1. Session-scoped state file

Path: `${XDG_CONFIG_HOME:-$HOME/.config}/pst/voice/<session-id>`

- Contents: a single line of space-separated tokens the persistent mode needs —
  either `always` or `always verbose`.
- **Presence of the file = always-mode is on.** Absence = off.
- One-shot `verbose` never writes this file.

### 2. A `UserPromptSubmit` hook (the glue, shipped by the plugin)

On every user turn the hook:

1. Reads the hook JSON from stdin and extracts the session id.
2. Computes the state-file path and checks for it.
3. If present, prints a one-line reminder to stdout (which Claude Code injects
   into the agent's context for that turn), e.g.:
   - `always` → "pst voice mode is ON (terse): speak a concise spoken wrap-up
     at the end of this turn via the `tts` binary in the background."
   - `always verbose` → the above **plus** "Narrate as you work: a one-line
     spoken opener, short notes at decision points, and a wrap-up."
4. If absent, prints nothing and exits 0.

The hook **never calls `tts` itself.** The agent still crafts and plays all
audio. This keeps speech summarized/natural and lets narration happen mid-turn
(a `Stop` hook fires only once, at the end, and could not narrate).

### 3. A `SessionEnd` hook (cleanup)

Deletes the session's state file when the session ends, strictly enforcing
session-only scope so the mode never leaks into a future conversation.

### Shared helper

A single helper script (e.g. `bin/pst-voice`) owns the state-file path
computation and the `set` / `get` / `clear` operations, so the skill and the
hooks agree on one implementation. It `mkdir -p`s the directory as needed.

**Implementation detail to verify in the plan:** the exact, reliable way to
obtain the current session id in (a) a bash command run from within the skill
and (b) the hook's stdin JSON. The hook receives `session_id` in its JSON
payload; the skill-side source (`$CLAUDE_SESSION_ID` env var vs. deriving from
the transcript/session path) must be confirmed empirically and standardized in
the helper so both sides key the file identically.

## Skill (`SKILL.md`) behavior

`skills/tts/SKILL.md` is updated to:

- Parse the mode arguments described above.
- On `always` / `always verbose`: write the state file via the helper, confirm
  to the user, and begin behaving accordingly this turn.
- On `off`: clear the state file via the helper and confirm.
- On `verbose` (one-shot): narrate the current turn only; write no state.
- Document the medium-verbose narration pattern (opener / decision notes /
  wrap-up).
- Document that when the hook's reminder appears in context, the agent should
  speak the appropriate audio for that turn.
- Standardize the `tts` invocation convention on `run_in_background: true` with
  **no** trailing `&` (resolves an existing inconsistency between the committed
  and working-tree versions of the skill; the trailing `&` trips a
  command-safety prompt and fires the completion notice before audio finishes).

## Packaging

- The plugin ships `hooks/hooks.json` registering the `UserPromptSubmit` and
  `SessionEnd` hooks, invoked via `${CLAUDE_PLUGIN_ROOT}/bin/...`.
- Because the plugin now ships hooks, existing installs pick them up on
  `/reload-plugins` (or reinstall). Note this in the README.
- New scripts live under `bin/` (already on the plugin's Bash `PATH`).

## Error handling

- Missing state directory: the helper creates it (`mkdir -p`).
- Unreadable/corrupt state file: hook treats it as "off" (fail safe — silence,
  never crash the turn).
- Missing session id: helper falls back to a stable default key and the hook
  degrades to no-op rather than erroring; the turn is never blocked.
- `tts` binary missing or engine not set up: unchanged from today — the agent
  surfaces the failure; voice mode does not mask setup problems.

## Testing

- **Helper unit tests** (shell, using a temp `XDG_CONFIG_HOME`): `set always`
  then `get` returns `always`; `set always verbose` round-trips; `clear`
  removes the file; `get` on absent file reports "off".
- **Hook tests**: feed a synthetic stdin JSON with a session id whose state file
  contains `always` / `always verbose` / is absent, and assert the emitted
  reminder text (or empty output) for each case.
- **Manual end-to-end**: `/pst:tts always verbose`, confirm subsequent turns
  receive the reminder and produce narration + wrap-up audio; `/pst:tts off`
  confirms the reminder stops.

## Out of scope (YAGNI)

- Voice/speed/tone selection per mode (tracked separately on the roadmap).
- Global (cross-session) persistence — deliberately session-only.
- Hook-side summarization via an LLM — keeps the design local-first and cheap;
  the agent remains the author of all speech.
