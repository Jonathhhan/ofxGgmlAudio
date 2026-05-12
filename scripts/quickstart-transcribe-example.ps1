param(
	[string]$ModelName = "tiny.en",
	[string]$ModelPath = "",
	[string]$AudioPath = "",
	[string]$Language = "auto",
	[int]$Threads = 0,
	[string]$Configuration = "Release",
	[string]$Platform = "x64",
	[switch]$CpuOnly,
	[switch]$Cuda,
	[switch]$Vulkan,
	[switch]$BundledGgml,
	[switch]$Translate,
	[switch]$NoTimestamps,
	[switch]$SkipRuntime,
	[switch]$ForceRuntime,
	[switch]$SkipAssets,
	[switch]$BuildOnly,
	[switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Write-Step {
	param([string]$Message)
	Write-Host "==> $Message"
}

function Invoke-Step {
	param(
		[string]$Label,
		[string]$ScriptPath,
		[string[]]$Arguments
	)
	Write-Step $Label
	& $ScriptPath @Arguments
	if ($LASTEXITCODE -ne 0) {
		throw "$Label failed with exit code $LASTEXITCODE"
	}
}

function Test-WhisperRuntimeReady {
	param([string]$Root)
	foreach ($relative in @(
		"libs\whisper\include\whisper.h",
		"libs\whisper\lib\whisper.lib",
		"libs\whisper\bin\whisper.dll"
	)) {
		if (!(Test-Path -LiteralPath (Join-Path $Root $relative) -PathType Leaf)) {
			return $false
		}
	}
	return $true
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonRoot = Split-Path -Parent $scriptRoot
$buildWhisper = Join-Path $scriptRoot "build-whisper.ps1"
$downloadAssets = Join-Path $scriptRoot "download-whisper-assets.ps1"
$buildExample = Join-Path $scriptRoot "build-transcribe-example.ps1"
$runExample = Join-Path $scriptRoot "run-transcribe-example.ps1"
$runtimeReady = Test-WhisperRuntimeReady -Root $addonRoot
$runtimeAction = if ($SkipRuntime) {
	"SKIP"
} elseif ($runtimeReady -and !$ForceRuntime) {
	"reuse installed runtime"
} else {
	"build-whisper"
}

$runtimeArgs = @("-Configuration", $Configuration)
if ($CpuOnly) { $runtimeArgs += "-CpuOnly" }
if ($Cuda) { $runtimeArgs += "-Cuda" }
if ($Vulkan) { $runtimeArgs += "-Vulkan" }
if ($BundledGgml) { $runtimeArgs += "-BundledGgml" }

$assetArgs = @("-Model", $ModelName)
$exampleBuildArgs = @(
	"-Configuration", $Configuration,
	"-Platform", $Platform,
	"-WithWhisper"
)
$runArgs = @(
	"-Configuration", $Configuration,
	"-Platform", $Platform,
	"-Language", $Language,
	"-Threads", [string]$Threads
)
if (![string]::IsNullOrWhiteSpace($ModelPath)) {
	$runArgs += @("-Model", $ModelPath)
}
if (![string]::IsNullOrWhiteSpace($AudioPath)) {
	$runArgs += @("-Audio", $AudioPath)
}
if ($Translate) { $runArgs += "-Translate" }
if ($NoTimestamps) { $runArgs += "-NoTimestamps" }

if ($DryRun) {
	Write-Step "Transcribe quickstart plan"
	Write-Host "  runtime: $runtimeAction"
	Write-Host "  assets: $(if ($SkipAssets) { 'SKIP' } else { $ModelName + ' + jfk.wav' })"
	Write-Host "  example build: ON"
	Write-Host "  launch: $(if ($BuildOnly) { 'OFF' } else { 'ON' })"
	Write-Host "  configuration: $Configuration"
	Write-Host "  platform: $Platform"
	Write-Host "  language: $Language"
	Write-Host "  threads: $Threads"
	Write-Host "  model path: $(if ([string]::IsNullOrWhiteSpace($ModelPath)) { '(auto)' } else { $ModelPath })"
	Write-Host "  audio path: $(if ([string]::IsNullOrWhiteSpace($AudioPath)) { '(auto)' } else { $AudioPath })"
	Write-Step "Dry run complete; no files were changed"
	return
}

if (!$SkipRuntime -and (!$runtimeReady -or $ForceRuntime)) {
	Invoke-Step "Building whisper.cpp runtime" $buildWhisper $runtimeArgs
} elseif (!$SkipRuntime) {
	Write-Step "Using installed whisper.cpp runtime"
}
if (!$SkipAssets) {
	Invoke-Step "Downloading Whisper quickstart assets" $downloadAssets $assetArgs
}

Invoke-Step "Building transcribe example with Whisper" $buildExample $exampleBuildArgs

if ($BuildOnly) {
	Write-Step "Build-only quickstart complete"
	return
}

Invoke-Step "Launching transcribe example" $runExample $runArgs
