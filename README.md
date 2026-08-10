# ofxGgmlAudio

`ofxGgmlAudio` is the companion addon for speech recognition, transcription,
timestamps, subtitles, diarization, real-time audio inference, denoising, voice
conversion, emotion cues, and voice workflow helpers on top of `ofxGgmlCore`.

`ofxGgmlCore` stays the dependency. This addon owns audio-specific workflow code
so core can stay small and boring.

Family map: https://jonathhhan.github.io/ofxGgmlCore/

Current addon API version: `1.0.1`.

## Features

- Whisper transcription
- chunked transcription
- audio feature helpers
- asset and setup dry-run workflows
- model-backed runtime smoke evidence

## First Milestone

- define small request/result types
- keep one root-level smoke example
- keep whisper.cpp as the first explicit backend, not a separate addon
- keep Whisper as one module inside the broader audio lane
- keep generated models, media, builds, and IDE files out of git
- validate the addon with local headless tests

## Audio Scope

The lane should not stop at transcription. Planned audio tasks include:

- real-time audio stream inference
- speech-to-text and subtitle/timestamp workflows
- denoising, enhancement, and source cleanup
- voice conversion and voice effects
- speaker, emotion, turn-taking, and conversational-agent audio cues
- VAD and lightweight audio event detection

The public API now has a backend-neutral stream request shape for those tasks:
`ofxGgmlAudioStreamRequest`, `ofxGgmlAudioStreamResult`,
`ofxGgmlAudioStreamFormat`, and `ofxGgmlAudioTask`. Concrete backends can map
those plain C++ types to Whisper, denoisers, classifiers, or voice models
without changing the Core addon.

For live input, `ofxGgmlAudioStreamChunker` accumulates interleaved float audio
and emits fixed-size overlapping stream requests. That keeps model windowing,
hop size, and timestamp handling out of examples and backend adapters.
`ofxGgmlAudioRollingTranscript` then collects timestamped chunk results,
deduplicates repeated overlap segments, and exports the current transcript as
plain text, SRT, or WebVTT.
`ofxGgmlAudioFeatures` adds small RMS, peak, zero-crossing, and mean helpers for
quick VAD gates, meters, smoke tests, and lightweight classifier inputs.
It also includes `estimateVoiceActivity()` as a deterministic baseline gate
before a model-backed VAD is available.

## Whisper Backend

`whisper.cpp` belongs here as the first opt-in speech backend. Keep the public
request/result API generic, then plug concrete Whisper setup and transcription
behind `ofxGgmlAudioWhisperBackend`.

Runtime files are generated locally:

```powershell
scripts\build-whisper.bat
scripts\build-whisper.bat -DryRun
scripts\build-whisper.bat -CpuOnly
scripts\build-whisper.bat -BundledGgml
```

The script defaults to `-Auto`, generates a small CMake package for the sibling
`ofxGgmlCore` ggml install, and installs generated files under `libs/whisper`.
Pass `-BundledGgml` only for upstream experiments where whisper.cpp should
build against its own ggml copy.

Compile app projects with `OFXGGMLAUDIO_WITH_WHISPER` after generating the
runtime. The transcribe build script exposes this as `-WithWhisper` and copies
`whisper.dll` next to the example executable on Windows. Until then, the
backend compiles as a clear unavailable stub.

Models and sample media are also local-only:

```powershell
scripts\download-whisper-assets.bat
scripts\download-whisper-assets.bat -DryRun
scripts\download-whisper-assets.bat -Model base.en
```

By default this downloads `models\ggml-tiny.en.bin` from
`ggerganov/whisper.cpp` on Hugging Face and `audio\jfk.wav` from
`ggml-org/whisper.cpp`.

After building the runtime and downloading assets, run the headless smoke test
to verify real transcription without opening the openFrameworks example:

```powershell
scripts\run-audio-runtime-smoke.bat -DryRun
scripts\run-audio-runtime-smoke.bat -Mode simple -Json -SummaryOnly
scripts\run-audio-runtime-smoke.bat -Mode chunked -Json -SummaryOnly
scripts\test-whisper-transcribe.bat
scripts\test-whisper-chunked-transcribe.bat
scripts\test-whisper-transcribe.bat -DryRun
scripts\test-whisper-chunked-transcribe.bat -DryRun
scripts\test-example-startup.bat
scripts\test-example-startup.bat -DryRun
scripts\run-transcribe-example.bat -AutoRun
scripts\run-transcribe-example.bat -AutoRun -Chunked
```

On macOS/Linux:

```sh
./scripts/run-audio-runtime-smoke.sh -DryRun
./scripts/run-audio-runtime-smoke.sh -Mode simple -Json -SummaryOnly
./scripts/run-audio-runtime-smoke.sh -Mode chunked -Json -SummaryOnly
./scripts/test-whisper-transcribe.sh
./scripts/test-whisper-chunked-transcribe.sh
./scripts/test-whisper-transcribe.sh -DryRun
./scripts/test-whisper-chunked-transcribe.sh -DryRun
./scripts/test-example-startup.sh
./scripts/test-example-startup.sh -DryRun
./scripts/run-transcribe-example.sh -AutoRun
./scripts/run-transcribe-example.sh -AutoRun -Chunked
```

