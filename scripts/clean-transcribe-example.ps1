param(
	[string]$ExampleRoot = "",
	[switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Write-Step {
	param([string]$Message)
	Write-Host "==> $Message"
}

function Test-PathInsideRoot {
	param(
		[string]$Root,
		[string]$Path
	)
	$rootWithSeparator = $Root.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) +
		[System.IO.Path]::DirectorySeparatorChar
	return $Path.StartsWith($rootWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)
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
	if (!(Test-PathInsideRoot -Root $ExampleRoot -Path $resolved.Path)) {
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
if (!(Test-Path -LiteralPath $ExampleRoot -PathType Container)) {
	throw "Transcribe example directory was not found: $ExampleRoot"
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
