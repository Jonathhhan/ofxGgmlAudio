param()

$ErrorActionPreference = "Stop"

function Write-Step {
	param([string]$Message)
	Write-Host "==> $Message"
}

function Assert-Path {
	param(
		[string]$Path,
		[string]$Label,
		[switch]$Directory
	)

	if ($Directory) {
		if (!(Test-Path -LiteralPath $Path -PathType Container)) {
			throw "$Label was not found: $Path"
		}
	} elseif (!(Test-Path -LiteralPath $Path -PathType Leaf)) {
		throw "$Label was not found: $Path"
	}
}

function Assert-FileContains {
	param(
		[string]$Path,
		[string]$Pattern,
		[string]$Label
	)

	$content = Get-Content -LiteralPath $Path -Raw
	if ($content -notmatch $Pattern) {
		throw "$Label did not contain expected pattern: $Pattern"
	}
}

function Assert-JsonFile {
	param(
		[string]$Path,
		[string]$Label
	)

	try {
		Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json | Out-Null
	} catch {
		throw "$Label was not valid JSON: $($_.Exception.Message)"
	}
}
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonRoot = Split-Path -Parent $scriptRoot
$addonsRoot = Split-Path -Parent $addonRoot

Write-Step "Checking addon skeleton"
Assert-Path (Join-Path $addonRoot "addon_config.mk") "addon config"
Assert-Path (Join-Path $addonRoot "ofxggml-addon.json") "addon metadata"
Assert-JsonFile (Join-Path $addonRoot "ofxggml-addon.json") "addon metadata"
Assert-Path (Join-Path $addonRoot "README.md") "README"
Assert-Path (Join-Path $addonRoot "LICENSE") "license"
Assert-Path (Join-Path $addonRoot "docs\QUICKSTART.md") "quickstart docs"
Assert-Path (Join-Path $addonRoot "docs\AUDIO_WORKFLOWS.md") "audio workflow docs"
Assert-FileContains (Join-Path $addonRoot "README.md") "docs/QUICKSTART.md" "README"
Assert-FileContains (Join-Path $addonRoot "README.md") "docs/AUDIO_WORKFLOWS.md" "README"
Assert-FileContains (Join-Path $addonRoot "docs\QUICKSTART.md") "scripts\\quickstart-transcribe-example.bat" "quickstart docs"
Assert-FileContains (Join-Path $addonRoot "docs\QUICKSTART.md") "./scripts/quickstart-transcribe-example.sh" "quickstart docs"
Assert-FileContains (Join-Path $addonRoot "docs\QUICKSTART.md") "-Jobs 0" "quickstart docs"
Assert-FileContains (Join-Path $addonRoot "docs\QUICKSTART.md") "projectGenerator.exe" "quickstart docs"
Assert-FileContains (Join-Path $addonRoot "docs\AUDIO_WORKFLOWS.md") "Planning handoff" "audio workflow docs"
Assert-FileContains (Join-Path $addonRoot "docs\AUDIO_WORKFLOWS.md") "Validation ladder" "audio workflow docs"
Assert-FileContains (Join-Path $addonRoot "docs\AUDIO_WORKFLOWS.md") "generated artifacts" "audio workflow docs"
Assert-FileContains (Join-Path $addonRoot "ofxggml-addon.json") '"examples"' "addon metadata"
Assert-FileContains (Join-Path $addonRoot "ofxggml-addon.json") "ofxGgmlAudioTranscribeExample" "addon metadata"
Assert-FileContains (Join-Path $addonRoot "ofxggml-addon.json") "scripts/quickstart-transcribe-example" "addon metadata"
Assert-FileContains (Join-Path $addonRoot "ofxggml-addon.json") "ofxGgmlAudioWhisperExample" "addon metadata"
Assert-FileContains (Join-Path $addonRoot "ofxggml-addon.json") "scripts/quickstart-whisper-example" "addon metadata"
Assert-FileContains (Join-Path $addonRoot "ofxggml-addon.json") "ofxGgmlAudioLiveMicExample" "addon metadata"
Assert-FileContains (Join-Path $addonRoot "ofxggml-addon.json") "scripts/quickstart-live-mic-example" "addon metadata"
Assert-Path (Join-Path $addonRoot "src\ofxGgmlAudio.h") "public header"
Assert-Path (Join-Path $addonRoot "src\ofxGgmlAudioVersion.h") "version header"
Assert-FileContains (Join-Path $addonRoot "src\ofxGgmlAudio.h") "ofxGgmlAudioVersion.h" "public header"
Assert-FileContains (Join-Path $addonRoot "src\ofxGgmlAudioVersion.h") "OFXGGML_AUDIO_VERSION_STRING" "version header"
Assert-Path (Join-Path $addonRoot "src\ofxGgmlAudio\ofxGgmlAudioTypes.h") "types header"
Assert-Path (Join-Path $addonRoot "src\ofxGgmlAudio\ofxGgmlAudioFeatures.h") "features header"
Assert-Path (Join-Path $addonRoot "src\ofxGgmlAudio\ofxGgmlAudioFeatures.cpp") "features source"
Assert-Path (Join-Path $addonRoot "src\ofxGgmlAudio\ofxGgmlAudioStreamChunker.h") "stream chunker header"
Assert-Path (Join-Path $addonRoot "src\ofxGgmlAudio\ofxGgmlAudioStreamChunker.cpp") "stream chunker source"
Assert-Path (Join-Path $addonRoot "src\ofxGgmlAudio\ofxGgmlAudioRollingTranscript.h") "rolling transcript header"
Assert-Path (Join-Path $addonRoot "src\ofxGgmlAudio\ofxGgmlAudioRollingTranscript.cpp") "rolling transcript source"
Assert-FileContains (Join-Path $addonRoot "src\ofxGgmlAudio.h") "ofxGgmlAudioRollingTranscript.h" "public header"
Assert-Path (Join-Path $addonRoot "src\ofxGgmlAudio\ofxGgmlAudioUtils.h") "utility header"
Assert-Path (Join-Path $addonRoot "src\ofxGgmlAudio\ofxGgmlAudioUtils.cpp") "utility source"
Assert-Path (Join-Path $addonRoot "src\ofxGgmlAudio\ofxGgmlAudioWhisperBackend.h") "Whisper backend header"
Assert-Path (Join-Path $addonRoot "src\ofxGgmlAudio\ofxGgmlAudioWhisperBackend.cpp") "Whisper backend source"

