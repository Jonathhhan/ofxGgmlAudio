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
$script = Join-Path $scriptRoot "download-whisper-assets.ps1"

Write-Step "Whisper asset default dry-run"
$defaultOutput = & $script -DryRun 2>&1 6>&1 | Out-String
Assert-Contains $defaultOutput "Whisper asset download plan" "asset dry-run"
Assert-Contains $defaultOutput "model: tiny.en" "asset dry-run"
Assert-Contains $defaultOutput "ggml-tiny.en.bin" "asset dry-run"
Assert-Contains $defaultOutput "sample: jfk.wav" "asset dry-run"
Assert-Contains $defaultOutput "Dry run complete; no files were changed" "asset dry-run"

Write-Step "Whisper asset skip dry-run"
$skipOutput = & $script -DryRun -SkipModel -SkipSample 2>&1 6>&1 | Out-String
Assert-Contains $skipOutput "model: SKIP" "asset skip dry-run"
Assert-Contains $skipOutput "sample: SKIP" "asset skip dry-run"

Write-Step "Whisper asset dry-run coverage passed"
