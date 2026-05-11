# ofxGgmlSpeech

`ofxGgmlSpeech` is the companion addon for speech recognition, transcription, timestamps, subtitles, diarization, and voice workflow helpers on top of `ofxGgmlCore`.

`ofxGgmlCore` stays the dependency. This addon owns speech-specific workflow code so core can stay small and boring.

Family map: https://jonathhhan.github.io/ofxGgmlCore/

## First Milestone

- define small request/result types
- keep one root-level smoke example
- keep generated models, media, builds, and IDE files out of git
- validate the addon with local headless tests

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

Keep speech-specific preprocessing, postprocessing, model launch, media handling, and examples here. Move code down into `ofxGgmlCore` only when it becomes a stable, domain-neutral primitive with focused tests.
