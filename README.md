# ofxGgmlSpeech

`ofxGgmlSpeech` is the companion addon for speech recognition, transcription, timestamps, subtitles, diarization, and voice workflow helpers on top of `ofxGgmlCore`.

`ofxGgmlCore` stays the dependency. This addon owns speech-specific workflow code so core can stay small and boring.

Family map: https://jonathhhan.github.io/ofxGgmlCore/

## First Milestone

- define small request/result types
- keep one root-level smoke example
- keep whisper.cpp as the first explicit backend, not a separate addon
- keep generated models, media, builds, and IDE files out of git
- validate the addon with local headless tests

## Whisper Backend

`whisper.cpp` belongs here as the first opt-in speech backend. Keep the public
request/result API generic, then plug concrete Whisper setup and transcription
behind `ofxGgmlSpeechWhisperBackend`.

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

Compile app projects with `OFXGGMLSPEECH_WITH_WHISPER` after generating the
runtime. Until then, the backend compiles as a clear unavailable stub.

## Example

`ofxGgmlSpeechTranscribeExample` is a root-level transcription request smoke test. Generate it with the openFrameworks projectGenerator using addons `ofxGgmlSpeech`, `ofxGgmlCore`, and `ofxImGui`.

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

Keep speech-specific preprocessing, postprocessing, model launch, media handling,
Whisper integration, and examples here. Move code down into `ofxGgmlCore` only
when it becomes a stable, domain-neutral primitive with focused tests.
