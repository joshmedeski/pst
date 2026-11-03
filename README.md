# pst

> **Local-first speech tooling optimized for macOS (text-to-speech and speech-to-text).**

A local-first, on-device voice toolkit for macOS (Apple Silicon), packaged as a
[Claude Code plugin](https://code.claude.com/docs/en/plugins).

Today `pst` gives you **text-to-speech** that runs entirely on your machine —
no cloud, no API keys, no per-character billing — powered by
[`mlx-audio`](https://github.com/Blaizzy/mlx-audio) and the
[Kokoro-82M](https://huggingface.co/mlx-community/Kokoro-82M-4bit) model running
on Apple's MLX framework.

It also does **[voice cloning](#voice-cloning-speak-in-your-own-voice)** — speak
in your own voice from a short reference recording you supply, still entirely
on-device.

Installed as a Claude Code plugin, it exposes the `tts` skill as **`/pst:tts`**
and cloning as **`/pst:tts-clone`** (and the agent triggers them automatically
when you ask it to "read that back" or "say that in my voice"). The `pst:`
namespace is the umbrella for the voice skills on the [roadmap](#roadmap) —
`/pst:stt`, `/pst:converse`, and more.

## Install as a Claude Code plugin

`pst` is distributed as a plugin through its own marketplace (this repo). In
Claude Code:

```
/plugin marketplace add joshmedeski/pst
/plugin install pst@pst
```

That's it — the `tts` and `tts-clone` skills are now available as `/pst:tts` and
`/pst:tts-clone`, and the `bin/` scripts (`tts`, `tts-clone`, `tts-compare`) are
on the Bash `PATH` while the plugin is enabled.

> **Prerequisite:** the skill shells out to the local `tts` binary, which needs
> the `mlx-audio` engine. Run the one-time setup first:
>
> ```
> /pst:setup
> ```
>
> This installs the on-device tooling via `uv` (see
> [engine setup](#setting-up-the-tts-engine-mlx-audio) for what it does and the
> manual equivalent). It requires [`uv`](https://github.com/astral-sh/uv) — the
> command tells you how to install it if it's missing.

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

The [`bin/tts`](bin/tts) script speaks any text aloud with a stock-voice model.
Kokoro is the default; nine other models are a flag away. Because everything
runs locally through MLX, it's fast, private, and free to run as often as you
like.

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

- Streams audio live as it generates on models that support it; nothing is
  written to disk.
- Output volume is matched across models, so switching models doesn't change
  how loud it is.

### Choosing a model

| Model | Voices | Langs | Params | Disk | Peak memory | Process start → first sound | Speed | License |
|---|---|---|---|---|---|---|---|---|
| `kokoro` (default) — [Kokoro-82M](https://huggingface.co/mlx-community/Kokoro-82M-4bit) | 31 | 9 | 82M | 0.6 GB | 2.5 GB | 2.5 s | 43× | Apache-2.0 |
| `kitten-nano` — [Kitten TTS nano](https://huggingface.co/mlx-community/kitten-tts-nano-0.8) | 8 | 1 | 15M | 0.06 GB | 1.8 GB | 0.8 s | 90× | Apache-2.0 |
| `kitten-mini` — [Kitten TTS mini](https://huggingface.co/mlx-community/kitten-tts-mini-0.8) | 8 | 1 | 80M | 0.3 GB | 2.1 GB | 1.1 s | 24× | Apache-2.0 |
| `pocket` — [Pocket TTS](https://huggingface.co/mlx-community/pocket-tts) | 8 | 1 | 100M | 0.2 GB | 1.0 GB | 1.9 s | 19× | CC-BY-4.0 |
| `soprano` — [Soprano 1.1](https://huggingface.co/mlx-community/Soprano-1.1-80M-bf16) | 1 | 1 | 80M | 0.3 GB | 0.4 GB | 2.9 s | 18× | Apache-2.0 |
| `melo` — [MeloTTS English v3](https://huggingface.co/mlx-community/MeloTTS-English-v3-MLX) | 1 | 1 | 50M | 0.6 GB | 1.3 GB | 5.7 s | 48× | MIT |
| `vibevoice` — [VibeVoice Realtime 0.5B](https://huggingface.co/mlx-community/VibeVoice-Realtime-0.5B-8bit) | 25 | 11 | 0.5B | 1.1 GB | 3.9 GB | 3.6 s | 8× | MIT |
| `qwen3-0.6b` — [Qwen3-TTS 0.6B CustomVoice](https://huggingface.co/mlx-community/Qwen3-TTS-12Hz-0.6B-CustomVoice-8bit) | 9 | 10 | 0.6B | 1.8 GB | 3.8 GB | 2.6 s | 5× | Apache-2.0 |
| `qwen3-1.7b` — [Qwen3-TTS 1.7B CustomVoice](https://huggingface.co/mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-8bit) | 9 | 10 | 1.7B | 2.9 GB | 5.0 GB | 2.6 s | 4.5× | Apache-2.0 |
| `voxtral` — [Voxtral 4B TTS](https://huggingface.co/mlx-community/Voxtral-4B-TTS-2603-mlx-4bit) | 20 | 9 | 4B | 2.4 GB | 3.4 GB | 3.1 s | 3.2× | CC-BY-NC-4.0 |

Measured on an M4 Max (48 GB) with mlx-audio 0.4.4, one fresh process per
call (as `tts` runs), speaking a three-sentence, ~11-second message; medians
across 2–3 voices per model. Speed is warm generation in multiples of real
time. `voxtral`'s weights are non-commercial.

Model resolution order: `--model` → `$PST_TTS_MODEL` → the
`--set-default-model` value (stored in
`${XDG_CONFIG_HOME:-~/.config}/pst/tts-model`) → `kokoro`.

Voice resolution order: `--voice` → `$PST_TTS_VOICE` → the `--set-default`
value for that model (stored in `${XDG_CONFIG_HOME:-~/.config}/pst/tts-voice-<model>`)
→ the model's default voice. A voice that the model doesn't have is an error.

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
you supply, instead of Kokoro's stock voice table. It stays on-device like
everything else here, running one of three interchangeable cloning models
through `mlx-audio` — see [Choosing a cloning model](#choosing-a-cloning-model).

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

> Worth being clear about the limit: this keeps your sample out of the repo. It
> cannot stop someone from cloning a voice out of recordings you've already
> published publicly.

### Configure your own voice

1. **Get a clean 15–20 second sample** of the voice talking continuously. Avoid
   long pauses, music, and background noise, and normalize it to a healthy
   level — a quiet or gappy reference clones noticeably worse. Mono 24 kHz WAV
   works well.

   `pst` does not ship tooling to produce this clip yet (see
   [roadmap](#tts-refinements)) — record it yourself, or cut it out of existing
   audio with `ffmpeg`.

2. **Save it** as `<name>.wav` in the voices directory above, where `<name>` is
   whatever you want to call the voice.

3. **Set your default** (optional):

   ```bash
   tts-clone --set-default <name>
   ```

Step 3 only matters once you have more than one voice installed — with exactly
one, `tts-clone` picks it automatically. The default is stored per machine in
`${XDG_CONFIG_HOME:-~/.config}/pst/clone-voice`, never in the repo.

Voice resolution order: `--voice` → `$PST_CLONE_VOICE` → the `--set-default`
value → the only installed voice.

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

Measured on an M4 Max (48 GB) with mlx-audio 0.4.4: median of three warm runs
speaking an 8-second, three-sentence message. Model load adds about 1.5 s on
every call and is not included above. Time to first sound for the non-streaming
models grows with the length of the text; Qwen3's does not. Energy was not
measured directly — generation time and peak memory are the best proxies here,
which makes `moss-nano` by far the lightest. Fidelity is a subjective
listening ranking.

Model resolution order: `--model` → `$PST_CLONE_MODEL` → the
`--set-default-model` value (stored in
`${XDG_CONFIG_HOME:-~/.config}/pst/clone-model`) → `voxcpm2`.

> **First run** of each model downloads its weights (see the Disk row), so it
> takes noticeably longer than later runs.

### Freeing disk space after trying models

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

### Voice design: a voice from a description

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

### How it differs from `tts`

| | `tts` | `tts-clone` |
|---|---|---|
| Voice | stock voices (see `tts --models`) | one you supply |
| Streaming | yes — audio starts right away | depends on the model (see above) |
| Delay before sound | none | ~3–7 s, depending on the model |
| Speaking rate | `--speed` honored | not supported; pauses follow punctuation |
| Disk | nothing written | nothing written |

Because of that delay, `tts` remains the right choice for always-on narration
and running commentary. Reach for `tts-clone` when the voice itself is the point.

## Setting up the TTS engine (mlx-audio)

The recommended path is the [`pst-setup`](bin/pst-setup) script — run it in
Claude Code as `/pst:setup`, or directly:

```bash
pst-setup
```

It's idempotent (safe to re-run, doubles as a repair command) and does exactly
what the manual steps below do. It requires [`uv`](https://github.com/astral-sh/uv)
and tells you how to install it if it's missing.

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

> **Note:** do *not* add `--with phonemizer`. `misaki[en]` already pulls in
> `phonemizer-fork`; installing plain `phonemizer` alongside it races on the
> shared `phonemizer/` directory and breaks misaki with
> `AttributeError: 'EspeakWrapper' has no attribute 'set_data_path'`.

</details>

> **Running `tts` outside Claude Code?** The plugin puts `bin/` on the Bash
> tool's `PATH` automatically, so no setup is needed for `/pst:tts`. To call
> `tts` from your own terminal too, add `bin/` to your shell `PATH`:
>
> ```bash
> export PATH="$HOME/c/pst/bin:$PATH"
> ```

## Requirements

- macOS on Apple Silicon (MLX is Apple-Silicon only)
- [`uv`](https://github.com/astral-sh/uv)
- `afplay` (ships with macOS) for playback

## Resources

- [mlx-audio](https://github.com/Blaizzy/mlx-audio) — the MLX speech engine behind both `tts` and `tts-clone`
- [Kokoro-82M](https://huggingface.co/mlx-community/Kokoro-82M-4bit) — `tts`'s default stock-voice model; the others are linked in [Choosing a model](#choosing-a-model)
- [VoxCPM2](https://huggingface.co/openbmb/VoxCPM2) — `tts-clone`'s default cloning model ([MLX weights](https://huggingface.co/mlx-community/VoxCPM2-bf16))
- [Qwen3-TTS](https://github.com/QwenLM/Qwen3-TTS) — streaming cloning model, `tts-clone --model qwen3` ([MLX weights](https://huggingface.co/mlx-community/Qwen3-TTS-12Hz-1.7B-Base-bf16))
- [MOSS-TTS-Nano](https://huggingface.co/OpenMOSS-Team/MOSS-TTS-Nano-100M) — lightweight cloning model, `tts-clone --model moss-nano` ([MLX weights](https://huggingface.co/mlx-community/MOSS-TTS-Nano-100M))

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
| `tts` | `/pst:tts` | ✅ Available | Summarize + speak text aloud (Kokoro or nine other stock-voice models via mlx-audio). |
| `tts-clone` | `/pst:tts-clone` | ✅ Available | Speak in your own voice, cloned from a reference recording (VoxCPM2, Qwen3-TTS, or MOSS-TTS-Nano via mlx-audio). |
| `tts-design` | `/pst:tts-design` | ✅ Available | Speak in a voice invented from a description ("calm and somber, older man") via VoxCPM2 voice design. |
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
| **Voice selection** | ✅ Available | Choose the model and voice that speaks, per call or as a persisted default — see [Choosing a model](#choosing-a-model). |
| **Speed control** | 🔜 Planned | Adjust speaking rate (slower for dense info, faster for quick confirmations), settable per-call and as a default. |
| **Pronunciation dictionary** | 🔜 Planned | A user-editable map of word → how-to-say-it, so terms like `id` → "eye-dee" or `Nutiliti` → "newtility" are always spoken correctly. Replaces today's ad-hoc rules baked into the skill. |
| **Tone / speech style** | 🔜 Planned | Select a delivery style (e.g. calm, upbeat, terse, narrator) so the same text can be spoken to match the moment. |
| **Contextual voice chooser** | 🔜 Planned | Automatically pick voice + tone from context — e.g. a distinct voice for errors vs. summaries vs. code, or per project — without asking. |
| **Voice cloning** | ✅ Available | Generate speech in a custom, user-provided voice — see [voice cloning](#voice-cloning-speak-in-your-own-voice). |
| **Voice sample extraction** | 🔜 Planned | Tooling to build a clone reference from existing audio (find a clean continuous-speech window, normalize it) instead of preparing the WAV by hand. |

### Playback & orchestration

Making speech behave when more than one thing wants to talk at once — across
long outputs, concurrent sessions, and multiple projects. The unifying
primitive is a **serialized playback queue**: a single global speaker that plays
one utterance at a time, in order, and never overlaps itself. The features below
are behaviors layered on that queue.

| Feature | Status | What it does |
|---------|--------|--------------|
| **Serialized playback queue** | 🔜 Planned | One global speaker, FIFO, one utterance at a time. The core primitive the rest build on — nothing ever plays over anything else. |
| **Sectioned playback** | 🔜 Planned | Break a large output (big plan, code walkthrough, dashboard summary) into ordered chunks and speak them back-to-back through the queue, so long content is delivered section by section without the voice overlapping itself. |
| **Cross-session audio lock** | 🔜 Planned | A machine-wide lock so multiple projects / Claude sessions with TTS on don't speak over each other — the queue is shared across processes, not per-session. |
| **Per-project voices** | 🔜 Planned | Assign a distinct Kokoro voice per project so you can tell at a glance (by ear) which project is talking. |
| **Project-handoff announcements** | 🔜 Planned | When the next queued utterance belongs to a different project than the one just spoken, prepend a spoken identity cue first — e.g. "Back in the Nutiliti project…" — so context switches are never ambiguous. |
