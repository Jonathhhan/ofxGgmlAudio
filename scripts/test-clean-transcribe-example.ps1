param()

$ErrorActionPreference = "Stop"

function Write-Step {
	param([string]$Message)
	Write-Host "==> $Message"
}

function Assert-Path {
	param(
		[string]$Path,
		[string]$Label
	)
	if (!(Test-Path -LiteralPath $Path)) {
		throw "$Label was not found: $Path"
	}
}

function Assert-Missing {
	param(
		[string]$Path,
		[string]$Label
	)
	if (Test-Path -LiteralPath $Path) {
		throw "$Label should have been removed: $Path"
	}
}

function New-File {
	param([string]$Path)
	$parent = Split-Path -Parent $Path
	if (![string]::IsNullOrWhiteSpace($parent)) {
		New-Item -ItemType Directory -Force -Path $parent | Out-Null
	}
	New-Item -ItemType File -Force -Path $Path | Out-Null
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$script = Join-Path $scriptRoot "clean-transcribe-example.ps1"
$scratchRoot = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgmlAudio-clean-examples-test"

if (Test-Path -LiteralPath $scratchRoot) {
	Remove-Item -LiteralPath $scratchRoot -Recurse -Force
}

try {
	foreach ($case in @(
		@{ Example = "transcribe"; Label = "Transcribe"; Name = "ofxGgmlAudioTranscribeExample"; Wrapper = "" },
		@{ Example = "live-mic"; Label = "Live mic"; Name = "ofxGgmlAudioLiveMicExample"; Wrapper = "clean-live-mic-example.ps1" }
	)) {
		$exampleRoot = Join-Path $scratchRoot $case.Name
		New-Item -ItemType Directory -Force -Path (Join-Path $exampleRoot "src") | Out-Null
		New-File (Join-Path $exampleRoot "src\ofApp.cpp")
		New-File (Join-Path $exampleRoot "README.md")

		$generated = @(
			"bin\$($case.Name).exe",
			"obj\generated.obj",
			".vs\state.bin",
			"dll\copied.dll",
			"icon.rc",
			"config.make",
			"Makefile",
			"$($case.Name).sln",
			"$($case.Name).vcxproj",
			"$($case.Name).vcxproj.filters",
			"$($case.Name).vcxproj.user",
			"$($case.Name).xcodeproj\project.pbxproj"
		)

		foreach ($relative in $generated) {
			New-File (Join-Path $exampleRoot $relative)
		}

		Write-Step "$($case.Label) example clean dry-run regression"
		$dryRunOutput = & $script -Example $case.Example -ExampleRoot $exampleRoot -DryRun 2>&1 6>&1 | ForEach-Object { $_.ToString() } | Out-String
		if ($dryRunOutput -notmatch "remove: bin") {
			throw "$($case.Label) clean dry-run did not list generated bin output.`n$dryRunOutput"
		}
		Assert-Path (Join-Path $exampleRoot "bin") "$($case.Label) dry-run generated bin"

		if (![string]::IsNullOrWhiteSpace($case.Wrapper)) {
			$wrapper = Join-Path $scriptRoot $case.Wrapper
			$wrapperOutput = & $wrapper -ExampleRoot $exampleRoot -DryRun 2>&1 6>&1 | ForEach-Object { $_.ToString() } | Out-String
			if ($wrapperOutput -notmatch "remove: bin") {
				throw "$($case.Label) wrapper clean dry-run did not list generated bin output.`n$wrapperOutput"
			}
		}

		Write-Step "$($case.Label) example clean remove regression"
		& $script -Example $case.Example -ExampleRoot $exampleRoot
		foreach ($relative in @("bin", "obj", ".vs", "dll", "icon.rc", "config.make", "Makefile", "$($case.Name).sln", "$($case.Name).vcxproj", "$($case.Name).vcxproj.filters", "$($case.Name).vcxproj.user", "$($case.Name).xcodeproj")) {
			Assert-Missing (Join-Path $exampleRoot $relative) $relative
		}
		Assert-Path (Join-Path $exampleRoot "src\ofApp.cpp") "$($case.Label) source file"
		Assert-Path (Join-Path $exampleRoot "README.md") "$($case.Label) README"
	}

	Write-Step "Example clean missing-root regression"
	$missingRootFailedClearly = $false
	try {
		& $script -ExampleRoot (Join-Path $scratchRoot "missing")
	} catch {
		$missingRootFailedClearly = $_.Exception.Message -match "directory was not found"
	}
	if (!$missingRootFailedClearly) {
		throw "clean script did not fail clearly for a missing example root."
	}

	Write-Step "Example clean regression passed"
} finally {
	if (Test-Path -LiteralPath $scratchRoot) {
		Remove-Item -LiteralPath $scratchRoot -Recurse -Force
	}
}