Write-Step "Checking dependency layout"
Assert-Path (Join-Path $addonsRoot "ofxGgmlCore") "sibling ofxGgmlCore addon" -Directory
Assert-Path (Join-Path $addonsRoot "ofxImGui") "sibling ofxImGui addon for examples" -Directory

Write-Step "Checking example layout"
$transcribeExampleRoot = Join-Path $addonRoot "ofxGgmlAudioTranscribeExample"
Assert-Path $transcribeExampleRoot "root-level transcribe example" -Directory
Assert-Path (Join-Path $transcribeExampleRoot "addons.make") "transcribe example addons.make"
Assert-FileContains (Join-Path $transcribeExampleRoot "addons.make") "(?m)^ofxImGui\s*$" "transcribe example addons.make"
Assert-Path (Join-Path $transcribeExampleRoot "src\main.cpp") "transcribe example main.cpp"
Assert-Path (Join-Path $transcribeExampleRoot "src\ofApp.h") "transcribe example ofApp.h"
Assert-Path (Join-Path $transcribeExampleRoot "src\ofApp.cpp") "transcribe example ofApp.cpp"
Assert-FileContains (Join-Path $transcribeExampleRoot "src\main.cpp") "ofLogToDebugView" "transcribe example Windows logger setup"
Assert-FileContains (Join-Path $transcribeExampleRoot "src\ofApp.cpp") "gui\.setup\(nullptr, false\)" "transcribe example manual ImGui setup"
Assert-FileContains (Join-Path $transcribeExampleRoot "src\ofApp.h") "runChunkedTranscription" "transcribe example chunked transcription header"
Assert-FileContains (Join-Path $transcribeExampleRoot "src\ofApp.cpp") "Chunked rolling transcript" "transcribe example chunked transcription UI"
Assert-FileContains (Join-Path $transcribeExampleRoot "src\ofApp.cpp") "ofxGgmlAudioRollingTranscript" "transcribe example rolling transcript source"
Assert-FileContains (Join-Path $transcribeExampleRoot "README.md") "..\\scripts\\quickstart-transcribe-example.bat" "transcribe example README"
Assert-FileContains (Join-Path $transcribeExampleRoot "README.md") "../scripts/quickstart-transcribe-example.sh" "transcribe example README"
Assert-FileContains (Join-Path $transcribeExampleRoot "README.md") "OFXGGML_AUDIO_MODEL" "transcribe example README"
Assert-FileContains (Join-Path $transcribeExampleRoot "README.md") "-Jobs 0" "transcribe example README"

