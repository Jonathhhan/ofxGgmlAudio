param(
	[string]$Configuration = "Release",
	[string]$Platform = "x64",
	[int]$Jobs = 1,
	[switch]$BuildOnly,
	[switch]$DryRun
)

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $scriptRoot "quickstart-transcribe-example.ps1") `
	-Example live-mic `
	-Configuration $Configuration `
	-Platform $Platform `
	-Jobs $Jobs `
	-BuildOnly:$BuildOnly `
	-DryRun:$DryRun
exit $LASTEXITCODE
