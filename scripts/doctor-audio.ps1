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

function Get-CoreGgmlLibraryRoots {
	param([string]$CoreRoot)
	return @(
		(Join-Path $CoreRoot "libs\ggml\lib"),
		(Join-Path $CoreRoot "libs\ggml\build-cuda\src\Release"),
		(Join-Path $CoreRoot "libs\ggml\build-cuda\src\ggml-cuda\Release"),
		(Join-Path $CoreRoot "libs\ggml\build-native\src\Release"),
		(Join-Path $CoreRoot "libs\ggml\build-native\src")
	)
}

function Test-CoreGgmlHeaderAvailable {
	param([string]$CoreRoot)
	foreach ($path in @(
		(Join-Path $CoreRoot "libs\ggml\include\ggml.h"),
		(Join-Path $CoreRoot "libs\ggml\.source\include\ggml.h")
	)) {
		if (Test-Path -LiteralPath $path -PathType Leaf) {
			return $true
		}
	}
	return $false
}

function Test-CoreGgmlLibrariesAvailable {
	param([string]$CoreRoot)
	$libraryNames = if (Test-WindowsHost) {
		@("ggml.lib", "ggml-base.lib", "ggml-cpu.lib")
	} else {
		@("libggml.a", "libggml-base.a", "libggml-cpu.a")
	}
	foreach ($libRoot in Get-CoreGgmlLibraryRoots -CoreRoot $CoreRoot) {
		if (!(Test-Path -LiteralPath $libRoot -PathType Container)) {
			continue
		}
		$allPresent = $true
		foreach ($libraryName in $libraryNames) {
			if (!(Test-Path -LiteralPath (Join-Path $libRoot $libraryName) -PathType Leaf)) {
				$allPresent = $false
				break
			}
		}
		if ($allPresent) {
			return $true
		}
	}
	return $false
}

