param(
	[Parameter(ValueFromRemainingArguments = $true)]
	[string[]]$RemainingArguments
)

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $scriptRoot "build-whisper.ps1") @RemainingArguments
exit $LASTEXITCODE
