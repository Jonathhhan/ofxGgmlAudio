# Architecture

`ofxGgmlSpeech` owns speech-specific workflow code. It should use `ofxGgmlCore` for stable runtime primitives and keep model-family workflow details out of core.

## Dependency Direction

```text
openFrameworks app
  -> ofxGgmlSpeech
      -> ofxGgmlCore
```

No dependency should point from `ofxGgmlCore` back to `ofxGgmlSpeech`.

## Owned Here

- speech-specific request/result helpers
- model-specific preprocessing and postprocessing
- whisper.cpp runtime setup and backend integration
- focused root-level examples
- local media/model workflow documentation

## Not Owned Here

- ggml runtime setup and backend selection
- generic tensor, graph, model metadata, and result types
- unrelated companion workflows

## Whisper

`whisper.cpp` is the first backend owned here. It should stay behind
`ofxGgmlSpeechWhisperBackend` and explicit `scripts/build-whisper.*` setup
scripts. Do not create `ofxGgmlWhisper` unless the Whisper layer grows into a
large reusable runtime with multiple consumers outside speech workflows.
