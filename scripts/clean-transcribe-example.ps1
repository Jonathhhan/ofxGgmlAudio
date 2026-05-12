param(
	[string]$ExampleRoot = "",
	[switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Write-Step {
	param([string]$Message)
	Write-Host "==> $Message"
}

function Remove-GeneratedPath {
	param(
		[string]$ExampleRoot,
		[string]$RelativePath,
		[bool]$DryRun
	)
	$path = Join-Path $ExampleRoot $RelativePath
	if (!(Test-Path -LiteralPath $path)) {
		return
	}

	$resolved = Resolve-Path -LiteralPath $path
	if (!$resolved.Path.StartsWith($ExampleRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
		throw "Refusing to remove outside example root: $($resolved.Path)"
	}

	if ($DryRun) {
		Write-Host "  remove: $RelativePath"
		return
	}

	Remove-Item -LiteralPath $resolved.Path -Recurse -Force
	Write-Host "  removed: $RelativePath"
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonRoot = Resolve-Path -LiteralPath (Join-Path $scriptRoot "..")
$exampleName = "ofxGgmlAudioTranscribeExample"
if ([string]::IsNullOrWhiteSpace($ExampleRoot)) {
	$ExampleRoot = Join-Path $addonRoot $exampleName
}
$exampleRoot = (Resolve-Path -LiteralPath $ExampleRoot).Path

$generatedPaths = @(
	"bin",
	"obj",
	".vs",
	"dll",
	"icon.rc",
	"config.make",
	"Makefile",
	"$exampleName.sln",
	"$exampleName.vcxproj",
	"$exampleName.vcxproj.filters",
	"$exampleName.vcxproj.user",
	"$exampleName.xcodeproj"
)

Write-Step "Transcribe example generated artifact cleanup"
Write-Host "  example: $exampleRoot"
Write-Host "  dry run: $(if ($DryRun) { 'ON' } else { 'OFF' })"

foreach ($relative in $generatedPaths) {
	Remove-GeneratedPath -ExampleRoot $exampleRoot -RelativePath $relative -DryRun ([bool]$DryRun)
}

Write-Step "Done"
