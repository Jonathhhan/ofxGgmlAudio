param(
	[ValidateSet("transcribe", "whisper")]
	[string]$Example = "transcribe",
	[string]$Model = $env:OFXGGML_AUDIO_MODEL,
	[string]$Audio = $env:OFXGGML_AUDIO_FILE,
	[string]$Language = $(if ($env:OFXGGML_AUDIO_LANGUAGE) { $env:OFXGGML_AUDIO_LANGUAGE } else { "auto" }),
	[int]$Threads = $(if ($env:OFXGGML_AUDIO_THREADS) { [int]$env:OFXGGML_AUDIO_THREADS } else { 0 }),
	[switch]$Translate,
	[switch]$NoTimestamps,
	[switch]$Build,
	[switch]$WithWhisper,
	[switch]$DryRun,
	[string]$Configuration = "Release",
	[string]$Platform = "x64",
	[int]$Jobs = 1
)

$ErrorActionPreference = "Stop"

function Write-Step {
	param([string]$Message)
	Write-Host "==> $Message"
}

function Normalize-PathText {
	param([string]$PathText)
	if ([string]::IsNullOrWhiteSpace($PathText)) {
		return ""
	}
	return $PathText.Trim().Trim('"')
}

function Test-EnabledFlag {
	param([string]$Value)
	$normalized = (Normalize-PathText $Value).ToLowerInvariant()
	return @("1", "true", "on", "yes").Contains($normalized)
}

function Test-DisabledFlag {
	param([string]$Value)
	$normalized = (Normalize-PathText $Value).ToLowerInvariant()
	return @("0", "false", "off", "no").Contains($normalized)
}

function Find-FirstFile {
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
				Sort-Object Name |
				Select-Object -First 1
			if ($file) {
				return $file.FullName
			}
		}
	}
	return ""
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonRoot = Resolve-Path (Join-Path $scriptRoot "..")
$exampleName = if ($Example -eq "whisper") { "ofxGgmlAudioWhisperExample" } else { "ofxGgmlAudioTranscribeExample" }
$exampleLabel = if ($Example -eq "whisper") { "Whisper" } else { "Transcribe" }
$exampleRoot = Join-Path $addonRoot $exampleName
$exampleExe = Join-Path $exampleRoot "bin\$exampleName.exe"

if ($Build) {
	$buildArgs = @{
		Configuration = $Configuration
		Platform = $Platform
		Jobs = $Jobs
		Example = $Example
	}
	if ($WithWhisper) {
		$buildArgs.WithWhisper = $true
	}
	& (Join-Path $scriptRoot "build-transcribe-example.ps1") @buildArgs
	if ($LASTEXITCODE -ne 0) {
		exit $LASTEXITCODE
	}
}

if (!(Test-Path -LiteralPath $exampleExe -PathType Leaf)) {
	if ($DryRun) {
		Write-Warning "$exampleLabel example executable was not found: $exampleExe"
	} else {
		throw "$exampleLabel example executable was not found: $exampleExe. Run scripts\run-transcribe-example.bat -Example $Example -Build first."
	}
}

$Model = Normalize-PathText $Model
$Audio = Normalize-PathText $Audio
$Language = Normalize-PathText $Language
if ([string]::IsNullOrWhiteSpace($Language)) {
	$Language = "auto"
}

if ([string]::IsNullOrWhiteSpace($Model)) {
	$Model = Find-FirstFile `
		-Directories @(
			(Join-Path $exampleRoot "bin\data\models"),
			(Join-Path $exampleRoot "bin\data"),
			(Join-Path $exampleRoot "models"),
			(Join-Path $addonRoot "models"),
			(Join-Path (Split-Path -Parent $addonRoot) "models")
		) `
		-Extensions @(".bin", ".gguf")
}

if ([string]::IsNullOrWhiteSpace($Audio)) {
	$Audio = Find-FirstFile `
		-Directories @(
			(Join-Path $exampleRoot "bin\data\audio"),
			(Join-Path $exampleRoot "bin\data"),
			(Join-Path $exampleRoot "audio"),
			(Join-Path $addonRoot "audio"),
			(Join-Path (Split-Path -Parent $addonRoot) "audio"),
			(Join-Path (Split-Path -Parent $addonRoot) "models")
		) `
		-Extensions @(".wav")
}

if (![string]::IsNullOrWhiteSpace($Model)) {
	$env:OFXGGML_AUDIO_MODEL = $Model
	Write-Step "Using Whisper model: $Model"
} else {
	Write-Warning "No Whisper model found. Pass -Model C:\path\to\ggml-base.en.bin or set OFXGGML_AUDIO_MODEL."
}

if (![string]::IsNullOrWhiteSpace($Audio)) {
	$env:OFXGGML_AUDIO_FILE = $Audio
	Write-Step "Using audio file: $Audio"
} else {
	Write-Warning "No WAV file found. Pass -Audio C:\path\to\speech.wav or set OFXGGML_AUDIO_FILE."
}

$env:OFXGGML_AUDIO_LANGUAGE = $Language
$env:OFXGGML_AUDIO_THREADS = [string]$Threads

$translateEnabled = $Translate.IsPresent -or (!$Translate.IsPresent -and (Test-EnabledFlag $env:OFXGGML_AUDIO_TRANSLATE))
$timestampsEnabled = $true
if ($NoTimestamps.IsPresent) {
	$timestampsEnabled = $false
} elseif (![string]::IsNullOrWhiteSpace($env:OFXGGML_AUDIO_TIMESTAMPS)) {
	$timestampsEnabled = !(Test-DisabledFlag $env:OFXGGML_AUDIO_TIMESTAMPS)
}

$env:OFXGGML_AUDIO_TRANSLATE = if ($translateEnabled) { "1" } else { "0" }
$env:OFXGGML_AUDIO_TIMESTAMPS = if ($timestampsEnabled) { "1" } else { "0" }

Write-Step "Language: $Language"
Write-Step "Threads: $Threads"
Write-Step "Translate: $(if ($translateEnabled) { 'ON' } else { 'OFF' })"
Write-Step "Timestamps: $(if ($timestampsEnabled) { 'ON' } else { 'OFF' })"

if ($DryRun) {
	Write-Step "Executable: $exampleExe"
	return
}

Write-Step "Starting $exampleName"
& $exampleExe
exit $LASTEXITCODE
