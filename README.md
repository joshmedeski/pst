# pst

A local-first, on-device voice toolkit for macOS (Apple Silicon), packaged as a
[Claude Code plugin](https://code.claude.com/docs/en/plugins).

Today `pst` gives you **text-to-speech** that runs entirely on your machine —
no cloud, no API keys, no per-character billing — powered by
[`mlx-audio`](https://github.com/Blaizzy/mlx-audio) and the
[Kokoro-82M](https://huggingface.co/mlx-community/Kokoro-82M-4bit) model running
on Apple's MLX framework.

Installed as a Claude Code plugin, it exposes the `tts` skill as **`/pst:tts`**
(and the agent triggers it automatically when you ask it to "read that back" or
"say that out loud"). The `pst:` namespace is the umbrella for the voice skills
on the [roadmap](#roadmap) — `/pst:stt`, `/pst:converse`, and more.

## Install as a Claude Code plugin

`pst` is distributed as a plugin through its own marketplace (this repo). In
Claude Code:

```
/plugin marketplace add joshmedeski/pst
/plugin install pst@pst
```

That's it — the `tts` skill is now available as `/pst:tts`, and the `bin/`
scripts (`tts`, `tts-compare`) are on the Bash `PATH` while the plugin is
enabled.

> **Prerequisite:** the skill shells out to the local `tts` binary, which needs
> the `mlx-audio` engine. Do the one-time [engine setup](#setting-up-the-tts-engine-mlx-audio)
> below before first use.

### Local development

To iterate on the plugin from a checkout without publishing:

```bash
git clone https://github.com/joshmedeski/pst ~/c/pst
```

Then point Claude Code at the local marketplace and reload after edits:

```
/plugin marketplace add ~/c/pst
/plugin install pst@pst
/reload-plugins        # pick up edits mid-session
```

## Main feature: text-to-speech with mlx-audio

The [`bin/tts`](bin/tts) script speaks any text aloud using the Kokoro TTS model.
Because everything runs locally through MLX, it's fast, private, and free to run
as often as you like.

```bash
tts "hello world"
tts --voice bm_george "good evening"
tts --voices          # list available voices, grouped by language
tts --help
```

- **28 voices** across American/British and female/male, e.g. `af_heart`
  (default), `am_michael`, `bf_emma`, `bm_george`.
- Streams and saves generated audio to `/tmp`.
- The correct `lang_code` is inferred from the voice prefix (`a*` → American,
  `b*` → British).

### Comparing model quality

[`bin/tts-compare`](bin/tts-compare) generates the same sentence across the
Kokoro quantization variants (`bf16`, `8bit`, `6bit`, `4bit`) so you can pick the
quality/size trade-off that sounds best to you. Each sample self-labels its
variant so you can identify it by ear.

```bash
tts-compare                     # generate (if missing) and play all four
tts-compare "custom body text"  # override the sentence; regenerates
tts-compare -f                  # force regeneration even if cached
```

## Setting up the TTS engine (mlx-audio)

`pst` depends on `mlx-audio`. Install it as a `uv` tool from git `main` (required
for the 4bit model — PyPI 0.4.2 lacks the fix for loading quantized checkpoints):

```bash
uv tool install --force git+https://github.com/Blaizzy/mlx-audio.git \
  --prerelease=allow --with "misaki[en]" --with num2words \
  --with espeakng-loader --with "numpy>=1.26,<2" \
  --with "spacy>=3.7,<4" --with pip

# Download the spaCy English model into the tool's env:
~/.local/share/uv/tools/mlx-audio/bin/python -m spacy download en_core_web_sm
```

> **Note:** do *not* add `--with phonemizer`. `misaki[en]` already pulls in
> `phonemizer-fork`; installing plain `phonemizer` alongside it races on the
> shared `phonemizer/` directory and breaks misaki with
> `AttributeError: 'EspeakWrapper' has no attribute 'set_data_path'`.

Then put `bin/` on your `PATH`:

```bash
export PATH="$HOME/c/pst/bin:$PATH"
```

## Requirements

- macOS on Apple Silicon (MLX is Apple-Silicon only)
- [`uv`](https://github.com/astral-sh/uv)
- `afplay` (ships with macOS) for playback

## Roadmap

`pst` is growing into a full local voice-assistant loop. Work falls into two
tracks: **new skills** (each a top-level `/pst:` capability) and **TTS
refinements** (making the speech itself better — voice, pace, pronunciation,
and tone).

### New skills

Each ships as its own skill under the shared `pst:` namespace, so they can be
invoked independently or composed together.

| Skill | Command | Status | What it does |
|-------|---------|--------|--------------|
| `tts` | `/pst:tts` | ✅ Available | Summarize + speak text aloud (Kokoro via mlx-audio). |
| `stt` | `/pst:stt` | 🔜 Planned | Local, on-device transcription — talk *to* the machine, not just hear it talk back. |
| `converse` | `/pst:converse` | 🔜 Planned | Full duplex voice loop (STT → agent → TTS), usable in parallel with other work. |
| `wake-word` | — | 🔜 Planned | Hands-free local trigger ("hey pst") so the assistant listens only when summoned. |

Adding a skill is additive: drop a new `skills/<name>/SKILL.md` into the plugin
and it becomes `/pst:<name>` on the next reload — no changes to the existing
skills.

### TTS refinements

Improvements to how `/pst:tts` sounds. Each is an independent feature so they
can land one at a time.

| Feature | Status | What it does |
|---------|--------|--------------|
| **Voice selection** | 🔜 Planned | Choose which Kokoro voice speaks (`bin/tts --voice` exists; surface it as a first-class, persisted preference so you can set a default voice for the assistant). |
| **Speed control** | 🔜 Planned | Adjust speaking rate (slower for dense info, faster for quick confirmations), settable per-call and as a default. |
| **Pronunciation dictionary** | 🔜 Planned | A user-editable map of word → how-to-say-it, so terms like `id` → "eye-dee" or `Nutiliti` → "newtility" are always spoken correctly. Replaces today's ad-hoc rules baked into the skill. |
| **Tone / speech style** | 🔜 Planned | Select a delivery style (e.g. calm, upbeat, terse, narrator) so the same text can be spoken to match the moment. |
| **Contextual voice chooser** | 🔜 Planned | Automatically pick voice + tone from context — e.g. a distinct voice for errors vs. summaries vs. code, or per project — without asking. |
| **Voice cloning** | 🔜 Planned | Generate speech in a custom, user-provided voice. |
