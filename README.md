<p align="center">
  <img width="256" src="assets/logo.png" alt="pst logo: a vintage oscilloscope showing p∿t" />
</p>

<h1 align="center">pst, local-first speech for macOS</h1>

<p align="center">
  <a href="https://code.claude.com/docs/en/plugins">
    <img alt="Claude Code plugin" src="https://img.shields.io/badge/Claude_Code-plugin-ff5a36" />
  </a>
  <img alt="macOS Apple Silicon" src="https://img.shields.io/badge/macOS-Apple_Silicon-1f1f1f?logo=apple" />
  <a href="https://github.com/Blaizzy/mlx-audio">
    <img alt="powered by mlx-audio" src="https://img.shields.io/badge/powered_by-mlx--audio-f5efe6" />
  </a>
</p>

pst is an on-device voice toolkit for Apple Silicon, packaged as a
[Claude Code plugin](https://code.claude.com/docs/en/plugins). It speaks text
aloud, in stock voices, your own cloned voice, or a voice described in words,
without anything leaving your machine.

- 🏠 **Fully local** - runs on Apple's MLX framework via [`mlx-audio`](https://github.com/Blaizzy/mlx-audio); no cloud, no API keys, no per-character billing
- 🧠 **Open-weight models** - macOS's built-in `say` plus ten stock-voice models (Kokoro, Kitten, Pocket, Soprano, Melo, VibeVoice, Qwen3-TTS, Voxtral) and three cloning models (VoxCPM2, Qwen3-TTS, MOSS-TTS-Nano)
- 🎙️ **High-quality voices** - 120 stock voices in up to 11 languages, with volume matched across models
- ⚡ **Streaming playback** - audio starts as it generates, and nothing is written to disk
- 🪞 **Voice cloning** - speak in your own voice from a 15–20 second recording
- 🎨 **Voice design** - invent a voice from a description ("calm, somber, low male voice"), no recording needed
- 🔒 **Private by design** - reference recordings live in your XDG config, never in the repo
- 🔁 **Voice modes** - have the assistant speak once, every turn, or narrate as it works
- 🤖 **Claude Code skills** - `/pst:tts`, `/pst:tts-clone`, and `/pst:tts-design` trigger automatically when you ask to "read that back" or "say that in my voice"
- 🧹 **Disk cleanup** - `pst-cleanup` removes the models you tried and aren't using

> [!NOTE]
> Speech-to-text and full voice conversation are next on the [roadmap](#roadmap).

## Table of Contents

<table>
  <tr>
    <td>

- [Quick start](#quick-start)
- [Install](#install)
- [Which command do I use?](#which-command-do-i-use)
- [Text-to-speech](#text-to-speech)
  - [Choosing a model](#choosing-a-model)
  - [Voice modes](#voice-modes-always-on-and-verbose)
  - [Comparing model quality](#comparing-model-quality)
- [Voice cloning](#voice-cloning-speak-in-your-own-voice)
  - [Configure your own voice](#configure-your-own-voice)
  - [Choosing a cloning model](#choosing-a-cloning-model)

</td>
    <td>

- [Voice design](#voice-design-a-voice-from-a-description)
- [Configuration](#configuration)
- [Freeing disk space](#freeing-disk-space-after-trying-models)
- [Setting up the TTS engine](#setting-up-the-tts-engine-mlx-audio)
- [Local development](#local-development)
- [Resources](#resources)
- [Roadmap](#roadmap)

</td>
  </tr>
</table>

## Quick start

After [installing](#install), in Claude Code or your terminal:

```bash
tts "hello world"                                         # stock voice, starts instantly
tts-clone "the build passed"                              # your cloned voice
tts-clone --design "calm, low male voice" "deploy done"   # a voice from a description
```

Or just ask Claude Code to "read that back to me" or "say that in my voice".

## Install

**Requirements:** macOS on Apple Silicon (MLX is Apple-Silicon only) and
[`uv`](https://github.com/astral-sh/uv). Playback uses `afplay`, which ships
with macOS.

1. Add the marketplace (this repo) in Claude Code:

   ```
   /plugin marketplace add joshmedeski/pst
   ```

2. Install the plugin:

   ```
   /plugin install pst@pst
   ```

3. Install the on-device speech engine (one time):

   ```
   /pst:setup
   ```

   This installs `mlx-audio` via `uv`, and tells you how to install `uv` if
   it's missing. See [engine setup](#setting-up-the-tts-engine-mlx-audio) for
   what it runs.

The `/pst:tts`, `/pst:tts-clone`, and `/pst:tts-design` skills are now
available, and the `bin/` scripts (`tts`, `tts-clone`, `tts-compare`,
`pst-cleanup`) are on Claude Code's Bash `PATH` while the plugin is enabled.

> [!TIP]
> To run `tts` from your own terminal too, add `bin/` to your shell `PATH`:
>
> ```bash
> export PATH="$HOME/c/pst/bin:$PATH"
> ```

## Which command do I use?

| | `tts` | `tts-clone` | `tts-clone --design` |
|---|---|---|---|
| Voice | 120 stock voices | yours, from a recording | invented from a description |
| Needs a recording | no | yes, 15–20 s | no |
| Streaming | yes, audio starts right away | depends on the model | no |
| Delay before sound | none | ~3–7 s, depending on the model | ~5 s+, grows with text length |
| Speaking rate | `--speed` honored | pauses follow punctuation | pauses follow punctuation |
| Claude Code skill | `/pst:tts` | `/pst:tts-clone` | `/pst:tts-design` |
| Best for | always-on narration, quick feedback | when the voice itself is the point | a mood or character for one message |

None of them write audio to disk.

## Text-to-speech

The [`bin/tts`](bin/tts) script speaks any text aloud with a stock-voice model.
Kokoro is the default; nine other models are a flag away.

```bash
tts "hello world"
tts --voice bm_george "good evening"
tts --voices                       # voices of the model in use
tts --model pocket --voice marius "the build passed"
tts --models                       # compare models; * marks the one in use
tts --set-default-model qwen3-1.7b # remember a model for this machine
tts --set-default aiden            # remember a voice for the model in use
tts --help
```

Audio streams live as it generates on models that support it, and output
volume is matched across models, so switching models doesn't change how loud
it is.

### Choosing a model

| Model | Voices | Langs | Disk | First sound | License |
|---|---|---|---|---|---|
| `say` — macOS built-in [`say`](https://ss64.com/mac/say.html) | 184 | 40 | 0 GB | 0.1 s | macOS |
| `kokoro` (default) — [Kokoro-82M](https://huggingface.co/mlx-community/Kokoro-82M-4bit) | 31 | 9 | 0.6 GB | 2.5 s | Apache-2.0 |
| `kitten-nano` — [Kitten TTS nano](https://huggingface.co/mlx-community/kitten-tts-nano-0.8) | 8 | 1 | 0.06 GB | 0.8 s | Apache-2.0 |
| `kitten-mini` — [Kitten TTS mini](https://huggingface.co/mlx-community/kitten-tts-mini-0.8) | 8 | 1 | 0.3 GB | 1.1 s | Apache-2.0 |
| `pocket` — [Pocket TTS](https://huggingface.co/mlx-community/pocket-tts) | 8 | 1 | 0.2 GB | 1.9 s | CC-BY-4.0 |
| `soprano` — [Soprano 1.1](https://huggingface.co/mlx-community/Soprano-1.1-80M-bf16) | 1 | 1 | 0.3 GB | 2.9 s | Apache-2.0 |
| `melo` — [MeloTTS English v3](https://huggingface.co/mlx-community/MeloTTS-English-v3-MLX) | 1 | 1 | 0.6 GB | 5.7 s | MIT |
| `vibevoice` — [VibeVoice Realtime 0.5B](https://huggingface.co/mlx-community/VibeVoice-Realtime-0.5B-8bit) | 25 | 11 | 1.1 GB | 3.6 s | MIT |
| `qwen3-0.6b` — [Qwen3-TTS 0.6B CustomVoice](https://huggingface.co/mlx-community/Qwen3-TTS-12Hz-0.6B-CustomVoice-8bit) | 9 | 10 | 1.8 GB | 2.6 s | Apache-2.0 |
| `qwen3-1.7b` — [Qwen3-TTS 1.7B CustomVoice](https://huggingface.co/mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-8bit) | 9 | 10 | 2.9 GB | 2.6 s | Apache-2.0 |
| `voxtral` — [Voxtral 4B TTS](https://huggingface.co/mlx-community/Voxtral-4B-TTS-2603-mlx-4bit) | 20 | 9 | 2.4 GB | 3.1 s | CC-BY-NC-4.0 |

> [!WARNING]
> `voxtral`'s weights are licensed for non-commercial use only.

<details>
<summary>Parameters, memory, speed, and how these were measured</summary>

| Model | Params | Peak memory | Speed |
|---|---|---|---|
| `say` | - | 0.07 GB | 8× |
| `kokoro` | 82M | 2.5 GB | 43× |
| `kitten-nano` | 15M | 1.8 GB | 90× |
| `kitten-mini` | 80M | 2.1 GB | 24× |
| `pocket` | 100M | 1.0 GB | 19× |
| `soprano` | 80M | 0.4 GB | 18× |
| `melo` | 50M | 1.3 GB | 48× |
| `vibevoice` | 0.5B | 3.9 GB | 8× |
| `qwen3-0.6b` | 0.6B | 3.8 GB | 5× |
| `qwen3-1.7b` | 1.7B | 5.0 GB | 4.5× |
| `voxtral` | 4B | 3.4 GB | 3.2× |

Measured on an M4 Max (48 GB) with mlx-audio 0.4.4, one fresh process per
call (as `tts` runs), speaking a three-sentence, ~11-second message; medians
across 2–3 voices per model. "First sound" is process start to first audio.
Speed is warm generation in multiples of real time.

</details>

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
mode active each turn (it never speaks — the assistant authors all audio).

> [!NOTE]
> Existing installs must run `/reload-plugins` once to pick up the hooks.

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

## Voice cloning: speak in your own voice

[`bin/tts-clone`](bin/tts-clone) speaks text in a voice cloned from a recording
you supply. It stays on-device like everything else here, running one of three
interchangeable cloning models through `mlx-audio` — see
[Choosing a cloning model](#choosing-a-cloning-model).

```bash
tts-clone "the build passed"
tts-clone --voice josh "twelve files changed"
tts-clone --voices              # list installed voices
tts-clone --set-default josh    # remember a default for this machine
tts-clone --model qwen3 "hi"    # pick a cloning model for one call
tts-clone --models              # list models; * marks the one in use
tts-clone --set-default-model moss-nano
tts-clone --help
```

In Claude Code it's the **`/pst:tts-clone`** skill — ask the assistant to "say
that in my voice" and it triggers automatically.

### Your voice never enters this repo

Voices live in your XDG config directory, deliberately outside the checkout:

```
${XDG_CONFIG_HOME:-~/.config}/pst/voices/<name>.wav   # reference audio
```

Nothing about a voice is committable, and no contributor's voice name appears in
a tracked file — so installing or forking `pst` never means handing over your
voice. There's no `.gitignore` rule for this because nothing ever lands in the
repo to ignore.

> [!WARNING]
> This keeps your sample out of the repo. It cannot stop someone from cloning a
> voice out of recordings you've already published publicly.

### Configure your own voice

1. **Get a clean 15–20 second sample** of the voice talking continuously. Avoid
   long pauses, music, and background noise, and normalize it to a healthy
   level — a quiet or gappy reference clones noticeably worse. Mono 24 kHz WAV
   works well.

   `pst` does not ship tooling to produce this clip yet (see the
   [roadmap](ROADMAP.md#tts-refinements)) — record it yourself, or cut it out of
   existing audio with `ffmpeg`.

2. **Save it** as `<name>.wav` in the voices directory above, where `<name>` is
   whatever you want to call the voice.

3. **Set your default** (optional, only needed with more than one voice — with
   exactly one, `tts-clone` picks it automatically):

   ```bash
   tts-clone --set-default <name>
   ```

### Choosing a cloning model

All three models take the same reference recording, so switching is just a
flag. Ordered from highest fidelity to lightest:

| | `voxcpm2` (default) | `qwen3` | `moss-nano` |
|---|---|---|---|
| Model | [VoxCPM2](https://huggingface.co/mlx-community/VoxCPM2-bf16) | [Qwen3-TTS 1.7B Base](https://huggingface.co/mlx-community/Qwen3-TTS-12Hz-1.7B-Base-bf16) | [MOSS-TTS-Nano](https://huggingface.co/mlx-community/MOSS-TTS-Nano-100M) |
| Fidelity | ★★★ most natural | ★★ good | ★ rough, but recognizable |
| Parameters | 2B | 1.7B | 0.1B |
| Disk (download) | 4.6 GB | 4.2 GB | 0.4 GB |
| Peak memory | 8.2 GB | 6.4 GB | 1.8 GB |
| Streams | no — whole clip first | yes | no — but done almost instantly |
| Time to first sound | 5.2 s | 1.6 s | 1.3 s |
| Generation speed | 1.3× real time | 1.3× real time | ~7× real time |
| Languages | 30 | 10 | 20 |
| Pick it when | the voice matters most and a short wait is fine | you want quick, steady feedback | the machine is low on memory or battery |

> [!NOTE]
> The first run of each model downloads its weights (see the Disk row), so it
> takes noticeably longer than later runs.

<details>
<summary>How these were measured</summary>

Measured on an M4 Max (48 GB) with mlx-audio 0.4.4: median of three warm runs
speaking an 8-second, three-sentence message. Model load adds about 1.5 s on
every call and is not included above. Time to first sound for the non-streaming
models grows with the length of the text; Qwen3's does not. Energy was not
measured directly — generation time and peak memory are the best proxies here,
which makes `moss-nano` by far the lightest. Fidelity is a subjective
listening ranking.

</details>

## Voice design: a voice from a description

VoxCPM2 can also invent a voice from a natural-language description — gender,
age, tone, emotion, pace — with no reference audio at all:

```bash
tts-clone --design "calm, somber, low male voice, slow pace" "the deploy failed"
tts-clone --design "cheerful" --voice josh "your own voice, styled"
```

`--design` always uses `voxcpm2`, whatever the default clone model is. Add
`--voice` to style one of your cloned voices instead of inventing a new one.

In Claude Code it's the **`/pst:tts-design`** skill, and it picks the
description out of ordinary requests: "summarize this and give me a calm and
somber voice" summarizes, then speaks it in that voice.

## Configuration

Every setting resolves in the same order: flag → environment variable → saved
default → built-in fallback. Saved defaults are plain files in
`${XDG_CONFIG_HOME:-~/.config}/pst/`, written by the `--set-default*` flags.

| Setting | Flag | Env var | Saved default (`pst/…`) | Fallback |
|---|---|---|---|---|
| `tts` model | `--model` | `PST_TTS_MODEL` | `tts-model` | `kokoro` |
| `tts` voice | `--voice` | `PST_TTS_VOICE` | `tts-voice-<model>` | the model's default voice |
| `tts-clone` model | `--model` | `PST_CLONE_MODEL` | `clone-model` | `voxcpm2` |
| `tts-clone` voice | `--voice` | `PST_CLONE_VOICE` | `clone-voice` | the only installed voice |

`tts` voices are saved per model, and asking a model for a voice it doesn't
have is an error.

## Freeing disk space after trying models

Once you've settled on a model, `pst-cleanup` deletes the ones you aren't
using:

```bash
pst-cleanup         # list pst models on disk, their sizes, and ask before deleting
pst-cleanup --yes   # delete without asking
```

It keeps the `tts` and `tts-clone` models currently in use (resolved the same
way as `tts --models` and `tts-clone --models`), and deletes the other models of
both plus any Kokoro variants `tts-compare` downloaded. Only models
pst downloads are considered — anything else in your Hugging Face cache is left
alone. Deleted models re-download the next time you use them.

## Setting up the TTS engine (mlx-audio)

The recommended path is the [`pst-setup`](bin/pst-setup) script — run it in
Claude Code as `/pst:setup`, or directly:

```bash
pst-setup
```

It's idempotent (safe to re-run, doubles as a repair command) and does exactly
what the manual steps below do.

<details>
<summary>What it runs (manual equivalent)</summary>

`pst` depends on `mlx-audio`, installed as a `uv` tool from git `main` (required
for the 4bit model — PyPI 0.4.2 lacks the fix for loading quantized checkpoints):

```bash
uv tool install --force git+https://github.com/Blaizzy/mlx-audio.git \
  --prerelease=allow --with "misaki[en]" --with num2words \
  --with espeakng-loader --with "numpy>=1.26,<2" \
  --with "spacy>=3.7,<4" --with pip \
  --with "mistral-common[audio]" --with g2p_en

# Download the spaCy English model into the tool's env:
"$(uv tool dir)/mlx-audio/bin/python" -m spacy download en_core_web_sm
```

> [!WARNING]
> Do *not* add `--with phonemizer`. `misaki[en]` already pulls in
> `phonemizer-fork`; installing plain `phonemizer` alongside it races on the
> shared `phonemizer/` directory and breaks misaki with
> `AttributeError: 'EspeakWrapper' has no attribute 'set_data_path'`.

</details>

## Local development

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

## Resources

- [mlx-audio](https://github.com/Blaizzy/mlx-audio) — the MLX speech engine behind both `tts` and `tts-clone`
- [Kokoro-82M](https://huggingface.co/mlx-community/Kokoro-82M-4bit) — `tts`'s default stock-voice model; the others are linked in [Choosing a model](#choosing-a-model)
- [VoxCPM2](https://huggingface.co/openbmb/VoxCPM2) — `tts-clone`'s default cloning model ([MLX weights](https://huggingface.co/mlx-community/VoxCPM2-bf16))
- [Qwen3-TTS](https://github.com/QwenLM/Qwen3-TTS) — streaming cloning model, `tts-clone --model qwen3` ([MLX weights](https://huggingface.co/mlx-community/Qwen3-TTS-12Hz-1.7B-Base-bf16))
- [MOSS-TTS-Nano](https://huggingface.co/OpenMOSS-Team/MOSS-TTS-Nano-100M) — lightweight cloning model, `tts-clone --model moss-nano` ([MLX weights](https://huggingface.co/mlx-community/MOSS-TTS-Nano-100M))

## Roadmap

`pst` is growing into a full local voice-assistant loop. Next up:

- 🎧 **Speech-to-text** (`/pst:stt`) - local, on-device transcription
- 💬 **Voice conversation** (`/pst:converse`) - a full STT → agent → TTS loop
- 👂 **Wake word** - start a voice conversation with a spoken phrase instead of a command
- 🗣️ **Better speech** - speed control, a pronunciation dictionary, tone styles, contextual voice choice, and instant acknowledgments so there's no dead air
- 🚦 **Playback queue** - one machine-wide speaker, so sessions and projects never talk over each other

See [ROADMAP.md](ROADMAP.md) for the full plan and status of each item.
