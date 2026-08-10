param(
	[string]$Configuration = "Release",
	[string]$Platform = "x64"
)

$ErrorActionPreference = "Stop"

function Write-Step {
	param([string]$Message)
	Write-Host "==> $Message"
}

function Assert-Contains {
	param(
		[string[]]$Output,
		[string]$Needle,
		[string]$Label
	)
	$text = $Output -join "`n"
	if ($text -notlike "*$Needle*") {
		throw "$Label did not contain expected text: $Needle`n$text"
	}
}

function Assert-NotContains {
	param(
		[string[]]$Output,
		[string]$Needle,
		[string]$Label
	)
	$text = $Output -join "`n"
	if ($text -like "*$Needle*") {
		throw "$Label contained unexpected text: $Needle`n$text"
	}
}

function Assert-MissingExecutableHints {
	param(
		[string[]]$Output,
		[string]$Label,
		[string]$BuildCommand,
		[string]$QuickstartCommand
	)
	$text = $Output -join "`n"
	if ($text -notlike "*was not found*") {
		return
	}
	Assert-Contains $Output "Build it with: $BuildCommand" $Label
	Assert-Contains $Output "First run shortcut: $QuickstartCommand" $Label
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

function Get-ExampleExecutableName {
	param([string]$Name)
	if (Test-WindowsHost) {
		return "$Name.exe"
	}
	return $Name
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$scratchDir = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgmlAudio-launch-dry-run"
$transcribeExeName = Get-ExampleExecutableName -Name "ofxGgmlAudioTranscribeExample"
$whisperExeName = Get-ExampleExecutableName -Name "ofxGgmlAudioWhisperExample"
$liveMicExeName = Get-ExampleExecutableName -Name "ofxGgmlAudioLiveMicExample"
New-Item -ItemType Directory -Force -Path $scratchDir | Out-Null
$modelPath = Join-Path $scratchDir "dry-whisper-model.bin"
$audioPath = Join-Path $scratchDir "dry-audio.wav"
if (!(Test-Path -LiteralPath $modelPath -PathType Leaf)) {
	New-Item -ItemType File -Path $modelPath | Out-Null
}
if (!(Test-Path -LiteralPath $audioPath -PathType Leaf)) {
	New-Item -ItemType File -Path $audioPath | Out-Null
}

Write-Step "Transcribe example build dry-run"
$buildOutput = & (Join-Path $scriptRoot "build-transcribe-example.ps1") `
	-DryRun `
	-Configuration $Configuration `
	-Platform $Platform *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "Transcribe example build dry-run failed."
}
Assert-Contains $buildOutput "Transcribe example build plan" "Build dry-run"
Assert-Contains $buildOutput "configuration: $Configuration" "Build dry-run"
Assert-Contains $buildOutput "platform: $Platform" "Build dry-run"
Assert-Contains $buildOutput "with whisper: OFF" "Build dry-run"

Write-Step "Whisper example build dry-run"
$whisperBuildOutput = & (Join-Path $scriptRoot "build-whisper-example.ps1") `
	-DryRun `
	-Configuration $Configuration `
	-Platform $Platform `
	-Jobs 3 *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "Whisper example build dry-run failed."
}
Assert-Contains $whisperBuildOutput "Whisper example build plan" "Whisper build dry-run"
Assert-Contains $whisperBuildOutput "ofxGgmlAudioWhisperExample" "Whisper build dry-run"
Assert-Contains $whisperBuildOutput "with whisper: OFF" "Whisper build dry-run"
Assert-Contains $whisperBuildOutput "jobs: 3" "Whisper build dry-run"

Write-Step "Live mic example build dry-run"
$liveMicBuildOutput = & (Join-Path $scriptRoot "build-live-mic-example.ps1") `
	-DryRun `
	-Configuration $Configuration `
	-Platform $Platform *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "Live mic example build dry-run failed."
}
Assert-Contains $liveMicBuildOutput "Live mic example build plan" "Live mic build dry-run"
Assert-Contains $liveMicBuildOutput "ofxGgmlAudioLiveMicExample" "Live mic build dry-run"
Assert-Contains $liveMicBuildOutput "configuration: $Configuration" "Live mic build dry-run"
Assert-Contains $liveMicBuildOutput "platform: $Platform" "Live mic build dry-run"

Write-Step "Transcribe example launch dry-run"
$runOutput = & (Join-Path $scriptRoot "run-transcribe-example.ps1") `
	-DryRun `
	-Model $modelPath `
	-Audio $audioPath `
	-Language "en" `
	-Threads 4 `
	-Translate `
	-NoTimestamps `
	-Chunked `
	-AutoRun `
	-Configuration $Configuration `
	-Platform $Platform *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "Transcribe example launch dry-run failed."
}
Assert-Contains $runOutput "Using Whisper model: $modelPath" "Launch dry-run"
Assert-Contains $runOutput "Using audio file: $audioPath" "Launch dry-run"
Assert-Contains $runOutput "Language: en" "Launch dry-run"
Assert-Contains $runOutput "Threads: 4" "Launch dry-run"
Assert-Contains $runOutput "Translate: ON" "Launch dry-run"
Assert-Contains $runOutput "Timestamps: OFF" "Launch dry-run"
Assert-Contains $runOutput "Mode: chunked rolling transcript" "Launch dry-run"
Assert-Contains $runOutput "Autorun: ON (exit after transcription)" "Launch dry-run"
Assert-Contains $runOutput "Executable:" "Launch dry-run"
Assert-Contains $runOutput $transcribeExeName "Launch dry-run"
Assert-MissingExecutableHints $runOutput "Launch dry-run" "$(Get-PlatformScript -Name 'run-transcribe-example') -Build -WithWhisper" "$(Get-PlatformScript -Name 'quickstart-transcribe-example')"
Assert-NotContains $runOutput "Starting ofxGgmlAudioTranscribeExample" "Launch dry-run"

Write-Step "Whisper example launch dry-run"
$whisperRunOutput = & (Join-Path $scriptRoot "run-whisper-example.ps1") `
	-DryRun `
	-Model $modelPath `
	-Audio $audioPath `
	-Language "en" `
	-Threads 4 `
	-Translate `
	-NoTimestamps `
	-Configuration $Configuration `
	-Platform $Platform *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "Whisper example launch dry-run failed."
}
Assert-Contains $whisperRunOutput "Using Whisper model: $modelPath" "Whisper launch dry-run"
Assert-Contains $whisperRunOutput "Using audio file: $audioPath" "Whisper launch dry-run"
Assert-Contains $whisperRunOutput "Language: en" "Whisper launch dry-run"
Assert-Contains $whisperRunOutput "Threads: 4" "Whisper launch dry-run"
Assert-Contains $whisperRunOutput "Translate: ON" "Whisper launch dry-run"
Assert-Contains $whisperRunOutput "Timestamps: OFF" "Whisper launch dry-run"
Assert-Contains $whisperRunOutput $whisperExeName "Whisper launch dry-run"
Assert-MissingExecutableHints $whisperRunOutput "Whisper launch dry-run" "$(Get-PlatformScript -Name 'run-whisper-example') -Build -WithWhisper" "$(Get-PlatformScript -Name 'quickstart-whisper-example')"
Assert-NotContains $whisperRunOutput "Starting ofxGgmlAudioWhisperExample" "Whisper launch dry-run"

