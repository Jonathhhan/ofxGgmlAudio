param(
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

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $scriptRoot "run-transcribe-example.ps1") `
	-Example whisper `
	-Model $Model `
	-Audio $Audio `
	-Language $Language `
	-Threads $Threads `
	-Translate:$Translate `
	-NoTimestamps:$NoTimestamps `
	-Build:$Build `
	-WithWhisper:$WithWhisper `
	-DryRun:$DryRun `
	-Configuration $Configuration `
	-Platform $Platform `
	-Jobs $Jobs
exit $LASTEXITCODE
