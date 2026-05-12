param(
	[string]$ModelName = "tiny.en"
)

$ErrorActionPreference = "Stop"

function Test-CommandAvailable {
	param([string]$Name)
	try {
		Get-Command $Name -ErrorAction Stop | Out-Null
		return $true
	} catch {
		return $false
	}
}

function Test-WindowsHost {
	return !($IsLinux -or $IsMacOS)
}

function Get-PlatformScript {
	param([string]$Name)
	if (Test-WindowsHost) {
		return "scripts\$Name.bat"
	}
	return "./scripts/$Name.sh"
}

function Get-PlatformSiblingScript {
	param(
		[string]$AddonName,
		[string]$Name
	)
	if (Test-WindowsHost) {
		return "..\$AddonName\scripts\$Name.bat"
	}
	return "../$AddonName/scripts/$Name.sh"
}

function Test-AnyFile {
	param(
		[string[]]$Directories,
		[string[]]$Extensions
	)
	foreach ($directory in $Directories) {
		if (!(Test-Path -LiteralPath $directory -PathType Container)) {
			continue
		}
		foreach ($extension in $Extensions) {
			$file = Get-ChildItem -LiteralPath $directory -Filter "*$extension" -File -ErrorAction SilentlyContinue |
				Select-Object -First 1
			if ($file) {
				return $true
			}
		}
	}
	return $false
}

function Test-AllFiles {
	param(
		[string]$Root,
		[string[]]$RelativePaths
	)
	foreach ($relative in $RelativePaths) {
		if (!(Test-Path -LiteralPath (Join-Path $Root $relative) -PathType Leaf)) {
			return $false
		}
	}
	return $true
}

