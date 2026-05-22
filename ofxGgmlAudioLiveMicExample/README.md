# ofxGgmlAudioLiveMicExample

Live microphone stream example for `ofxGgmlAudio`.

This example captures mono microphone input with `ofSoundStream`, pushes it
through `ofxGgmlAudioStreamChunker`, and displays deterministic audio features
plus the baseline voice-activity estimate. It does not claim model-backed
transcription; use the Whisper examples for file and chunked Whisper runtime
validation.

Generate it with openFrameworks projectGenerator using:

```txt
ofxGgmlCore
ofxGgmlAudio
ofxImGui
```
