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

if ($exitCode -eq 0) {
	Assert-Contains $output "Ready. Run:" "doctor ready report"
} else {
	Assert-Contains $output "Next likely command:" "doctor incomplete report"
}

Write-Step "Audio doctor smoke coverage passed"