function Add-Check {
	param(
		[System.Collections.Generic.List[object]]$Checks,
		[string]$Label,
		[bool]$Ok,
		[string]$Details,
		[string]$Fix = ""
	)
	$Checks.Add([pscustomobject]@{
		Label = $Label
		Ok = $Ok
		Details = $Details
		Fix = $Fix
	}) | Out-Null
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonRoot = Split-Path -Parent $scriptRoot
$addonsRoot = Split-Path -Parent $addonRoot
$ofRoot = Split-Path -Parent $addonsRoot
$coreRoot = Join-Path $addonsRoot "ofxGgmlCore"
$imguiRoot = Join-Path $addonsRoot "ofxImGui"
$exampleRoot = Join-Path $addonRoot "ofxGgmlAudioTranscribeExample"
$modelPath = Join-Path $addonRoot "models\ggml-$ModelName.bin"
$audioPath = Join-Path $addonRoot "audio\jfk.wav"
$exampleExe = if (Test-WindowsHost) {
	Join-Path $exampleRoot "bin\ofxGgmlAudioTranscribeExample.exe"
} else {
	Join-Path $exampleRoot "bin/ofxGgmlAudioTranscribeExample"
}
$coreSetupCommand = "$(Get-PlatformSiblingScript -AddonName 'ofxGgmlCore' -Name 'setup-ggml') -Cuda"
$buildWhisperCommand = Get-PlatformScript -Name "build-whisper"
$downloadAssetsCommand = Get-PlatformScript -Name "download-whisper-assets"
$quickstartCommand = Get-PlatformScript -Name "quickstart-transcribe-example"
$runBuildCommand = "$(Get-PlatformScript -Name 'run-transcribe-example') -Build -WithWhisper"
$runCommand = Get-PlatformScript -Name "run-transcribe-example"
$validateCommand = Get-PlatformScript -Name "validate-local"

$checks = [System.Collections.Generic.List[object]]::new()

Add-Check $checks "openFrameworks root" (Test-Path -LiteralPath (Join-Path $ofRoot "libs\openFrameworks") -PathType Container) $ofRoot "Run this addon from openFrameworks/addons/ofxGgmlAudio."
Add-Check $checks "ofxGgmlCore sibling" (Test-Path -LiteralPath $coreRoot -PathType Container) $coreRoot "Clone ofxGgmlCore next to ofxGgmlAudio."
Add-Check $checks "ofxImGui sibling" (Test-Path -LiteralPath $imguiRoot -PathType Container) $imguiRoot "Clone ofxImGui next to ofxGgmlAudio."
Add-Check $checks "PowerShell" ((Test-CommandAvailable "pwsh") -or (Test-CommandAvailable "powershell")) "pwsh or powershell" "Install PowerShell."
Add-Check $checks "git" (Test-CommandAvailable "git") "git on PATH" "Install Git and reopen the terminal."
Add-Check $checks "cmake" (Test-CommandAvailable "cmake") "cmake on PATH" "Install CMake and reopen the terminal."

$coreRuntimeFiles = if (Test-WindowsHost) {
	@("libs\ggml\include\ggml.h", "libs\ggml\lib\ggml.lib", "libs\ggml\lib\ggml-base.lib", "libs\ggml\lib\ggml-cpu.lib")
} else {
	@("libs/ggml/include/ggml.h", "libs/ggml/lib/libggml.a", "libs/ggml/lib/libggml-base.a", "libs/ggml/lib/libggml-cpu.a")
}
$coreGgmlReady = Test-AllFiles -Root $coreRoot -RelativePaths $coreRuntimeFiles
Add-Check $checks "ofxGgmlCore ggml runtime" $coreGgmlReady (Join-Path $coreRoot "libs\ggml") $coreSetupCommand

$whisperRuntimeFiles = if (Test-WindowsHost) {
	@("libs\whisper\include\whisper.h", "libs\whisper\lib\whisper.lib", "libs\whisper\bin\whisper.dll")
} else {
	@("libs/whisper/include/whisper.h", "libs/whisper/lib/libwhisper.a")
}
$whisperReady = Test-AllFiles -Root $addonRoot -RelativePaths $whisperRuntimeFiles
Add-Check $checks "Whisper runtime" $whisperReady (Join-Path $addonRoot "libs\whisper") $buildWhisperCommand

$modelReady = (Test-Path -LiteralPath $modelPath -PathType Leaf) -or
	(Test-AnyFile -Directories @((Join-Path $addonRoot "models"), (Join-Path $addonsRoot "models")) -Extensions @(".bin"))
Add-Check $checks "Whisper model" $modelReady $modelPath $downloadAssetsCommand

$audioReady = (Test-Path -LiteralPath $audioPath -PathType Leaf) -or
	(Test-AnyFile -Directories @((Join-Path $addonRoot "audio"), (Join-Path $addonsRoot "audio")) -Extensions @(".wav"))
Add-Check $checks "WAV input" $audioReady $audioPath $downloadAssetsCommand

Add-Check $checks "Transcribe example executable" (Test-Path -LiteralPath $exampleExe -PathType Leaf) $exampleExe $runBuildCommand

Write-Host "ofxGgmlAudio doctor"
Write-Host ""
foreach ($check in $checks) {
	$status = if ($check.Ok) { "OK " } else { "MISS" }
	Write-Host ("[{0}] {1}" -f $status, $check.Label)
	Write-Host ("     {0}" -f $check.Details)
	if (!$check.Ok -and ![string]::IsNullOrWhiteSpace($check.Fix)) {
		Write-Host ("     fix: {0}" -f $check.Fix)
	}
}

$missing = @($checks | Where-Object { !$_.Ok })
Write-Host ""
if ($missing.Count -eq 0) {
	Write-Host "Ready. Run: $runCommand"
	exit 0
}

Write-Host "Next likely command:"
if (!$coreGgmlReady) {
	Write-Host "  $coreSetupCommand"
} elseif (!$whisperReady -or !$modelReady -or !$audioReady -or !(Test-Path -LiteralPath $exampleExe -PathType Leaf)) {
	Write-Host "  $quickstartCommand"
} else {
	Write-Host "  $validateCommand"
}
exit 1
