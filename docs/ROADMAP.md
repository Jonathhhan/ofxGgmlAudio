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
- Add lightweight stream feature helpers for RMS, peak, zero-crossing rate, and
  silence checks.
- Add a deterministic baseline VAD gate on top of stream features.
- Wire the first narrow Whisper transcription path for WAV input and PCM stream
  requests.
- Add dependency-free mono mixing and linear resampling to prepare PCM for
  Whisper's 16 kHz input rate.
- Add independent addon version metadata and release-candidate docs.

## Next Milestones

- Add broader media decoding before claiming general audio-file support.
- Add one useful openFrameworks example that runs with a user-provided Whisper
  model and audio file. Done first as `ofxGgmlAudioTranscribeExample`.
- Add task lanes for denoising, voice conversion, emotion cues, VAD, and audio
  event detection.
- Add focused tests around request/result helpers.
- Document the `clone -> setup -> run` path from a new user's point of view.
  Done first in `docs/QUICKSTART.md`.

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
- `ofxGgmlAudioFeatures` provides tiny feature extraction for meters, VAD gates,
  and classifier inputs without pulling in a model runtime.
- `ofxGgmlAudioFeatures::estimateVoiceActivity()` is a baseline heuristic gate;
  model-backed VAD can replace it later without changing stream windowing.
