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
