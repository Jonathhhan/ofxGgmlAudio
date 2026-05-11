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

## Next Milestones

- Wire WAV/PCM decoding into `ofxGgmlAudioWhisperBackend::transcribe()`.
- Add one useful openFrameworks example that runs with a user-provided Whisper
  model and audio file.
- Add a streaming audio request/result shape for real-time inference.
- Add task lanes for denoising, voice conversion, emotion cues, VAD, and audio
  event detection.
- Add focused tests around request/result helpers.
- Document the `clone -> setup -> run` path from a new user's point of view.
