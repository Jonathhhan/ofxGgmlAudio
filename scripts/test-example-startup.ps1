param(
	[ValidateSet("all", "transcribe", "whisper", "live-mic")]
	[string]$Example = "all",
	[int]$WaitSeconds = 4,
	[string]$Configuration = "Release",
	[string]$Platform = "x64",
	[switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Write-Step {
	param([string]$Message)
	Write-Host "==> $Message"
}

function Test-WindowsHost {
	return !($IsLinux -or $IsMacOS)
}

function Get-ExampleCases {
	$all = @(
		[pscustomobject]@{ Key = "transcribe"; Label = "Transcribe"; Name = "ofxGgmlAudioTranscribeExample"; Build = "scripts\run-transcribe-example.bat -Build -WithWhisper" },
		[pscustomobject]@{ Key = "whisper"; Label = "Whisper"; Name = "ofxGgmlAudioWhisperExample"; Build = "scripts\run-whisper-example.bat -Build -WithWhisper" },
		[pscustomobject]@{ Key = "live-mic"; Label = "Live mic"; Name = "ofxGgmlAudioLiveMicExample"; Build = "scripts\run-live-mic-example.bat -Build" }
	)
	if ($Example -eq "all") {
		return $all
	}
	return @($all | Where-Object { $_.Key -eq $Example })
}

function Get-ExecutablePath {
	param(
		[string]$AddonRoot,
		[string]$ExampleName
	)
	if (Test-WindowsHost) {
		return Join-Path $AddonRoot "$ExampleName\bin\$ExampleName.exe"
	}
	return Join-Path $AddonRoot "$ExampleName/bin/$ExampleName"
}

if ($WaitSeconds -lt 1) {
	throw "-WaitSeconds must be 1 or greater."
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonRoot = Resolve-Path (Join-Path $scriptRoot "..")
$cases = @(Get-ExampleCases)

Write-Step "Audio example startup smoke plan"
Write-Host "  examples: $($cases.Key -join ', ')"
Write-Host "  wait seconds: $WaitSeconds"
Write-Host "  configuration: $Configuration"
Write-Host "  platform: $Platform"

$failures = New-Object System.Collections.Generic.List[string]
foreach ($case in $cases) {
	$exe = Get-ExecutablePath -AddonRoot $addonRoot -ExampleName $case.Name
	Write-Step "$($case.Label) executable: $exe"
	if (!(Test-Path -LiteralPath $exe -PathType Leaf)) {
		$message = "$($case.Label) example executable was not found. Build it with: $($case.Build)"
		if ($DryRun) {
			Write-Warning $message
			continue
		}
		$failures.Add($message)
		continue
	}

	if ($DryRun) {
		continue
	}

	$startArgs = @{
		FilePath = $exe
		WorkingDirectory = Split-Path -Parent $exe
		PassThru = $true
	}
	if (Test-WindowsHost) {
		$startArgs.WindowStyle = "Hidden"
	}

	$process = $null
	try {
		$process = Start-Process @startArgs
		Start-Sleep -Seconds $WaitSeconds
		if ($process.HasExited) {
			$failures.Add("$($case.Label) example exited during startup smoke with code $($process.ExitCode).")
			continue
		}
		Write-Step "$($case.Label) stayed running for $WaitSeconds second(s)"
	} finally {
		if ($process -and !$process.HasExited) {
			try {
				[void]$process.CloseMainWindow()
				Start-Sleep -Milliseconds 500
			} catch {
			}
			if (!$process.HasExited) {
				Stop-Process -Id $process.Id -Force
			}
		}
	}
}

if ($failures.Count -gt 0) {
	throw "Audio example startup smoke failed:`n$($failures -join "`n")"
}

if ($DryRun) {
	Write-Step "Dry run complete; no examples were launched"
} else {
	Write-Step "Audio example startup smoke passed"
}
