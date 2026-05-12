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
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonRoot = Split-Path -Parent $scriptRoot
$addonsRoot = Split-Path -Parent $addonRoot

Write-Step "Checking addon skeleton"
Assert-Path (Join-Path $addonRoot "addon_config.mk") "addon config"
Assert-Path (Join-Path $addonRoot "README.md") "README"
Assert-Path (Join-Path $addonRoot "LICENSE") "license"
Assert-Path (Join-Path $addonRoot "docs\QUICKSTART.md") "quickstart docs"
Assert-FileContains (Join-Path $addonRoot "README.md") "docs/QUICKSTART.md" "README"
Assert-FileContains (Join-Path $addonRoot "docs\QUICKSTART.md") "scripts\\quickstart-transcribe-example.bat" "quickstart docs"
Assert-FileContains (Join-Path $addonRoot "docs\QUICKSTART.md") "./scripts/quickstart-transcribe-example.sh" "quickstart docs"
Assert-FileContains (Join-Path $addonRoot "docs\QUICKSTART.md") "projectGenerator.exe" "quickstart docs"
Assert-Path (Join-Path $addonRoot "src\ofxGgmlAudio.h") "public header"
Assert-Path (Join-Path $addonRoot "src\ofxGgmlAudio\ofxGgmlAudioTypes.h") "types header"
Assert-Path (Join-Path $addonRoot "src\ofxGgmlAudio\ofxGgmlAudioFeatures.h") "features header"
Assert-Path (Join-Path $addonRoot "src\ofxGgmlAudio\ofxGgmlAudioFeatures.cpp") "features source"
Assert-Path (Join-Path $addonRoot "src\ofxGgmlAudio\ofxGgmlAudioStreamChunker.h") "stream chunker header"
Assert-Path (Join-Path $addonRoot "src\ofxGgmlAudio\ofxGgmlAudioStreamChunker.cpp") "stream chunker source"
Assert-Path (Join-Path $addonRoot "src\ofxGgmlAudio\ofxGgmlAudioUtils.h") "utility header"
Assert-Path (Join-Path $addonRoot "src\ofxGgmlAudio\ofxGgmlAudioUtils.cpp") "utility source"
Assert-Path (Join-Path $addonRoot "src\ofxGgmlAudio\ofxGgmlAudioWhisperBackend.h") "Whisper backend header"
Assert-Path (Join-Path $addonRoot "src\ofxGgmlAudio\ofxGgmlAudioWhisperBackend.cpp") "Whisper backend source"

Write-Step "Checking dependency layout"
Assert-Path (Join-Path $addonsRoot "ofxGgmlCore") "sibling ofxGgmlCore addon" -Directory
Assert-Path (Join-Path $addonsRoot "ofxImGui") "sibling ofxImGui addon for examples" -Directory

Write-Step "Checking example layout"
$exampleRoot = Join-Path $addonRoot "ofxGgmlAudioTranscribeExample"
Assert-Path $exampleRoot "root-level smoke example" -Directory
Assert-Path (Join-Path $exampleRoot "addons.make") "smoke example addons.make"
Assert-FileContains (Join-Path $exampleRoot "addons.make") "(?m)^ofxImGui\s*$" "smoke example addons.make"
Assert-Path (Join-Path $exampleRoot "src\main.cpp") "smoke example main.cpp"
Assert-Path (Join-Path $exampleRoot "src\ofApp.h") "smoke example ofApp.h"
Assert-Path (Join-Path $exampleRoot "src\ofApp.cpp") "smoke example ofApp.cpp"
Assert-Path (Join-Path $addonRoot "tests\CMakeLists.txt") "test CMakeLists"
Assert-Path (Join-Path $addonRoot "tests\test_main.cpp") "test source"
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
Assert-Path (Join-Path $scriptRoot "build-transcribe-example.ps1") "transcribe example build script"
Assert-Path (Join-Path $scriptRoot "build-transcribe-example.bat") "transcribe example Windows build wrapper"
Assert-Path (Join-Path $scriptRoot "build-transcribe-example.sh") "transcribe example shell build wrapper"
Assert-Path (Join-Path $scriptRoot "clean-transcribe-example.ps1") "transcribe example clean script"
Assert-Path (Join-Path $scriptRoot "clean-transcribe-example.bat") "transcribe example clean Windows wrapper"
Assert-Path (Join-Path $scriptRoot "clean-transcribe-example.sh") "transcribe example clean shell wrapper"
Assert-Path (Join-Path $scriptRoot "run-transcribe-example.ps1") "transcribe example run script"
Assert-Path (Join-Path $scriptRoot "run-transcribe-example.bat") "transcribe example Windows run wrapper"
Assert-Path (Join-Path $scriptRoot "run-transcribe-example.sh") "transcribe example shell run wrapper"
Assert-Path (Join-Path $scriptRoot "quickstart-transcribe-example.ps1") "transcribe quickstart script"
Assert-Path (Join-Path $scriptRoot "quickstart-transcribe-example.bat") "transcribe quickstart Windows wrapper"
Assert-Path (Join-Path $scriptRoot "quickstart-transcribe-example.sh") "transcribe quickstart shell wrapper"
Assert-Path (Join-Path $scriptRoot "test-launch-dry-run.ps1") "transcribe example launch dry-run test"
Assert-Path (Join-Path $scriptRoot "test-launch-dry-run.bat") "transcribe example launch dry-run Windows wrapper"
Assert-Path (Join-Path $scriptRoot "test-launch-dry-run.sh") "transcribe example launch dry-run shell wrapper"
Assert-Path (Join-Path $scriptRoot "test-transcribe-quickstart-dry-run.ps1") "transcribe quickstart dry-run test"
Assert-Path (Join-Path $scriptRoot "test-transcribe-quickstart-dry-run.bat") "transcribe quickstart dry-run Windows wrapper"
Assert-Path (Join-Path $scriptRoot "test-transcribe-quickstart-dry-run.sh") "transcribe quickstart dry-run shell wrapper"
Assert-Path (Join-Path $addonRoot "libs\whisper\bin\.gitkeep") "Whisper bin placeholder"
Assert-Path (Join-Path $addonRoot "libs\whisper\include\.gitkeep") "Whisper include placeholder"
Assert-Path (Join-Path $addonRoot "libs\whisper\lib\.gitkeep") "Whisper lib placeholder"

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
	"libs\whisper\.source",
	"libs\whisper\build"
)

foreach ($relative in $forbidden) {
	$path = Join-Path $addonRoot $relative
	if (Test-Path -LiteralPath $path) {
		throw "Generated or local-only path should not be committed here: $relative"
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

Write-Step "Checking transcribe example launch dry-runs"
& (Join-Path $scriptRoot "test-launch-dry-run.ps1")

Write-Step "Checking transcribe example clean dry-run"
& (Join-Path $scriptRoot "clean-transcribe-example.ps1") -DryRun

Write-Step "Checking transcribe quickstart dry-runs"
& (Join-Path $scriptRoot "test-transcribe-quickstart-dry-run.ps1")

Write-Step "Running headless tests"
& (Join-Path $scriptRoot "test-addon.ps1")
if ($LASTEXITCODE -ne 0) {
	throw "Headless tests failed with exit code $LASTEXITCODE"
}

Write-Step "ofxGgmlAudio local validation passed"
