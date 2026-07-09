---
name: tts
description: Summarize conversation feedback and speak it aloud using the local tts binary (Kokoro TTS via mlx-audio). Use when the user runs "/pst:tts", says "read this back to me", "summarize and speak", "text to speech", or wants an audio summary of the current conversation or any text. Trigger on any request to hear something spoken aloud.
---

# TTS - Text to Speech

Summarize conversation context into a concise spoken message and play it aloud using the local `tts` binary.

## Usage

1. Review the conversation history for key feedback, decisions, outcomes, or takeaways
2. Write a concise, natural-sounding summary (1-3 sentences, under 200 words) suitable for spoken audio
3. Run the summary through tts in the background so the user can continue working:

```bash
tts "Your summary message here" &
```

## Guidelines

- Keep summaries conversational and natural - this will be spoken aloud
- Focus on actionable takeaways: what was decided, what changed, what to do next
- Avoid technical syntax, file paths, code snippets, or markdown formatting in the spoken text
- Use plain English, short sentences, and natural phrasing
- If the user provides a specific message (e.g., `/pst:tts "custom message"`), speak that message directly instead of summarizing
- Escape any quotes or special shell characters in the text before passing to the command
- Spell "id" phonetically as "eye-dee" in the spoken text (e.g. "click up id" becomes "click up eye-dee") so it isn't mispronounced
- Spell "Nutiliti" phonetically as "newtility" in the spoken text (it's a play on "new utility", pronounced new-TIL-ih-tee) so it isn't mispronounced
- The `tts` binary plays audio immediately via `--play` - no file management needed
- ALWAYS run the tts command in the background (append `&`) and use `run_in_background: true` on the Bash tool so the user can continue working without waiting for audio to finish
