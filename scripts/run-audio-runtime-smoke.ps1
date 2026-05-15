param(
	[ValidateSet("simple", "chunked", "all")]
	[string]$Mode = "simple",
	[string]$Model = "",
	[string]$Audio = "",
	[string]$ExpectedText = "ask not",
	[string]$Configuration = "Release",
	[string]$BuildDir = "",
	[switch]$Clean,
	[switch]$DryRun,
	[switch]$Json,
	[switch]$SummaryOnly
)

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonRoot = Resolve-Path (Join-Path $scriptRoot "..")

function Write-Step {
	param([string]$Message)
	if (-not $Json) {
		Write-Host "==> $Message"
	}
}

function ConvertTo-SmokeJson {
	param([hashtable]$Value)
	return ($Value | ConvertTo-Json -Depth 7)
}

function Resolve-SmokePath {
	param(
		[string]$Path,
		[string]$Fallback
	)
	if ([string]::IsNullOrWhiteSpace($Path)) {
		$Path = $Fallback
	}
	return [System.IO.Path]::GetFullPath($Path)
}

function Invoke-SmokeScript {
	param(
		[string]$Name,
		[string]$Script,
		[string]$BuildDir
	)
	$started = Get-Date
	$previousErrorActionPreference = $ErrorActionPreference
	$ErrorActionPreference = "Continue"
	try {
		$powerShellExe = if ($PSHOME) {
			Join-Path $PSHOME "powershell.exe"
		} else {
			"powershell.exe"
		}
		if (!(Test-Path -LiteralPath $powerShellExe -PathType Leaf)) {
			$powerShellExe = "powershell.exe"
		}
		$args = @(
			"-NoProfile",
			"-ExecutionPolicy", "Bypass",
			"-File", $Script,
			"-Configuration", $Configuration,
			"-BuildDir", $BuildDir,
			"-Model", $resolvedModel,
			"-Audio", $resolvedAudio,
			"-ExpectedText", $ExpectedText
		)
		if ($Clean) {
			$args += "-Clean"
		}
		$output = & $powerShellExe @args 2>&1 | ForEach-Object { $_.ToString() }
		$exitCode = if ($null -ne $LASTEXITCODE) { [int]$LASTEXITCODE } else { 0 }
		$succeeded = $exitCode -eq 0
	} finally {
		$ErrorActionPreference = $previousErrorActionPreference
	}
	$elapsedMs = ((Get-Date) - $started).TotalMilliseconds
	[pscustomobject]@{
		Name = $Name
		Passed = ($exitCode -eq 0 -and $succeeded)
		ExitCode = $exitCode
		ElapsedMs = [Math]::Round($elapsedMs, 3)
		Output = @($output)
	}
}

$resolvedModel = Resolve-SmokePath -Path $Model -Fallback (Join-Path $addonRoot "models\ggml-tiny.en.bin")
$resolvedAudio = Resolve-SmokePath -Path $Audio -Fallback (Join-Path $addonRoot "audio\jfk.wav")
if ([string]::IsNullOrWhiteSpace($BuildDir)) {
	$BuildDir = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgmlAudio-runtime-smoke"
}
$resolvedBuildDir = [System.IO.Path]::GetFullPath($BuildDir)
$simpleBuildDir = Join-Path $resolvedBuildDir "simple"
$chunkedBuildDir = Join-Path $resolvedBuildDir "chunked"
$modes = if ($Mode -eq "all") { @("simple", "chunked") } else { @($Mode) }

$plan = @{
	Name = "ofxGgmlAudio runtime smoke"
	Root = $addonRoot.Path
	Mode = $Mode
	Model = $resolvedModel
	Audio = $resolvedAudio
	ExpectedText = $ExpectedText
	BuildDir = $resolvedBuildDir
	Ready = (
		(Test-Path -LiteralPath (Join-Path $addonRoot "libs\whisper\include\whisper.h") -PathType Leaf) -and
		(Test-Path -LiteralPath (Join-Path $addonRoot "libs\whisper\lib\whisper.lib") -PathType Leaf) -and
		(Test-Path -LiteralPath (Join-Path $addonRoot "libs\whisper\bin\whisper.dll") -PathType Leaf) -and
		(Test-Path -LiteralPath $resolvedModel -PathType Leaf) -and
		(Test-Path -LiteralPath $resolvedAudio -PathType Leaf)
	)
	NextCommands = @(
		"scripts\run-audio-runtime-smoke.bat -DryRun",
		"scripts\run-audio-runtime-smoke.bat -Mode simple -Json -SummaryOnly",
		"scripts\run-audio-runtime-smoke.bat -Mode chunked -Json -SummaryOnly",
		"scripts\run-audio-runtime-smoke.bat -Mode all -Json -SummaryOnly"
	)
}

if ($DryRun) {
	if ($Json) {
		ConvertTo-SmokeJson -Value $plan
	} else {
		Write-Host "ofxGgmlAudio runtime smoke plan"
		Write-Host "Mode:          $Mode"
		Write-Host "Model:         $resolvedModel"
		Write-Host "Audio:         $resolvedAudio"
		Write-Host "Expected text: $ExpectedText"
		Write-Host "BuildDir:      $resolvedBuildDir"
		Write-Host "Ready:         $($plan.Ready)"
		Write-Host "Next:          scripts\run-audio-runtime-smoke.bat -Mode $Mode -Json -SummaryOnly"
	}
	exit 0
}

$results = New-Object System.Collections.Generic.List[object]
foreach ($modeName in $modes) {
	if ($modeName -eq "simple") {
		Write-Step "Running Whisper transcription runtime smoke"
		$results.Add((Invoke-SmokeScript `
			-Name "simple" `
			-Script (Join-Path $scriptRoot "test-whisper-transcribe.ps1") `
			-BuildDir $simpleBuildDir))
	} elseif ($modeName -eq "chunked") {
		Write-Step "Running Whisper chunked transcription runtime smoke"
		$results.Add((Invoke-SmokeScript `
			-Name "chunked" `
			-Script (Join-Path $scriptRoot "test-whisper-chunked-transcribe.ps1") `
			-BuildDir $chunkedBuildDir))
	}
}

$resultArray = @($results.ToArray())
$failedArray = @($resultArray | Where-Object { -not $_.Passed })
$elapsedTotal = [double](($resultArray | Measure-Object -Property ElapsedMs -Sum).Sum)
$passed = $failedArray.Count -eq 0
$summary = @{
	SummaryOnly = [bool]$SummaryOnly
	Summary = @{
		Passed = [bool]$passed
		Mode = $Mode
		ModelPath = $resolvedModel
		AudioPath = $resolvedAudio
		ExpectedText = $ExpectedText
		ResultCount = $resultArray.Count
		FailedCount = $failedArray.Count
		ElapsedMs = [Math]::Round($elapsedTotal, 3)
		Error = if ($passed) { "" } else { "one or more audio runtime smokes failed" }
	}
}
if (-not $SummaryOnly) {
	$summary.Results = $resultArray
}

if ($Json) {
	ConvertTo-SmokeJson -Value $summary
} else {
	Write-Host "ofxGgmlAudio runtime smoke"
	Write-Host "Passed:    $passed"
	Write-Host "Mode:      $Mode"
	Write-Host "Model:     $resolvedModel"
	Write-Host "Audio:     $resolvedAudio"
	foreach ($result in $resultArray) {
		Write-Host "$($result.Name): $($result.Passed) ($($result.ElapsedMs) ms)"
	}
}

if (-not $passed) {
	exit 1
}
