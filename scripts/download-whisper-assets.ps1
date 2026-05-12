param(
	[string]$Model = "tiny.en",
	[string]$ModelDir = "",
	[string]$AudioDir = "",
	[string]$ModelRepo = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main",
	[string]$SampleUrl = "https://raw.githubusercontent.com/ggml-org/whisper.cpp/master/samples/jfk.wav",
	[switch]$SkipModel,
	[switch]$SkipSample,
	[switch]$Force,
	[switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Write-Step {
	param([string]$Message)
	Write-Host "==> $Message"
}

function Normalize-Directory {
	param(
		[string]$Directory,
		[string]$Fallback
	)
	if ([string]::IsNullOrWhiteSpace($Directory)) {
		$Directory = $Fallback
	}
	return [System.IO.Path]::GetFullPath($Directory)
}

function Invoke-Download {
	param(
		[string]$Url,
		[string]$OutputPath,
		[string]$Label
	)
	if ((Test-Path -LiteralPath $OutputPath -PathType Leaf) -and !$Force) {
		Write-Step "$Label already exists: $OutputPath"
		return
	}
	New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutputPath) | Out-Null
	Write-Step "Downloading $Label"
	Write-Host "  url: $Url"
	Write-Host "  file: $OutputPath"
	Invoke-WebRequest -Uri $Url -OutFile $OutputPath
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonRoot = Split-Path -Parent $scriptRoot
$ModelDir = Normalize-Directory -Directory $ModelDir -Fallback (Join-Path $addonRoot "models")
$AudioDir = Normalize-Directory -Directory $AudioDir -Fallback (Join-Path $addonRoot "audio")
$modelFile = Join-Path $ModelDir "ggml-$Model.bin"
$sampleFile = Join-Path $AudioDir "jfk.wav"
$modelUrl = "$($ModelRepo.TrimEnd('/'))/ggml-$Model.bin"

if ($DryRun) {
	Write-Step "Whisper asset download plan"
	Write-Host "  model: $(if ($SkipModel) { 'SKIP' } else { $Model })"
	Write-Host "  model url: $modelUrl"
	Write-Host "  model file: $modelFile"
	Write-Host "  sample: $(if ($SkipSample) { 'SKIP' } else { 'jfk.wav' })"
	Write-Host "  sample url: $SampleUrl"
	Write-Host "  sample file: $sampleFile"
	Write-Host "  force: $(if ($Force) { 'ON' } else { 'OFF' })"
	Write-Step "Dry run complete; no files were changed"
	return
}

if (!$SkipModel) {
	Invoke-Download -Url $modelUrl -OutputPath $modelFile -Label "Whisper model $Model"
}
if (!$SkipSample) {
	Invoke-Download -Url $SampleUrl -OutputPath $sampleFile -Label "Whisper sample audio"
}

Write-Step "Done. Assets are ready for scripts\run-transcribe-example.bat"
Write-Host "  model: $modelFile"
Write-Host "  audio: $sampleFile"
