param()

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$smokeScript = Join-Path $scriptRoot "run-audio-runtime-smoke.ps1"

$textOutput = & $smokeScript -DryRun -Mode simple *>&1 | ForEach-Object { $_.ToString() }
if ($LASTEXITCODE -ne 0) {
	throw "run-audio-runtime-smoke.ps1 -DryRun failed."
}
$text = $textOutput -join "`n"
foreach ($expected in @(
	"ofxGgmlAudio runtime smoke plan",
	"Mode:          simple",
	"Expected text: ask not",
	"Ready:"
)) {
	if ($text -notmatch [regex]::Escape($expected)) {
		throw "Audio runtime smoke dry-run output did not contain expected text: $expected"
	}
}

$jsonOutput = & $smokeScript -DryRun -Mode all -Json -SummaryOnly *>&1 | ForEach-Object { $_.ToString() }
if ($LASTEXITCODE -ne 0) {
	throw "run-audio-runtime-smoke.ps1 -DryRun -Json failed."
}
$json = ($jsonOutput -join "`n") | ConvertFrom-Json
if ($json.Name -ne "ofxGgmlAudio runtime smoke") {
	throw "Audio runtime smoke JSON did not include the expected Name."
}
if ($json.Mode -ne "all") {
	throw "Audio runtime smoke JSON did not preserve the requested mode."
}
if (($json.NextCommands -join "`n") -notmatch "run-audio-runtime-smoke\.bat -Mode simple") {
	throw "Audio runtime smoke JSON did not include the simple runtime command."
}
if ($json.SmokeKind -ne "model-backed-whisper-transcription") {
	throw "Audio runtime smoke JSON did not include the expected smoke kind."
}
if ($json.Backend -ne "whisper.cpp") {
	throw "Audio runtime smoke JSON did not include the expected backend."
}

$evidencePath = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgmlAudio-runtime-smoke-evidence.json"
Remove-Item -LiteralPath $evidencePath -Force -ErrorAction SilentlyContinue
$null = & $smokeScript -DryRun -Mode simple -Json -SummaryOnly -OutputPath $evidencePath
if ($LASTEXITCODE -ne 0) {
	throw "run-audio-runtime-smoke.ps1 evidence dry-run failed."
}
if (!(Test-Path -LiteralPath $evidencePath -PathType Leaf)) {
	throw "Audio runtime smoke did not write dry-run evidence output."
}
$evidence = Get-Content -LiteralPath $evidencePath -Raw | ConvertFrom-Json
if ($evidence.SmokeKind -ne "model-backed-whisper-transcription") {
	throw "Audio runtime smoke evidence did not preserve the smoke kind."
}
Remove-Item -LiteralPath $evidencePath -Force -ErrorAction SilentlyContinue

Write-Host "Audio runtime smoke contract passed"
