param(
	[switch]$Build,
	[switch]$DryRun,
	[string]$Configuration = "Release",
	[string]$Platform = "x64",
	[int]$Jobs = 1
)

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $scriptRoot "run-transcribe-example.ps1") `
	-Example live-mic `
	-Build:$Build `
	-DryRun:$DryRun `
	-Configuration $Configuration `
	-Platform $Platform `
	-Jobs $Jobs
exit $LASTEXITCODE