$whisperExampleRoot = Join-Path $addonRoot "ofxGgmlAudioWhisperExample"
Assert-Path $whisperExampleRoot "root-level Whisper example" -Directory
Assert-Path (Join-Path $whisperExampleRoot "addons.make") "Whisper example addons.make"
Assert-FileContains (Join-Path $whisperExampleRoot "addons.make") "(?m)^ofxImGui\s*$" "Whisper example addons.make"
Assert-Path (Join-Path $whisperExampleRoot "src\main.cpp") "Whisper example main.cpp"
Assert-Path (Join-Path $whisperExampleRoot "src\ofApp.h") "Whisper example ofApp.h"
Assert-Path (Join-Path $whisperExampleRoot "src\ofApp.cpp") "Whisper example ofApp.cpp"
Assert-FileContains (Join-Path $whisperExampleRoot "src\main.cpp") "ofLogToDebugView" "Whisper example Windows logger setup"
Assert-FileContains (Join-Path $whisperExampleRoot "src\ofApp.cpp") "OFXGGML_AUDIO_EXAMPLE_LOG_MODULE" "Whisper example wrapper source"
Assert-FileContains (Join-Path $whisperExampleRoot "src\ofApp.cpp") "ofxGgmlAudioWhisperExample" "Whisper example wrapper source"
Assert-FileContains (Join-Path $whisperExampleRoot "README.md") "..\\scripts\\quickstart-whisper-example.bat" "Whisper example README"
Assert-FileContains (Join-Path $whisperExampleRoot "README.md") "../scripts/quickstart-whisper-example.sh" "Whisper example README"
Assert-FileContains (Join-Path $whisperExampleRoot "README.md") "OFXGGML_AUDIO_MODEL" "Whisper example README"
Assert-FileContains (Join-Path $whisperExampleRoot "README.md") "-Jobs 0" "Whisper example README"

$liveMicExampleRoot = Join-Path $addonRoot "ofxGgmlAudioLiveMicExample"
Assert-Path $liveMicExampleRoot "root-level live mic example" -Directory
Assert-Path (Join-Path $liveMicExampleRoot "addons.make") "live mic example addons.make"
Assert-FileContains (Join-Path $liveMicExampleRoot "addons.make") "(?m)^ofxImGui\s*$" "live mic example addons.make"
Assert-Path (Join-Path $liveMicExampleRoot "src\main.cpp") "live mic example main.cpp"
Assert-Path (Join-Path $liveMicExampleRoot "src\ofApp.h") "live mic example ofApp.h"
Assert-Path (Join-Path $liveMicExampleRoot "src\ofApp.cpp") "live mic example ofApp.cpp"
Assert-FileContains (Join-Path $liveMicExampleRoot "src\main.cpp") "ofLogToDebugView" "live mic example Windows logger setup"
Assert-FileContains (Join-Path $liveMicExampleRoot "src\ofApp.cpp") "gui\.setup\(nullptr, false\)" "live mic example manual ImGui setup"
Assert-FileContains (Join-Path $liveMicExampleRoot "src\ofApp.cpp") "ofSoundStream" "live mic example audio stream source"
Assert-FileContains (Join-Path $liveMicExampleRoot "src\ofApp.cpp") "chunker\.setup" "live mic example chunker source"
Assert-FileContains (Join-Path $liveMicExampleRoot "src\ofApp.cpp") "estimateVoiceActivity" "live mic example VAD source"
Assert-FileContains (Join-Path $liveMicExampleRoot "README.md") "Live microphone stream example" "live mic example README"
Assert-FileContains (Join-Path $liveMicExampleRoot "README.md") "-Jobs 0" "live mic example README"