function Get-CoreGgmlAccelerators {
	param([string]$CoreRoot)

	$libRoots = Get-CoreGgmlLibraryRoots -CoreRoot $CoreRoot
	$candidates = if (Test-WindowsHost) {
		@(
			@{ Name = "CUDA"; File = "ggml-cuda.lib" },
			@{ Name = "Vulkan"; File = "ggml-vulkan.lib" },
			@{ Name = "OpenCL"; File = "ggml-opencl.lib" },
			@{ Name = "Metal"; File = "ggml-metal.lib" }
		)
	} else {
		@(
			@{ Name = "CUDA"; File = "libggml-cuda.a" },
			@{ Name = "Vulkan"; File = "libggml-vulkan.a" },
			@{ Name = "OpenCL"; File = "libggml-opencl.a" },
			@{ Name = "Metal"; File = "libggml-metal.a" }
		)
	}

	$accelerators = @()
	foreach ($candidate in $candidates) {
		foreach ($libRoot in $libRoots) {
			if (Test-Path -LiteralPath (Join-Path $libRoot $candidate.File) -PathType Leaf) {
				$accelerators += $candidate.Name
				break
			}
		}
	}
	return $accelerators
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
$transcribeExampleRoot = Join-Path $addonRoot "ofxGgmlAudioTranscribeExample"
$liveMicExampleRoot = Join-Path $addonRoot "ofxGgmlAudioLiveMicExample"
$modelPath = Join-Path $addonRoot "models\ggml-$ModelName.bin"
$audioPath = Join-Path $addonRoot "audio\jfk.wav"
$transcribeExe = if (Test-WindowsHost) {
	Join-Path $transcribeExampleRoot "bin\ofxGgmlAudioTranscribeExample.exe"
} else {
	Join-Path $transcribeExampleRoot "bin/ofxGgmlAudioTranscribeExample"
}
$liveMicExe = if (Test-WindowsHost) {
	Join-Path $liveMicExampleRoot "bin\ofxGgmlAudioLiveMicExample.exe"
} else {
	Join-Path $liveMicExampleRoot "bin/ofxGgmlAudioLiveMicExample"
}
$coreSetupCommand = "$(Get-PlatformSiblingScript -AddonName 'ofxGgmlCore' -Name 'setup-ggml') -Cuda"
$buildWhisperCommand = Get-PlatformScript -Name "build-whisper"
$downloadAssetsCommand = Get-PlatformScript -Name "download-whisper-assets"
$transcribeQuickstartCommand = Get-PlatformScript -Name "quickstart-transcribe-example"
$liveMicQuickstartCommand = Get-PlatformScript -Name "quickstart-live-mic-example"
$transcribeRunBuildCommand = "$(Get-PlatformScript -Name 'run-transcribe-example') -Build -WithWhisper"
$liveMicRunBuildCommand = "$(Get-PlatformScript -Name 'run-live-mic-example') -Build"
$transcribeRunCommand = Get-PlatformScript -Name "run-transcribe-example"
$liveMicRunCommand = Get-PlatformScript -Name "run-live-mic-example"
$validateCommand = Get-PlatformScript -Name "validate-local"

$checks = [System.Collections.Generic.List[object]]::new()

Add-Check $checks "openFrameworks root" (Test-Path -LiteralPath (Join-Path $ofRoot "libs\openFrameworks") -PathType Container) $ofRoot "Run this addon from openFrameworks/addons/ofxGgmlAudio."
Add-Check $checks "ofxGgmlCore sibling" (Test-Path -LiteralPath $coreRoot -PathType Container) $coreRoot "Clone ofxGgmlCore next to ofxGgmlAudio."
Add-Check $checks "ofxImGui sibling" (Test-Path -LiteralPath $imguiRoot -PathType Container) $imguiRoot "Clone ofxImGui next to ofxGgmlAudio."
Add-Check $checks "PowerShell" ((Test-CommandAvailable "pwsh") -or (Test-CommandAvailable "powershell")) "pwsh or powershell" "Install PowerShell."
Add-Check $checks "git" (Test-CommandAvailable "git") "git on PATH" "Install Git and reopen the terminal."
Add-Check $checks "cmake" (Test-CommandAvailable "cmake") "cmake on PATH" "Install CMake and reopen the terminal."

$coreGgmlReady = (Test-CoreGgmlHeaderAvailable -CoreRoot $coreRoot) -and
	(Test-CoreGgmlLibrariesAvailable -CoreRoot $coreRoot)
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

Add-Check $checks "Transcribe example executable" (Test-Path -LiteralPath $transcribeExe -PathType Leaf) $transcribeExe $transcribeRunBuildCommand
Add-Check $checks "Live mic example executable" (Test-Path -LiteralPath $liveMicExe -PathType Leaf) $liveMicExe $liveMicRunBuildCommand

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

$accelerators = @(Get-CoreGgmlAccelerators -CoreRoot $coreRoot)
$acceleratorText = if ($accelerators.Count -gt 0) { $accelerators -join ", " } else { "none detected" }
Write-Host ""
Write-Host "Runtime notes"
Write-Host "  Transcribe example Threads controls CPU worker threads only."
Write-Host "  Core ggml accelerator candidates: $acceleratorText"
Write-Host "  Actual Whisper GPU use depends on how whisper.cpp was built and is reported in the example Runtime panel."
Write-Host "  Live mic quickstart skips Whisper runtime and sample asset setup."

$missing = @($checks | Where-Object { !$_.Ok })
Write-Host ""
if ($missing.Count -eq 0) {
	Write-Host "Ready. Run:"
	Write-Host "  $transcribeRunCommand"
	Write-Host "  $liveMicRunCommand"
	exit 0
}

Write-Host "Next likely command:"
if (!$coreGgmlReady) {
	Write-Host "  $coreSetupCommand"
} elseif (!(Test-Path -LiteralPath $liveMicExe -PathType Leaf)) {
	Write-Host "  $liveMicQuickstartCommand"
} elseif (!$whisperReady -or !$modelReady -or !$audioReady -or !(Test-Path -LiteralPath $transcribeExe -PathType Leaf)) {
	Write-Host "  $transcribeQuickstartCommand"
} else {
	Write-Host "  $validateCommand"
}
exit 1