Write-Step "Live mic example launch dry-run"
$liveMicRunOutput = & (Join-Path $scriptRoot "run-live-mic-example.ps1") `
	-DryRun `
	-AutoRun `
	-Configuration $Configuration `
	-Platform $Platform *>&1 | ForEach-Object { $_.ToString() }
if (!$?) {
	throw "Live mic example launch dry-run failed."
}
Assert-Contains $liveMicRunOutput $liveMicExeName "Live mic launch dry-run"
Assert-Contains $liveMicRunOutput "Executable:" "Live mic launch dry-run"
Assert-Contains $liveMicRunOutput "Autorun: ON (exit after first captured chunk)" "Live mic launch dry-run"
Assert-MissingExecutableHints $liveMicRunOutput "Live mic launch dry-run" "$(Get-PlatformScript -Name 'run-live-mic-example') -Build" "$(Get-PlatformScript -Name 'quickstart-live-mic-example')"
Assert-NotContains $liveMicRunOutput "Using Whisper model" "Live mic launch dry-run"
Assert-NotContains $liveMicRunOutput "Starting ofxGgmlAudioLiveMicExample" "Live mic launch dry-run"

Write-Step "Transcribe example env flag dry-run"
$previousTranslate = $env:OFXGGML_AUDIO_TRANSLATE
$previousTimestamps = $env:OFXGGML_AUDIO_TIMESTAMPS
$previousChunked = $env:OFXGGML_AUDIO_CHUNKED
$previousAutoRun = $env:OFXGGML_AUDIO_AUTORUN
try {
	$env:OFXGGML_AUDIO_TRANSLATE = " yes "
	$env:OFXGGML_AUDIO_TIMESTAMPS = " off "
	$env:OFXGGML_AUDIO_CHUNKED = " yes "
	$env:OFXGGML_AUDIO_AUTORUN = " on "
	$envOutput = & (Join-Path $scriptRoot "run-transcribe-example.ps1") `
		-DryRun `
		-Model $modelPath `
		-Audio $audioPath `
		-Language "auto" `
		-Threads 2 `
		-Configuration $Configuration `
		-Platform $Platform *>&1 | ForEach-Object { $_.ToString() }
	if (!$?) {
		throw "Transcribe example env flag dry-run failed."
	}
	Assert-Contains $envOutput "Language: auto" "Env flag dry-run"
	Assert-Contains $envOutput "Threads: 2" "Env flag dry-run"
	Assert-Contains $envOutput "Translate: ON" "Env flag dry-run"
	Assert-Contains $envOutput "Timestamps: OFF" "Env flag dry-run"
	Assert-Contains $envOutput "Mode: chunked rolling transcript" "Env flag dry-run"
	Assert-Contains $envOutput "Autorun: ON (exit after transcription)" "Env flag dry-run"
	Assert-Contains $envOutput "Executable:" "Env flag dry-run"
	Assert-Contains $envOutput $transcribeExeName "Env flag dry-run"
	Assert-MissingExecutableHints $envOutput "Env flag dry-run" "$(Get-PlatformScript -Name 'run-transcribe-example') -Build -WithWhisper" "$(Get-PlatformScript -Name 'quickstart-transcribe-example')"
} finally {
	if ($null -eq $previousTranslate) {
		Remove-Item Env:OFXGGML_AUDIO_TRANSLATE -ErrorAction SilentlyContinue
	} else {
		$env:OFXGGML_AUDIO_TRANSLATE = $previousTranslate
	}
	if ($null -eq $previousTimestamps) {
		Remove-Item Env:OFXGGML_AUDIO_TIMESTAMPS -ErrorAction SilentlyContinue
	} else {
		$env:OFXGGML_AUDIO_TIMESTAMPS = $previousTimestamps
	}
	if ($null -eq $previousChunked) {
		Remove-Item Env:OFXGGML_AUDIO_CHUNKED -ErrorAction SilentlyContinue
	} else {
		$env:OFXGGML_AUDIO_CHUNKED = $previousChunked
	}
	if ($null -eq $previousAutoRun) {
		Remove-Item Env:OFXGGML_AUDIO_AUTORUN -ErrorAction SilentlyContinue
	} else {
		$env:OFXGGML_AUDIO_AUTORUN = $previousAutoRun
	}
}

Write-Step "Launch dry-run smoke coverage passed"
