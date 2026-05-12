param()

$ErrorActionPreference = "Stop"

function Write-Step {
	param([string]$Message)
	Write-Host "==> $Message"
}

function Assert-Path {
	param(
		[string]$Path,
		[string]$Label
	)
	if (!(Test-Path -LiteralPath $Path)) {
		throw "$Label was not found: $Path"
	}
}

function Assert-Missing {
	param(
		[string]$Path,
		[string]$Label
	)
	if (Test-Path -LiteralPath $Path) {
		throw "$Label should have been removed: $Path"
	}
}

function New-File {
	param([string]$Path)
	$parent = Split-Path -Parent $Path
	if (![string]::IsNullOrWhiteSpace($parent)) {
		New-Item -ItemType Directory -Force -Path $parent | Out-Null
	}
	New-Item -ItemType File -Force -Path $Path | Out-Null
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$script = Join-Path $scriptRoot "clean-transcribe-example.ps1"
$scratchRoot = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgmlAudio-clean-transcribe-test"
$exampleRoot = Join-Path $scratchRoot "ofxGgmlAudioTranscribeExample"

if (Test-Path -LiteralPath $scratchRoot) {
	Remove-Item -LiteralPath $scratchRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path (Join-Path $exampleRoot "src") | Out-Null
New-File (Join-Path $exampleRoot "src\ofApp.cpp")
New-File (Join-Path $exampleRoot "README.md")

$generated = @(
	"bin\ofxGgmlAudioTranscribeExample.exe",
	"obj\generated.obj",
	".vs\state.bin",
	"dll\copied.dll",
	"icon.rc",
	"config.make",
	"Makefile",
	"ofxGgmlAudioTranscribeExample.sln",
	"ofxGgmlAudioTranscribeExample.vcxproj",
	"ofxGgmlAudioTranscribeExample.vcxproj.filters",
	"ofxGgmlAudioTranscribeExample.vcxproj.user",
	"ofxGgmlAudioTranscribeExample.xcodeproj\project.pbxproj"
)

foreach ($relative in $generated) {
	New-File (Join-Path $exampleRoot $relative)
}

Write-Step "Transcribe example clean dry-run regression"
$dryRunOutput = & $script -ExampleRoot $exampleRoot -DryRun 2>&1 6>&1 | ForEach-Object { $_.ToString() } | Out-String
if ($dryRunOutput -notmatch "remove: bin") {
	throw "clean dry-run did not list generated bin output.`n$dryRunOutput"
}
Assert-Path (Join-Path $exampleRoot "bin") "dry-run generated bin"

Write-Step "Transcribe example clean remove regression"
& $script -ExampleRoot $exampleRoot
foreach ($relative in @("bin", "obj", ".vs", "dll", "icon.rc", "config.make", "Makefile", "ofxGgmlAudioTranscribeExample.sln", "ofxGgmlAudioTranscribeExample.vcxproj", "ofxGgmlAudioTranscribeExample.vcxproj.filters", "ofxGgmlAudioTranscribeExample.vcxproj.user", "ofxGgmlAudioTranscribeExample.xcodeproj")) {
	Assert-Missing (Join-Path $exampleRoot $relative) $relative
}
Assert-Path (Join-Path $exampleRoot "src\ofApp.cpp") "source file"
Assert-Path (Join-Path $exampleRoot "README.md") "README"

Remove-Item -LiteralPath $scratchRoot -Recurse -Force
Write-Step "Transcribe example clean regression passed"
