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

Write-Host "Audio runtime smoke contract passed"
