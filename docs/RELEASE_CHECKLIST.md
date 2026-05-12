# Release Checklist

Use this before tagging or announcing an `ofxGgmlAudio` release. The goal is to
prove the fresh-checkout path while keeping generated runtime files local.

## Fresh Clone Layout

From the openFrameworks `addons` folder:

```powershell
git clone https://github.com/Jonathhhan/ofxGgmlCore.git
git clone https://github.com/Jonathhhan/ofxGgmlAudio.git
cd ofxGgmlAudio
```

Expected layout:

```text
addons/
  ofxGgmlCore/
  ofxGgmlAudio/
  ofxImGui/
```

## Optional Whisper Runtime

The Whisper backend is opt-in. Runtime files are generated locally:

```powershell
scripts\build-whisper.bat
scripts\download-whisper-assets.bat
```

macOS/Linux:

```sh
./scripts/build-whisper.sh
./scripts/download-whisper-assets.sh
```

Expected generated local paths:

```text
libs/whisper/
models/
audio/
```

These paths must not be staged for release.

## Example Path

Run the new-user path:

```powershell
scripts\doctor-audio.bat
scripts\quickstart-transcribe-example.bat -DryRun
```

When the optional runtime and openFrameworks project files are available:

```powershell
scripts\quickstart-transcribe-example.bat
```

## Local Validation

Run:

```powershell
scripts\validate-local.bat
```

macOS/Linux:

```sh
./scripts/validate-local.sh
```

For a pre-tag release candidate gate:

```powershell
scripts\release-candidate.bat
```

macOS/Linux:

```sh
./scripts/release-candidate.sh
```

## Before Tagging

- `git status --short --ignored` shows only expected ignored local runtime,
  model, audio, or build outputs
- no Whisper runtime binaries, model files, sample audio, generated OF project
  files, or build outputs are staged
- `CHANGELOG.md` has an entry for the release
- `docs/releases/vX.Y.Z.md` matches the release scope
- `README.md` and `docs/QUICKSTART.md` match the actual script names
- the release notes are explicit about which audio tasks are implemented and
  which remain roadmap items
