---
name: tts-clone
description: Speak text aloud in the user's own cloned voice using the local tts-clone binary (Chatterbox via mlx-audio). Use when the user runs "/pst:tts-clone", says "say that in my voice", "read this back in my own voice", "use my cloned voice", or asks for spoken output in a cloned/custom voice rather than a stock one. For stock Kokoro voices and always-on voice modes, use the tts skill instead.
---

# TTS Clone - speak in a cloned voice

Speak text aloud with the local `tts-clone` binary, which clones a voice from a
reference recording instead of using Kokoro's stock voice table.

## Speaking

```bash
tts-clone "Your spoken message here"
```

Pass **no** `--voice` flag. The voice is per-user machine configuration, not
something this skill decides — `tts-clone` resolves it from `$PST_CLONE_VOICE`,
then the machine's configured default, then the only installed voice. Hardcoding
a name here would break every user but one, since pst is open source.

Only pass `--voice <name>` when the user explicitly names a voice.

ALWAYS run `tts-clone` via the Bash tool with `run_in_background: true` and **no**
trailing `&`. A trailing `&` is redundant, trips a command-safety prompt, and
fires the completion notification before the audio finishes playing.

## Timing - this is not `tts`

Unlike `tts`, Chatterbox **cannot stream**. It generates a complete file before
any sound plays, so expect roughly:

- **~5s of silence** before playback begins (longer on the first run of a
  session, which loads model weights from disk)
- then playback of the generated audio

Because of that delay, prefer `tts` for running narration and always-on voice
modes. Reach for `tts-clone` when the voice itself is the point.

## When no voice is installed

`tts-clone` exits with `no voices installed` when the user has not set one up. Do
not try to work around it or fall back to `tts` silently. Tell the user they need
a reference recording installed at
`${XDG_CONFIG_HOME:-~/.config}/pst/voices/<name>.wav` with its transcript
alongside as `<name>.txt`, then `tts-clone --set-default <name>`.

Run `tts-clone --voices` to see what is installed.

## Guidelines

- Keep spoken text conversational and natural — it will be spoken aloud.
- Avoid technical syntax, file paths, code snippets, or markdown in spoken text.
  This matters more here than with `tts`: paths come out badly mangled
  (`~/.config/pst` was heard as "IRconfigPress"). Say paths as words, or omit them.
- Say "id" as "eye-dee" (e.g. "click up id" → "click up eye-dee").
- Say "Nutiliti" as "newtility" (a play on "new utility", new-TIL-ih-tee).
- Escape any quotes or special shell characters before passing to the command.
- If the user provides literal text, speak that directly instead of summarizing.
- A voice sample is personal. Never copy a `voices/` file into the repo, quote its
  path into committed code, or share it — the whole point of keeping voices under
  XDG config is that installing pst never means handing over your voice.
