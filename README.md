# ofxGgmlAudio

`ofxGgmlAudio` is the companion addon for speech recognition, transcription,
timestamps, subtitles, diarization, real-time audio inference, denoising, voice
conversion, emotion cues, and voice workflow helpers on top of `ofxGgmlCore`.

`ofxGgmlCore` stays the dependency. This addon owns audio-specific workflow code
so core can stay small and boring.

Family map: https://jonathhhan.github.io/ofxGgmlCore/

Current addon API version: `1.0.1`.

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
scripts\test-whisper-transcribe.bat
scripts\test-whisper-transcribe.bat -DryRun
```

On macOS/Linux:

```sh
./scripts/test-whisper-transcribe.sh
./scripts/test-whisper-transcribe.sh -DryRun
```

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

`ofxGgmlAudioTranscribeExample` is a root-level Whisper transcription example
with editable model/audio paths and `ofLog` output. When timestamped segments
are available, it writes `.srt` and `.vtt` subtitles next to the input WAV.
Generate it with the openFrameworks projectGenerator using addons
`ofxGgmlAudio`, `ofxGgmlCore`, and `ofxImGui`.

For the full fresh-checkout path, see [docs/QUICKSTART.md](docs/QUICKSTART.md).

First run:

```powershell
scripts\doctor-audio.bat
scripts\quickstart-transcribe-example.bat
scripts\quickstart-transcribe-example.bat -DryRun
```

On macOS/Linux:

```sh
./scripts/doctor-audio.sh
./scripts/quickstart-transcribe-example.sh
./scripts/quickstart-transcribe-example.sh -DryRun
```

`doctor-audio` prints the current setup state and the next likely command when
something is missing. The quickstart reuses an installed Whisper runtime when
present, downloads the default tiny model and sample WAV, builds the
openFrameworks example with `-WithWhisper`, then launches it. Use
`-ForceRuntime` to rebuild the optional runtime. For manual control, run the
lower-level scripts directly:

```powershell
scripts\build-whisper.bat
scripts\download-whisper-assets.bat
scripts\run-transcribe-example.bat -Build -WithWhisper
```

On macOS/Linux:

```sh
./scripts/build-whisper.sh
./scripts/download-whisper-assets.sh
./scripts/run-transcribe-example.sh -Build -WithWhisper
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
