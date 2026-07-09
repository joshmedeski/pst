---
name: setup
description: Install or repair the local mlx-audio tooling that pst's text-to-speech depends on (uv tool install + spaCy model). Use when the user runs "/pst:setup", is setting up pst for the first time, or when tts fails because mlx-audio / mlx_audio.tts.generate is missing or broken.
---

# pst Setup

One-time (idempotent) install of the on-device TTS engine that `tts` relies on.

## Steps

1. Run the setup script. It ships with the plugin and is on the Bash `PATH`
   while the plugin is enabled:

   ```bash
   pst-setup
   ```

2. Report the outcome to the user based on how it exits:
   - **Success** — tell them TTS is ready and they can try `/pst:tts` or
     `tts "hello world"`.
   - **`uv` is not installed** — the script prints install instructions
     (`brew install uv`, or the astral.sh installer). Relay those and tell them
     to re-run `/pst:setup` once `uv` is available.
   - **Any other failure** — show the error output; the install can be retried
     by running `pst-setup` again.

## Notes

- Safe to re-run — it uses `uv tool install --force` and re-downloads the spaCy
  model, so it doubles as a repair command.
- Requires `uv` and macOS on Apple Silicon.
- Always call `pst-setup` rather than pasting the raw `uv tool install` command
  by hand — the script pins the exact, tested flags (git-main source, the
  no-`phonemizer` rule, the spaCy model step).
