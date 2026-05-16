# ofxGgmlAudioWhisperExample

Root-level Whisper example for `ofxGgmlAudio`.

This example uses the same native whisper.cpp backend as the transcribe example,
but exposes it under an explicit Whisper example name for agent and project
workflows. It has editable model/audio fields, language, threads, translation,
timestamps, and chunked rolling transcript mode. Transcription runs on a
background thread so the UI remains responsive.

First run:

Windows:

```powershell
..\scripts\doctor-audio.bat
..\scripts\build-whisper-example.bat -WithWhisper
..\scripts\run-whisper-example.bat
```

macOS/Linux:

```sh
../scripts/doctor-audio.sh
../scripts/build-whisper-example.sh -WithWhisper
../scripts/run-whisper-example.sh
```

Optional environment defaults:

Windows:

```powershell
$env:OFXGGML_AUDIO_MODEL="C:\path\to\ggml-base.en.bin"
$env:OFXGGML_AUDIO_FILE="C:\path\to\speech.wav"
```

macOS/Linux:

```sh
export OFXGGML_AUDIO_MODEL=/path/to/ggml-base.en.bin
export OFXGGML_AUDIO_FILE=/path/to/speech.wav
```

The current native path accepts WAV files, mixes to mono, and resamples to
16 kHz before passing float PCM to whisper.cpp. Chunked mode uses
`ofxGgmlAudioStreamChunker` and `ofxGgmlAudioRollingTranscript`.
