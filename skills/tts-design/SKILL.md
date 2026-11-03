---
name: tts-design
description: Speak text aloud in a voice invented from a natural-language description (gender, age, tone, emotion, pace) using VoxCPM2 voice design via the local tts-clone binary — no reference audio needed. Use when the user runs "/pst:tts-design", or asks to hear something spoken in a described voice or mood, e.g. "summarize this and give me a calm and somber voice", "read it like an excited old pirate", "say that in a whispery young woman's voice", "custom voice". If the user names a stock model or the macOS say command ("say's robot voice", "a kokoro voice"), use the tts skill instead. Also use with the user's cloned voice when they ask for it styled ("in my voice, but cheerful").
---

# TTS Design - speak in a described voice

Invent a voice from a description and speak with it:

```bash
tts-clone --design "<voice description>" "Your spoken message here"
```

## Pulling the description out of the request

The voice description is usually mixed into other instructions. Split it out:

| User says | `--design` | Spoken text |
|---|---|---|
| "summarize this and give me a calm and somber" | `calm and somber` | a summary of the recent work |
| "read the error back like a grumpy old man, slowly" | `grumpy old man, slow pace` | the error, conversationally |
| "say 'ship it' as an excited young woman" | `excited young woman` | `ship it` |

Write the description as a short comma-separated list of traits (gender, age,
tone, emotion, pace, accent). Keep the user's words; only fill in what they
clearly implied. The rest of the request (summarize, read back, literal text)
decides the spoken text, exactly as the `tts` skill would.

## Designed voice vs. the user's own voice

- Default: **no `--voice`** — the voice is invented from the description alone.
- "in my voice, but calm" or a named installed voice → add `--voice <name>` to
  style that cloned voice instead. Run `tts-clone --voices` to find the name.

`--design` always uses VoxCPM2, whatever the default clone model is. Do not
pass `--model`.

## Running it

ALWAYS run via the Bash tool with `run_in_background: true` and **no** trailing
`&`. VoxCPM2 does not stream: expect a few seconds of silence while the whole
clip generates, longer on the first run while weights download.

## Guidelines

Same as the `tts-clone` skill: conversational spoken text, no code, paths, or
markdown; say "id" as "eye-dee" and "Nutiliti" as "newtility"; escape quotes
and shell characters.
