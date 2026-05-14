# Architecture

`ofxGgmlAudio` owns audio-specific workflow code. It should use `ofxGgmlCore`
for stable runtime primitives and keep model-family workflow details out of
core.

## Dependency Direction

```text
openFrameworks app
  -> ofxGgmlAudio
      -> ofxGgmlCore
```

No dependency should point from `ofxGgmlCore` back to this addon.

## Owned Here

- audio-specific request/result helpers
- timestamped transcript segments and subtitle export helpers
- rolling transcript accumulation for overlapping stream chunks
- model-specific preprocessing and postprocessing
- whisper.cpp runtime setup and backend integration
- real-time stream inference helpers
- denoising, voice conversion, emotion, VAD, and audio-event workflows
- focused root-level examples
- local media/model workflow documentation

## Not Owned Here

- ggml runtime setup and backend selection
- generic tensor, graph, model metadata, and result types
- unrelated companion workflows

## Whisper

`whisper.cpp` is the first backend owned here. It should stay behind
`ofxGgmlAudioWhisperBackend` and explicit `scripts/build-whisper.*` setup
scripts. Do not create `ofxGgmlWhisper` unless the Whisper layer grows into a
large reusable runtime with multiple consumers outside audio workflows.

The scripted smoke coverage has two levels: `test-whisper-transcribe.*` verifies
single-file WAV transcription and timestamped subtitle export, while
`test-whisper-chunked-transcribe.*` verifies the streaming path through
`ofxGgmlAudioStreamChunker`, `ofxGgmlAudioWhisperBackend`, and
`ofxGgmlAudioRollingTranscript`.

See `docs/AUDIO_WORKFLOWS.md` before expanding the lane beyond Whisper. It
defines the planning handoff, generated-artifact boundaries, and validation
ladder for future audio workflows.