Assert-Path (Join-Path $addonRoot "tests\CMakeLists.txt") "test CMakeLists"
Assert-Path (Join-Path $addonRoot "tests\test_main.cpp") "test source"
Assert-Path (Join-Path $addonRoot "tests\test_whisper_smoke.cpp") "Whisper smoke test source"
Assert-Path (Join-Path $addonRoot "tests\test_whisper_chunked_smoke.cpp") "Whisper chunked smoke test source"
Assert-Path (Join-Path $scriptRoot "build-whisper.ps1") "Whisper build script"
Assert-Path (Join-Path $scriptRoot "build-whisper.bat") "Whisper Windows build wrapper"
Assert-Path (Join-Path $scriptRoot "build-whisper.sh") "Whisper shell build wrapper"
Assert-Path (Join-Path $scriptRoot "setup-whisper.ps1") "Whisper setup script"
Assert-Path (Join-Path $scriptRoot "setup-whisper.bat") "Whisper Windows setup wrapper"
Assert-Path (Join-Path $scriptRoot "setup-whisper.sh") "Whisper shell setup wrapper"
Assert-Path (Join-Path $scriptRoot "doctor-audio.ps1") "Audio doctor script"
Assert-Path (Join-Path $scriptRoot "doctor-audio.bat") "Audio doctor Windows wrapper"
Assert-Path (Join-Path $scriptRoot "doctor-audio.sh") "Audio doctor shell wrapper"
Assert-Path (Join-Path $scriptRoot "test-doctor-audio.ps1") "Audio doctor smoke test"
Assert-Path (Join-Path $scriptRoot "test-doctor-audio.bat") "Audio doctor smoke test Windows wrapper"
Assert-Path (Join-Path $scriptRoot "test-doctor-audio.sh") "Audio doctor smoke test shell wrapper"
Assert-Path (Join-Path $scriptRoot "test-whisper-setup-dry-run.ps1") "Whisper setup dry-run test"
Assert-Path (Join-Path $scriptRoot "test-whisper-setup-dry-run.bat") "Whisper setup dry-run Windows wrapper"
Assert-Path (Join-Path $scriptRoot "test-whisper-setup-dry-run.sh") "Whisper setup dry-run shell wrapper"
Assert-Path (Join-Path $scriptRoot "download-whisper-assets.ps1") "Whisper asset download script"
Assert-Path (Join-Path $scriptRoot "download-whisper-assets.bat") "Whisper asset download Windows wrapper"
Assert-Path (Join-Path $scriptRoot "download-whisper-assets.sh") "Whisper asset download shell wrapper"
Assert-Path (Join-Path $scriptRoot "test-whisper-assets-dry-run.ps1") "Whisper asset dry-run test"
Assert-Path (Join-Path $scriptRoot "test-whisper-assets-dry-run.bat") "Whisper asset dry-run Windows wrapper"
Assert-Path (Join-Path $scriptRoot "test-whisper-assets-dry-run.sh") "Whisper asset dry-run shell wrapper"
Assert-Path (Join-Path $scriptRoot "test-whisper-transcribe.ps1") "Whisper transcription smoke script"
Assert-Path (Join-Path $scriptRoot "test-whisper-transcribe.bat") "Whisper transcription smoke Windows wrapper"
Assert-Path (Join-Path $scriptRoot "test-whisper-transcribe.sh") "Whisper transcription smoke shell wrapper"
Assert-Path (Join-Path $scriptRoot "test-whisper-chunked-transcribe.ps1") "Whisper chunked transcription smoke script"
Assert-Path (Join-Path $scriptRoot "test-whisper-chunked-transcribe.bat") "Whisper chunked transcription smoke Windows wrapper"
Assert-Path (Join-Path $scriptRoot "test-whisper-chunked-transcribe.sh") "Whisper chunked transcription smoke shell wrapper"
Assert-Path (Join-Path $scriptRoot "run-audio-runtime-smoke.ps1") "Audio runtime smoke script"
Assert-Path (Join-Path $scriptRoot "run-audio-runtime-smoke.bat") "Audio runtime smoke Windows wrapper"
Assert-Path (Join-Path $scriptRoot "run-audio-runtime-smoke.sh") "Audio runtime smoke shell wrapper"
Assert-Path (Join-Path $scriptRoot "test-audio-runtime-smoke.ps1") "Audio runtime smoke contract test"
Assert-Path (Join-Path $scriptRoot "build-transcribe-example.ps1") "transcribe example build script"
Assert-FileContains (Join-Path $scriptRoot "build-transcribe-example.ps1") "OFXIMGUI_GLFW_EVENTS_REPLACE_OF_CALLBACKS=0" "transcribe example build script ImGui backend flags"
Assert-FileContains (Join-Path $scriptRoot "build-transcribe-example.ps1") "Remove-CompilerDefinition" "transcribe example build script stale ImGui flag cleanup"
Assert-Path (Join-Path $scriptRoot "build-transcribe-example.bat") "transcribe example Windows build wrapper"
Assert-Path (Join-Path $scriptRoot "build-transcribe-example.sh") "transcribe example shell build wrapper"
Assert-Path (Join-Path $scriptRoot "build-whisper-example.ps1") "Whisper example build script"
Assert-Path (Join-Path $scriptRoot "build-whisper-example.bat") "Whisper example Windows build wrapper"
Assert-Path (Join-Path $scriptRoot "build-whisper-example.sh") "Whisper example shell build wrapper"
Assert-Path (Join-Path $scriptRoot "build-live-mic-example.ps1") "live mic example build script"
Assert-Path (Join-Path $scriptRoot "build-live-mic-example.bat") "live mic example Windows build wrapper"
Assert-Path (Join-Path $scriptRoot "build-live-mic-example.sh") "live mic example shell build wrapper"
Assert-Path (Join-Path $scriptRoot "clean-transcribe-example.ps1") "transcribe example clean script"
Assert-Path (Join-Path $scriptRoot "clean-transcribe-example.bat") "transcribe example clean Windows wrapper"
Assert-Path (Join-Path $scriptRoot "clean-transcribe-example.sh") "transcribe example clean shell wrapper"
Assert-Path (Join-Path $scriptRoot "clean-whisper-example.ps1") "Whisper example clean script"
Assert-Path (Join-Path $scriptRoot "clean-whisper-example.bat") "Whisper example clean Windows wrapper"
Assert-Path (Join-Path $scriptRoot "clean-whisper-example.sh") "Whisper example clean shell wrapper"
Assert-Path (Join-Path $scriptRoot "clean-live-mic-example.ps1") "live mic example clean script"
Assert-Path (Join-Path $scriptRoot "clean-live-mic-example.bat") "live mic example clean Windows wrapper"
Assert-Path (Join-Path $scriptRoot "clean-live-mic-example.sh") "live mic example clean shell wrapper"
Assert-Path (Join-Path $scriptRoot "test-clean-transcribe-example.ps1") "example clean regression test"
Assert-Path (Join-Path $scriptRoot "test-clean-transcribe-example.bat") "example clean regression Windows wrapper"
Assert-Path (Join-Path $scriptRoot "test-clean-transcribe-example.sh") "example clean regression shell wrapper"
Assert-Path (Join-Path $scriptRoot "run-transcribe-example.ps1") "transcribe example run script"
Assert-Path (Join-Path $scriptRoot "run-transcribe-example.bat") "transcribe example Windows run wrapper"
Assert-Path (Join-Path $scriptRoot "run-transcribe-example.sh") "transcribe example shell run wrapper"
Assert-Path (Join-Path $scriptRoot "run-whisper-example.ps1") "Whisper example run script"
Assert-Path (Join-Path $scriptRoot "run-whisper-example.bat") "Whisper example Windows run wrapper"
Assert-Path (Join-Path $scriptRoot "run-whisper-example.sh") "Whisper example shell run wrapper"
Assert-Path (Join-Path $scriptRoot "run-live-mic-example.ps1") "live mic example run script"
Assert-Path (Join-Path $scriptRoot "run-live-mic-example.bat") "live mic example Windows run wrapper"
Assert-Path (Join-Path $scriptRoot "run-live-mic-example.sh") "live mic example shell run wrapper"
Assert-Path (Join-Path $scriptRoot "quickstart-transcribe-example.ps1") "transcribe quickstart script"
Assert-Path (Join-Path $scriptRoot "quickstart-transcribe-example.bat") "transcribe quickstart Windows wrapper"
Assert-Path (Join-Path $scriptRoot "quickstart-transcribe-example.sh") "transcribe quickstart shell wrapper"
Assert-Path (Join-Path $scriptRoot "quickstart-whisper-example.ps1") "Whisper quickstart script"
Assert-Path (Join-Path $scriptRoot "quickstart-whisper-example.bat") "Whisper quickstart Windows wrapper"
Assert-Path (Join-Path $scriptRoot "quickstart-whisper-example.sh") "Whisper quickstart shell wrapper"
Assert-Path (Join-Path $scriptRoot "quickstart-live-mic-example.ps1") "live mic quickstart script"
Assert-Path (Join-Path $scriptRoot "quickstart-live-mic-example.bat") "live mic quickstart Windows wrapper"
Assert-Path (Join-Path $scriptRoot "quickstart-live-mic-example.sh") "live mic quickstart shell wrapper"
Assert-Path (Join-Path $scriptRoot "test-launch-dry-run.ps1") "example launch dry-run test"
Assert-Path (Join-Path $scriptRoot "test-launch-dry-run.bat") "example launch dry-run Windows wrapper"
Assert-Path (Join-Path $scriptRoot "test-launch-dry-run.sh") "example launch dry-run shell wrapper"
Assert-Path (Join-Path $scriptRoot "test-transcribe-quickstart-dry-run.ps1") "example quickstart dry-run test"
Assert-Path (Join-Path $scriptRoot "test-transcribe-quickstart-dry-run.bat") "example quickstart dry-run Windows wrapper"
Assert-Path (Join-Path $scriptRoot "test-transcribe-quickstart-dry-run.sh") "example quickstart dry-run shell wrapper"
Assert-Path (Join-Path $addonRoot "libs\whisper\bin\.gitkeep") "Whisper bin placeholder"
Assert-Path (Join-Path $addonRoot "libs\whisper\include\.gitkeep") "Whisper include placeholder"
Assert-Path (Join-Path $addonRoot "libs\whisper\lib\.gitkeep") "Whisper lib placeholder"

