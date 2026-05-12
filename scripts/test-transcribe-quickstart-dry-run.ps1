param()

$ErrorActionPreference = "Stop"

function Write-Step {
	param([string]$Message)
	Write-Host "==> $Message"
}

function Assert-Contains {
	param(
		[string]$Text,
		[string]$Needle,
		[string]$Label
	)
	if (!$Text.Contains($Needle)) {
		throw "$Label did not contain expected text: $Needle`n$Text"
	}
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$script = Join-Path $scriptRoot "quickstart-transcribe-example.ps1"

Write-Step "Transcribe quickstart default dry-run"
$defaultOutput = & $script -DryRun 2>&1 6>&1 | Out-String
Assert-Contains $defaultOutput "Transcribe quickstart plan" "quickstart dry-run"
Assert-Contains $defaultOutput "runtime: build-whisper" "quickstart dry-run"
Assert-Contains $defaultOutput "assets: tiny.en + jfk.wav" "quickstart dry-run"
Assert-Contains $defaultOutput "example build: ON" "quickstart dry-run"
Assert-Contains $defaultOutput "launch: ON" "quickstart dry-run"
Assert-Contains $defaultOutput "Dry run complete; no files were changed" "quickstart dry-run"

Write-Step "Transcribe quickstart build-only dry-run"
$buildOnlyOutput = & $script -DryRun -SkipRuntime -SkipAssets -BuildOnly -ModelName base.en -Language en -Threads 4 2>&1 6>&1 | Out-String
Assert-Contains $buildOnlyOutput "runtime: SKIP" "quickstart build-only dry-run"
Assert-Contains $buildOnlyOutput "assets: SKIP" "quickstart build-only dry-run"
Assert-Contains $buildOnlyOutput "launch: OFF" "quickstart build-only dry-run"
Assert-Contains $buildOnlyOutput "language: en" "quickstart build-only dry-run"
Assert-Contains $buildOnlyOutput "threads: 4" "quickstart build-only dry-run"

Write-Step "Transcribe quickstart dry-run coverage passed"
