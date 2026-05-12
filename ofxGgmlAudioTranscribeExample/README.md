# ofxGgmlAudioTranscribeExample

Root-level Whisper transcription example for `ofxGgmlAudio`.

The example has editable model and audio fields, logs the selected paths with
`ofLog`, and runs transcription on a background thread so the UI remains
responsive while whisper.cpp works.

First run:

```powershell
..\scripts\quickstart-transcribe-example.bat
```

For manual setup, build the optional runtime, download local assets, then
compile the generated project with `OFXGGMLAUDIO_WITH_WHISPER` enabled:

```powershell
..\scripts\build-whisper.bat
..\scripts\download-whisper-assets.bat
..\scripts\run-transcribe-example.bat -Build -WithWhisper
```

Optional environment defaults:

```powershell
$env:OFXGGML_AUDIO_MODEL="C:\path\to\ggml-base.en.bin"
$env:OFXGGML_AUDIO_FILE="C:\path\to\speech.wav"
```

The current native path accepts WAV files, mixes to mono, and resamples to
16 kHz before passing float PCM to whisper.cpp.