The chunked smoke test runs the same sample WAV through
`ofxGgmlAudioStreamChunker`, `ofxGgmlAudioWhisperBackend`, and
`ofxGgmlAudioRollingTranscript`, then verifies text plus subtitle export. Use it
when changing live-stream, overlap, or rolling transcript code.
The example startup smoke launches the GUI examples long enough to catch
startup crashes, then closes them.
The transcribe launcher `-AutoRun` mode executes the example's real file path
without UI input and exits when inference finishes. Adding `-Chunked` executes
the example's stream chunker and rolling transcript path instead.

The first native transcription path is intentionally narrow: `transcribe()`
accepts WAV files with 16-bit PCM or 32-bit float samples, mixes multi-channel
input to mono, linearly resamples to Whisper's 16 kHz input rate, and passes
float PCM to whisper.cpp. Other file types fail with explicit errors until
broader decoding is added. Successful transcriptions now return
`ofxGgmlAudioTranscriptSegment` entries with start/end timestamps when the
backend provides them. `ofxGgmlAudioUtils::buildSrt()`,
`buildWebVtt()`, `writeSrtFile()`, and `writeWebVttFile()` convert those
segments into subtitle files.

## Example

`ofxGgmlAudioWhisperExample` is the explicit root-level Whisper example. It has
editable model/audio paths, language, threads, translation, timestamps, chunked
rolling transcript mode, and `ofLog` output. `ofxGgmlAudioTranscribeExample`
keeps the same backend path under the older transcribe example name. When
timestamped segments are available, the shared example UI writes `.srt` and
`.vtt` subtitles next to the input WAV. Generate either example with the
openFrameworks projectGenerator using addons `ofxGgmlAudio`, `ofxGgmlCore`, and
`ofxImGui`.

`ofxGgmlAudioLiveMicExample` is the dedicated live microphone stream example.
It captures mono mic input, feeds `ofxGgmlAudioStreamChunker`, and displays
RMS/peak/zero-crossing features plus the deterministic voice-activity baseline.
It intentionally does not claim model-backed live transcription yet; use the
Whisper examples for model-backed file and chunked transcription evidence.
Use `scripts\quickstart-live-mic-example.bat` or
`./scripts/quickstart-live-mic-example.sh` to build and launch it.

The example Runtime panel reports whether Whisper is compiled and loaded, the
CPU/GPU acceleration flags reported by whisper.cpp, the loaded model path, and
the effective CPU worker thread count. The threads control is not a CPU-only
mode switch; it only controls CPU work scheduling while GPU use comes from the
compiled Whisper/ggml runtime.

For the full fresh-checkout path, see [docs/QUICKSTART.md](docs/QUICKSTART.md).
For audio-lane planning and future backend boundaries, see
[docs/AUDIO_WORKFLOWS.md](docs/AUDIO_WORKFLOWS.md).

First run:

```powershell
scripts\doctor-audio.bat
scripts\run-audio-runtime-smoke.bat -DryRun
scripts\build-whisper-example.bat -WithWhisper
scripts\run-whisper-example.bat
scripts\quickstart-whisper-example.bat -DryRun
scripts\quickstart-live-mic-example.bat -DryRun
scripts\quickstart-live-mic-example.bat
scripts\clean-live-mic-example.bat -DryRun
scripts\quickstart-transcribe-example.bat
scripts\quickstart-transcribe-example.bat -DryRun
```

On macOS/Linux:

```sh
./scripts/doctor-audio.sh
./scripts/quickstart-whisper-example.sh -DryRun
./scripts/quickstart-live-mic-example.sh -DryRun
./scripts/quickstart-live-mic-example.sh
./scripts/clean-live-mic-example.sh -DryRun
./scripts/quickstart-transcribe-example.sh
./scripts/quickstart-transcribe-example.sh -DryRun
```

`doctor-audio` prints the current setup state and the next likely command when
something is missing. The quickstart reuses an installed Whisper runtime when
present, downloads the default tiny model and sample WAV, builds the
openFrameworks Whisper examples with `-WithWhisper`, then launches the selected
example. The live mic quickstart skips Whisper runtime and asset setup. Use
`-ForceRuntime` to rebuild the optional runtime. Add `-Jobs 0` to example
quickstarts or run scripts to use all logical cores for the example build, or a
positive value such as `-Jobs 4` for a fixed job count. For manual control, run
the lower-level scripts directly:

```powershell
scripts\build-whisper.bat
scripts\download-whisper-assets.bat
scripts\run-transcribe-example.bat -Build -WithWhisper
scripts\run-whisper-example.bat -Build -WithWhisper
scripts\run-live-mic-example.bat -Build
scripts\run-live-mic-example.bat -AutoRun
```

On macOS/Linux:

```sh
./scripts/build-whisper.sh
./scripts/download-whisper-assets.sh
./scripts/run-transcribe-example.sh -Build -WithWhisper
./scripts/run-whisper-example.sh -Build -WithWhisper
./scripts/run-live-mic-example.sh -Build
./scripts/run-live-mic-example.sh -AutoRun
```

## Dependencies

- openFrameworks
- `ofxGgmlCore`
- `ofxImGui` for examples

## Validate

```powershell
scripts\validate-local.bat
```

On macOS/Linux:

```sh
./scripts/validate-local.sh
```

## Boundary

Keep audio-specific preprocessing, postprocessing, model launch, media handling,
Whisper integration, and examples here. Move code down into `ofxGgmlCore` only
when it becomes a stable, domain-neutral primitive with focused tests.
