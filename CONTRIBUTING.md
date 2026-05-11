# Contributing

`ofxGgmlSpeech` is a companion addon. Keep speech-specific workflow code here,
including whisper.cpp integration, and keep generic ggml/runtime primitives in
`ofxGgmlCore`.

Before changing public API or scripts:

- keep `ofxGgmlSpeech` depending on `ofxGgmlCore`, never the reverse
- keep examples focused and copyable
- keep generated models, media, builds, and IDE projects out of git
- update docs when command behavior changes

Run local validation before pushing:

```powershell
scripts\validate-local.bat
```
