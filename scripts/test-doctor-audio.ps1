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

function Get-PowerShellCommand {
	$pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
	if ($pwsh) {
		return $pwsh.Source
	}

	$powershell = Get-Command powershell -ErrorAction SilentlyContinue
	if ($powershell) {
		return $powershell.Source
	}

	throw "Could not find pwsh or powershell."
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$script = Join-Path $scriptRoot "doctor-audio.ps1"

Write-Step "Audio doctor report smoke test"
$powerShell = Get-PowerShellCommand
$arguments = @("-NoProfile", "-File", $script)
if ($IsWindows -or !($IsLinux -or $IsMacOS)) {
	$arguments = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $script)
}

$output = & $powerShell @arguments 2>&1 | ForEach-Object { $_.ToString() } | Out-String
$exitCode = $LASTEXITCODE

Assert-Contains $output "ofxGgmlAudio doctor" "doctor report"
Assert-Contains $output "openFrameworks root" "doctor report"
Assert-Contains $output "ofxGgmlCore sibling" "doctor report"
Assert-Contains $output "Whisper runtime" "doctor report"
Assert-Contains $output "Whisper model" "doctor report"
Assert-Contains $output "WAV input" "doctor report"
Assert-Contains $output "Transcribe example executable" "doctor report"
Assert-Contains $output "Whisper example executable" "doctor report"
Assert-Contains $output "Live mic example executable" "doctor report"
Assert-Contains $output "Runtime notes" "doctor report"
Assert-Contains $output "Threads controls CPU worker threads" "doctor report"
Assert-Contains $output "Live mic quickstart skips Whisper runtime" "doctor report"

if ($exitCode -eq 0) {
	Assert-Contains $output "Ready. Run:" "doctor ready report"
	Assert-Contains $output "run-transcribe-example" "doctor ready report"
	Assert-Contains $output "run-whisper-example" "doctor ready report"
	Assert-Contains $output "run-live-mic-example" "doctor ready report"
} else {
	Assert-Contains $output "Next likely command:" "doctor incomplete report"
}

Write-Step "Audio doctor Core build-output runtime regression"
$scratchRoot = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgmlAudio-doctor-core-layout"
$fakeAddonRoot = Join-Path $scratchRoot "addons\ofxGgmlAudio"
$fakeCoreRoot = Join-Path $scratchRoot "addons\ofxGgmlCore"
$fakeImguiRoot = Join-Path $scratchRoot "addons\ofxImGui"
try {
	if (Test-Path -LiteralPath $scratchRoot) {
		Remove-Item -LiteralPath $scratchRoot -Recurse -Force
	}
	foreach ($path in @(
		(Join-Path $scratchRoot "libs\openFrameworks"),
		(Join-Path $fakeAddonRoot "scripts"),
		$fakeImguiRoot,
		(Join-Path $fakeCoreRoot "libs\ggml\.source\include"),
		(Join-Path $fakeCoreRoot "libs\ggml\build-cuda\src\Release")
	)) {
		New-Item -ItemType Directory -Force -Path $path | Out-Null
	}
	foreach ($relative in @(
		"libs\ggml\.source\include\ggml.h",
		"libs\ggml\build-cuda\src\Release\ggml.lib",
		"libs\ggml\build-cuda\src\Release\ggml-base.lib",
		"libs\ggml\build-cuda\src\Release\ggml-cpu.lib"
	)) {
		New-Item -ItemType File -Force -Path (Join-Path $fakeCoreRoot $relative) | Out-Null
	}
	Copy-Item -LiteralPath $script -Destination (Join-Path $fakeAddonRoot "scripts\doctor-audio.ps1") -Force

	$layoutOutput = & $powerShell @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $fakeAddonRoot "scripts\doctor-audio.ps1")) 2>&1 |
		ForEach-Object { $_.ToString() } |
		Out-String
	Assert-Contains $layoutOutput "[OK ] ofxGgmlCore ggml runtime" "doctor Core build-output runtime regression"
} finally {
	if (Test-Path -LiteralPath $scratchRoot) {
		Remove-Item -LiteralPath $scratchRoot -Recurse -Force
	}
}

Write-Step "Audio doctor smoke coverage passed"