foreach ($shellWrapper in Get-ChildItem -LiteralPath $scriptRoot -Filter "*.sh" -File) {
	Assert-FileContains $shellWrapper.FullName "ExecutionPolicy Bypass" "shell wrapper $($shellWrapper.Name)"
}

$nestedExamples = Join-Path $addonRoot "examples"
if (Test-Path -LiteralPath $nestedExamples -PathType Container) {
	throw "Examples should live at the addon root, not under: $nestedExamples"
}

Write-Step "Checking generated artifact hygiene"
$forbidden = @(
	"build",
	".vs",
	"ofxGgmlAudioTranscribeExample\bin",
	"ofxGgmlAudioTranscribeExample\obj",
	"ofxGgmlAudioTranscribeExample\.vs",
	"ofxGgmlAudioWhisperExample\bin",
	"ofxGgmlAudioWhisperExample\obj",
	"ofxGgmlAudioWhisperExample\.vs",
	"ofxGgmlAudioLiveMicExample\bin",
	"ofxGgmlAudioLiveMicExample\obj",
	"ofxGgmlAudioLiveMicExample\.vs",
	"libs\whisper\.source",
	"libs\whisper\build"
)

foreach ($relative in $forbidden) {
	$status = @(& git -C $addonRoot status --short -- $relative 2>$null)
	if ($LASTEXITCODE -ne 0) {
		throw "Could not inspect git status for artifact hygiene path: $relative"
	}
	if ($status.Count -gt 0) {
		throw "Generated or local-only path should not be committed here: $relative`n$($status -join "`n")"
	}
}

Assert-FileContains (Join-Path $addonRoot ".gitignore") "(?m)^models/\s*$" "gitignore"
Assert-FileContains (Join-Path $addonRoot ".gitignore") "(?m)^audio/\s*$" "gitignore"

Write-Step "Checking audio doctor report"
& (Join-Path $scriptRoot "test-doctor-audio.ps1")

Write-Step "Checking whisper.cpp setup dry-runs"
& (Join-Path $scriptRoot "test-whisper-setup-dry-run.ps1")

Write-Step "Checking Whisper asset download dry-runs"
& (Join-Path $scriptRoot "test-whisper-assets-dry-run.ps1")

Write-Step "Checking Whisper transcription smoke dry-run"
$whisperSmokeDryRun = & (Join-Path $scriptRoot "test-whisper-transcribe.ps1") -DryRun 2>&1 6>&1 | Out-String
if (!$whisperSmokeDryRun.Contains("Whisper transcription smoke plan") -or
	!$whisperSmokeDryRun.Contains("expected text: ask not") -or
	!$whisperSmokeDryRun.Contains("Dry run complete; no files were changed")) {
	throw "Whisper transcription smoke dry-run output was unexpected:`n$whisperSmokeDryRun"
}

Write-Step "Checking Whisper chunked transcription smoke dry-run"
$whisperChunkedSmokeDryRun = & (Join-Path $scriptRoot "test-whisper-chunked-transcribe.ps1") -DryRun 2>&1 6>&1 | Out-String
if (!$whisperChunkedSmokeDryRun.Contains("Whisper chunked transcription smoke plan") -or
	!$whisperChunkedSmokeDryRun.Contains("expected text: ask not") -or
	!$whisperChunkedSmokeDryRun.Contains("Dry run complete; no files were changed")) {
	throw "Whisper chunked transcription smoke dry-run output was unexpected:`n$whisperChunkedSmokeDryRun"
}

Write-Step "Checking Audio runtime smoke contract"
& (Join-Path $scriptRoot "test-audio-runtime-smoke.ps1")
if ($LASTEXITCODE -ne 0) {
	throw "Audio runtime smoke contract failed with exit code $LASTEXITCODE"
}

Write-Step "Checking example launch dry-runs"
& (Join-Path $scriptRoot "test-launch-dry-run.ps1")

Write-Step "Checking example clean dry-runs"
& (Join-Path $scriptRoot "test-clean-transcribe-example.ps1")

Write-Step "Checking example quickstart dry-runs"
& (Join-Path $scriptRoot "test-transcribe-quickstart-dry-run.ps1")

Write-Step "Running headless tests"
& (Join-Path $scriptRoot "test-addon.ps1")
if ($LASTEXITCODE -ne 0) {
	throw "Headless tests failed with exit code $LASTEXITCODE"
}

Write-Step "ofxGgmlAudio local validation passed"
