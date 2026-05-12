# Quickstart

This is the boring path for a fresh `ofxGgmlAudio` checkout: clone the addon,
check the environment, build the optional Whisper runtime, download a tiny model
and sample WAV, then run the transcribe example.

## 1. Folder Layout

Place the addon next to `ofxGgmlCore` and `ofxImGui` inside an openFrameworks
`addons` folder:

```text
openFrameworks/
  addons/
    ofxGgmlCore/
    ofxGgmlAudio/
    ofxImGui/
```

On Windows:

```powershell
cd C:\path\to\openFrameworks\addons
git clone https://github.com/Jonathhhan/ofxGgmlCore
git clone https://github.com/Jonathhhan/ofxGgmlAudio
git clone https://github.com/jvcleave/ofxImGui
cd ofxGgmlAudio
```

On macOS/Linux:

```sh
cd /path/to/openFrameworks/addons
git clone https://github.com/Jonathhhan/ofxGgmlCore
git clone https://github.com/Jonathhhan/ofxGgmlAudio
git clone https://github.com/jvcleave/ofxImGui
cd ofxGgmlAudio
```

## 2. Check Setup State

Run the doctor first. It prints each required piece and the next likely command
if something is missing.

Windows:

```powershell
scripts\doctor-audio.bat
```

macOS/Linux:

```sh
./scripts/doctor-audio.sh
```

If the `ofxGgmlCore ggml runtime` line is missing, build core first:

Windows:

```powershell
..\ofxGgmlCore\scripts\setup-ggml.bat -Auto
```

macOS/Linux:

```sh
../ofxGgmlCore/scripts/setup-ggml.sh -Auto
```

Use `-Cuda` only on a Windows machine with a working CUDA toolkit and Visual
Studio C++ toolchain.

## 3. One Command Quickstart

This builds the optional Whisper runtime if needed, downloads the default
`tiny.en` model and `jfk.wav` sample, builds the example with
`OFXGGMLAUDIO_WITH_WHISPER`, and launches it.

Windows:

```powershell
scripts\quickstart-transcribe-example.bat
```

macOS/Linux:

```sh
./scripts/quickstart-transcribe-example.sh
```

To see the plan without changing files:

```powershell
scripts\quickstart-transcribe-example.bat -DryRun
```

```sh
./scripts/quickstart-transcribe-example.sh -DryRun
```

## 4. Manual Path

Use the lower-level scripts when you want control over each step.

Windows:

```powershell
scripts\build-whisper.bat
scripts\download-whisper-assets.bat
scripts\run-transcribe-example.bat -Build -WithWhisper
```

macOS/Linux:

```sh
./scripts/build-whisper.sh
./scripts/download-whisper-assets.sh
./scripts/run-transcribe-example.sh -Build -WithWhisper
```

## 5. Custom Model And Audio

The example accepts a Whisper `.bin` model and a WAV input. The native path
currently supports 16-bit PCM and 32-bit float WAV files, then mixes to mono and
resamples to 16 kHz for Whisper.

Windows:

```powershell
scripts\run-transcribe-example.bat -Model C:\models\ggml-base.en.bin -Audio C:\audio\speech.wav
```

macOS/Linux:

```sh
./scripts/run-transcribe-example.sh -Model /models/ggml-base.en.bin -Audio /audio/speech.wav
```

You can also set defaults:

```powershell
$env:OFXGGML_AUDIO_MODEL="C:\models\ggml-base.en.bin"
$env:OFXGGML_AUDIO_FILE="C:\audio\speech.wav"
```

```sh
export OFXGGML_AUDIO_MODEL=/models/ggml-base.en.bin
export OFXGGML_AUDIO_FILE=/audio/speech.wav
```

## 6. Validate

Before pushing changes:

Windows:

```powershell
scripts\validate-local.bat
```

macOS/Linux:

```sh
./scripts/validate-local.sh
```

To remove generated Visual Studio, Xcode, make, `bin`, and `obj` files from
the transcribe example after local builds:

```powershell
scripts\clean-transcribe-example.bat
```

```sh
./scripts/clean-transcribe-example.sh
```

## Troubleshooting

- If runtime files are locked on Windows, close running examples and any
  `whisper` process, then rerun the build script.
- If CMake cannot find a compiler, open a Visual Studio Developer PowerShell or
  install the Visual Studio C++ workload.
- If `projectGenerator.exe` exits nonzero after writing the Visual Studio
  project, the build script warns, repairs the generated `.vcxproj`, and
  continues. Treat it as a real failure only when the script stops before
  MSBuild starts.
- If the example says Whisper is unavailable, rebuild or rerun it with
  `-WithWhisper`.
- If the doctor reports missing assets, run `scripts\download-whisper-assets.bat`
  or `./scripts/download-whisper-assets.sh`.
