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
