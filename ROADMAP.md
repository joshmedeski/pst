# pst roadmap

`pst` is growing into a full local voice-assistant loop. Work falls into three
tracks: **new skills** (each a top-level `/pst:` capability), **TTS
refinements** (making the speech itself better), and **playback &
orchestration** (making speech behave when several things want to talk).

Shipped features are documented in the [README](README.md).

## New skills

Each ships as its own skill under the shared `pst:` namespace, so they can be
invoked independently or composed together.

| Skill | Command | Status | What it does |
|-------|---------|--------|--------------|
| `stt` | `/pst:stt` | 🔜 Planned | Local, on-device transcription — talk *to* the machine, not just hear it talk back. |
| `converse` | `/pst:converse` | 🔜 Planned | Full duplex voice loop (STT → agent → TTS), usable in parallel with other work. |
| `wake-word` | — | 💡 Someday | Hands-free local trigger (a spoken phrase) that starts a `/pst:converse` loop instead of a command. |

Adding a skill is additive: drop a new `skills/<name>/SKILL.md` into the plugin
and it becomes `/pst:<name>` on the next reload — no changes to the existing
skills.

### Voice conversation design notes

The goal is a fully hands-free back-and-forth: Claude speaks, a cue says it's
my turn, the mic opens, I talk, and the transcript goes straight back to
Claude.

- **Prior art first.** [VoiceMode](https://github.com/mbailey/voicemode)
  already does mic → Whisper → Claude → Kokoro offline with silence detection.
  Evaluate it (and Claude Code's push-to-talk `/voice`) before building, and
  adopt or adapt rather than rebuild.
- **Turn-taking.** Try voice-activity (silence) detection first; keep a spoken
  keyword like "over" as a fallback for noisy rooms.
- **Turn cue.** A short "your turn" sound before the mic opens, played through
  the [playback queue](#playback--orchestration) so it never overlaps a
  response.
- **Later.** Barge-in (interrupt Claude by talking), Whisper model-size tuning
  for latency vs. accuracy, and a visual turn indicator alongside the sound.

## TTS refinements

Improvements to how `/pst:tts` sounds. Each is an independent feature so they
can land one at a time.

| Feature | Status | What it does |
|---------|--------|--------------|
| **Speed control** | 🔜 Planned | Adjust speaking rate (slower for dense info, faster for quick confirmations), settable per-call and as a default. |
| **Pronunciation dictionary** | 🔜 Planned | A user-editable map of word → how-to-say-it, so terms like `id` → "eye-dee" or `Nutiliti` → "newtility" are always spoken correctly. Replaces today's ad-hoc rules baked into the skill. |
| **Tone / speech style** | 🔜 Planned | Select a delivery style (e.g. calm, upbeat, terse, narrator) so the same text can be spoken to match the moment. |
| **Contextual voice chooser** | 🔜 Planned | Automatically pick voice + tone from context — e.g. a distinct voice for errors vs. summaries vs. code, or per project — without asking. |
| **Instant acknowledgments** | 🔜 Planned | A small set of pre-generated filler clips ("Working on it…") played the moment a response starts, so there's no dead air while the real summary generates. |
| **Voice sample extraction** | 🔜 Planned | Tooling to build a clone reference from existing audio (find a clean continuous-speech window, normalize it) instead of preparing the WAV by hand. |

## Playback & orchestration

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
| **Per-project voices** | 🔜 Planned | Assign a distinct voice per project so you can tell at a glance (by ear) which project is talking. |
| **Per-agent voices** | 💡 Someday | Give each Claude Code sub-agent its own voice, so delegated work is audibly "someone else" talking. |
| **Project-handoff announcements** | 🔜 Planned | When the next queued utterance belongs to a different project than the one just spoken, prepend a spoken identity cue first — e.g. "Back in the Nutiliti project…" — so context switches are never ambiguous. |
