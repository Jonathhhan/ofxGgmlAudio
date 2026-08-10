# ofxGgmlAudioTranscribeExample

Root-level Whisper transcription example for `ofxGgmlAudio`.

The example has editable model and audio fields, logs the selected paths with
`ofLog`, and runs transcription on a background thread so the UI remains
responsive while whisper.cpp works. Enable `Chunked rolling transcript` to run
the WAV through overlapping stream windows and see the rolling transcript update
after each chunk. Cancel stops between chunks and keeps the transcript produced
so far.

Run the actual example unattended with the same local model and WAV discovery
used by the GUI launcher. `-AutoRun` starts transcription immediately and exits
with a nonzero status on failure; add `-Chunked` to exercise the stream chunker
and rolling transcript path. Successful timestamped runs write `.srt` and
`.vtt` files next to the input WAV.

```powershell
..\scripts\run-transcribe-example.bat -AutoRun
..\scripts\run-transcribe-example.bat -AutoRun -Chunked
```

```sh
../scripts/run-transcribe-example.sh -AutoRun
../scripts/run-transcribe-example.sh -AutoRun -Chunked
```

First run:

Windows:

```powershell
..\scripts\doctor-audio.bat
..\scripts\quickstart-transcribe-example.bat
..\scripts\clean-transcribe-example.bat -DryRun
```

macOS/Linux:

```sh
../scripts/doctor-audio.sh
../scripts/quickstart-transcribe-example.sh
../scripts/clean-transcribe-example.sh -DryRun
```

Use `-Jobs 0` on the quickstart or run script to use all logical cores while
building the example, or a positive value such as `-Jobs 4` for a fixed job
count.

For manual setup, build the optional runtime, download local assets, then
compile the generated project with `OFXGGMLAUDIO_WITH_WHISPER` enabled:

Windows:

```powershell
..\scripts\build-whisper.bat
..\scripts\download-whisper-assets.bat
..\scripts\run-transcribe-example.bat -Build -WithWhisper
```

macOS/Linux:

```sh
../scripts/build-whisper.sh
../scripts/download-whisper-assets.sh
../scripts/run-transcribe-example.sh -Build -WithWhisper
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
16 kHz before passing float PCM to whisper.cpp. Chunked mode uses the same
Whisper backend through `ofxGgmlAudioStreamChunker` and
`ofxGgmlAudioRollingTranscript`.
