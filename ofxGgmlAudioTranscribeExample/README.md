# ofxGgmlAudioTranscribeExample

Root-level Whisper transcription example for `ofxGgmlAudio`.

The example has editable model and audio fields, logs the selected paths with
`ofLog`, and runs transcription on a background thread so the UI remains
responsive while whisper.cpp works.

Build the optional runtime first:

```powershell
..\scripts\build-whisper.bat
```

Then compile the generated project with `OFXGGMLAUDIO_WITH_WHISPER` enabled and
link the generated whisper runtime listed in `addon_config.mk`.

Optional environment defaults:

```powershell
$env:OFXGGML_AUDIO_MODEL="C:\path\to\ggml-base.en.bin"
$env:OFXGGML_AUDIO_FILE="C:\path\to\speech.wav"
```

The current native path accepts WAV files, mixes to mono, and resamples to
16 kHz before passing float PCM to whisper.cpp.
