# ofxGgmlAudioLiveMicExample

Live microphone stream example for `ofxGgmlAudio`.

This example captures mono microphone input with `ofSoundStream`, pushes it
through `ofxGgmlAudioStreamChunker`, and displays deterministic audio features
plus the baseline voice-activity estimate. It does not claim model-backed
transcription; use the Whisper examples for file and chunked Whisper runtime
validation.

The UI includes live input meters, RMS/VAD history plots, adjustable chunk
window/hop settings, and tweakable VAD thresholds so you can calibrate the
baseline detector against the current microphone and room. Press Space to pause
or resume capture, and press C to reset the chunker, counters, plots, and recent
chunk log.

Build and launch it with:

```powershell
..\scripts\quickstart-live-mic-example.bat
```

On macOS/Linux:

```sh
../scripts/quickstart-live-mic-example.sh
```

Use `-Jobs 0` on the quickstart or run script to use all logical cores while
building the example, or a positive value such as `-Jobs 4` for a fixed job
count.

Clean generated project/build artifacts with:

```powershell
..\scripts\clean-live-mic-example.bat
```

On macOS/Linux:

```sh
../scripts/clean-live-mic-example.sh
```

Generate it with openFrameworks projectGenerator using:

```txt
ofxGgmlCore
ofxGgmlAudio
ofxImGui
```
