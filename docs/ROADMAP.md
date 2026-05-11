# Roadmap

## Current Milestone

- Seed the companion addon skeleton.
- Keep `ofxGgmlAudioTranscribeExample` as the first root-level smoke example.
- Keep `ofxGgmlCore` as the only required library dependency; examples may depend on `ofxImGui`.
- Add local validation and headless tests.
- Rename the lane and repository to `ofxGgmlAudio`.
- Decide that whisper.cpp lives in the audio lane first, not in a separate
  `ofxGgmlWhisper` addon.
- Add explicit whisper.cpp setup scripts and an unavailable-by-default
  `ofxGgmlAudioWhisperBackend` boundary.
- Add a streaming audio request/result shape for real-time inference.
- Add a backend-neutral stream chunker for live audio windows.

## Next Milestones

- Wire WAV/PCM decoding into `ofxGgmlAudioWhisperBackend::transcribe()`.
- Add one useful openFrameworks example that runs with a user-provided Whisper
  model and audio file.
- Add task lanes for denoising, voice conversion, emotion cues, VAD, and audio
  event detection.
- Add focused tests around request/result helpers.
- Document the `clone -> setup -> run` path from a new user's point of view.

## Stream API Notes

The first generic stream surface is intentionally backend-neutral:

- `ofxGgmlAudioTask` names the requested workflow.
- `ofxGgmlAudioStreamFormat` carries sample rate and channel count.
- `ofxGgmlAudioStreamRequest` carries interleaved float samples, timestamps,
  optional model paths, voice IDs, and hints.
- `ofxGgmlAudioStreamResult` can return generated samples, labels, scores, text,
  or errors without forcing one backend model family.
- `ofxGgmlAudioStreamChunker` turns openFrameworks audio callbacks into fixed
  model windows with a configurable hop size and timestamps.
