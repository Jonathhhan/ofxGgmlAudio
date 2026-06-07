# Changelog

## Unreleased

- Added an optional headless Whisper transcription smoke test for verifying the
  generated runtime, model, sample WAV, and native backend without launching the
  openFrameworks example.
- Added timestamped transcript segments, SRT/WebVTT export helpers, and subtitle
  output from the transcription example when Whisper returns segment timestamps.
- Added `ofxGgmlAudioRollingTranscript` for accumulating overlapping
  timestamped transcription chunks into text, SRT, and WebVTT output.
- Added a chunked Whisper smoke test for validating stream chunking, native
  transcription, rolling transcript deduplication, and subtitle export together.
- Added chunked rolling transcript mode to the transcribe example, including
  live chunk progress and between-chunk cancellation.
- Added an explicit Whisper example wrapper plus live microphone diagnostics
  with pause/resume, reset, VAD threshold controls, and RMS/VAD history plots.
- Added per-example build, run, clean, and quickstart wrappers for transcribe,
  Whisper, and live microphone workflows.
- Added a GUI example startup smoke test for the transcribe, Whisper, and live
  microphone examples, including dry-run coverage and platform-aware build
  hints.
- Fixed Windows GUI example startup crashes by routing early example logging to
  the debugger before the openFrameworks window opens.
- Cleaned generated example project defines so stale ImGui backend flags do not
  leak into rebuilt Visual Studio projects.
- Expanded `doctor-audio` and local validation so example setup checks cover all
  root-level examples and Core ggml local build-output layouts.

## 1.0.1 - 2026-05-12

- Added independent Audio addon version metadata.
- Exposed version metadata through the public umbrella header.
- Documented the release checklist, release policy, and `v1.0.1` scope.
- Kept Whisper runtime files, models, and sample audio as generated local-only
  state.

## 1.0.0

- Started `ofxGgmlAudio` as the companion addon for speech recognition,
  transcription, real-time audio processing, denoising, voice workflows, and
  audio event helpers on top of `ofxGgmlCore`.
- Added backend-neutral audio request/result types, stream chunking, lightweight
  feature helpers, baseline VAD, Whisper setup scripts, and a root-level
  transcription example lane.
