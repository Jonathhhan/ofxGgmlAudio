param(
	[string]$ExampleRoot = "",
	[switch]$DryRun
)

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $scriptRoot "clean-transcribe-example.ps1") `
	-Example whisper `
	-ExampleRoot $ExampleRoot `
	-DryRun:$DryRun
exit $LASTEXITCODE
