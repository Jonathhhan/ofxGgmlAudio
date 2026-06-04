param(
	[string]$Configuration = "Release",
	[string]$Platform = "x64",
	[switch]$Clean,
	[switch]$WithWhisper,
	[switch]$DryRun,
	[int]$Jobs = 1
)

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $scriptRoot "build-transcribe-example.ps1") `
	-Example whisper `
	-Configuration $Configuration `
	-Platform $Platform `
	-Clean:$Clean `
	-WithWhisper:$WithWhisper `
	-DryRun:$DryRun `
	-Jobs $Jobs
exit $LASTEXITCODE
