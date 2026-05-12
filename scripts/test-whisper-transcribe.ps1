param(
	[string]$Configuration = "Release",
	[string]$BuildDir = "",
	[string]$Model = "",
	[string]$Audio = "",
	[string]$ExpectedText = "ask not",
	[switch]$Clean,
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

function Convert-ToCmdArgument {
	param([string]$Value)
	return '"' + ($Value -replace '"', '""') + '"'
}

function Invoke-CheckedNative {
	param(
		[string]$Step,
		[scriptblock]$Command
	)
	& $Command
	if ($LASTEXITCODE -ne 0) {
		throw "$Step failed with exit code $LASTEXITCODE"
	}
}

function Invoke-CheckedCmd {
	param(
		[string]$Step,
		[string]$Command
	)
	& cmd.exe /d /s /c $Command
	if ($LASTEXITCODE -ne 0) {
		throw "$Step failed with exit code $LASTEXITCODE"
	}
}

function Get-VisualStudioDevCmd {
	$candidates = New-Object System.Collections.Generic.List[string]
	$vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
	if (Test-Path -LiteralPath $vswhere) {
		$installPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null
		if ($installPath) {
			$candidates.Add((Join-Path $installPath "Common7\Tools\VsDevCmd.bat"))
		}
	}

	foreach ($version in @("18", "17", "16")) {
		foreach ($edition in @("Community", "Professional", "Enterprise", "BuildTools")) {
			$candidates.Add("C:\Program Files\Microsoft Visual Studio\$version\$edition\Common7\Tools\VsDevCmd.bat")
			$candidates.Add("C:\Program Files (x86)\Microsoft Visual Studio\$version\$edition\Common7\Tools\VsDevCmd.bat")
		}
	}

	foreach ($candidate in $candidates) {
		if (Test-Path -LiteralPath $candidate) {
			return $candidate
		}
	}
	return ""
}

function Assert-File {
	param(
		[string]$Path,
		[string]$Label,
		[string]$Fix
	)
	if (!(Test-Path -LiteralPath $Path -PathType Leaf)) {
		throw "$Label was not found: $Path`nfix: $Fix"
	}
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonRoot = Resolve-Path (Join-Path $scriptRoot "..")
$addonsRoot = Split-Path -Parent $addonRoot
$testsDir = Join-Path $addonRoot "tests"
$whisperInclude = Join-Path $addonRoot "libs\whisper\include"
$whisperHeader = Join-Path $whisperInclude "whisper.h"
$ggmlInclude = Join-Path $addonsRoot "ofxGgmlCore\libs\ggml\include"
$ggmlHeader = Join-Path $ggmlInclude "ggml.h"
$whisperLib = if (Test-WindowsHost) {
	Join-Path $addonRoot "libs\whisper\lib\whisper.lib"
} else {
	Join-Path $addonRoot "libs/whisper/lib/libwhisper.a"
}
$whisperDll = Join-Path $addonRoot "libs\whisper\bin\whisper.dll"
if ([string]::IsNullOrWhiteSpace($BuildDir)) {
	$BuildDir = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgmlAudio-whisper-smoke"
}
if ([string]::IsNullOrWhiteSpace($Model)) {
	$Model = Join-Path $addonRoot "models\ggml-tiny.en.bin"
}
if ([string]::IsNullOrWhiteSpace($Audio)) {
	$Audio = Join-Path $addonRoot "audio\jfk.wav"
}
$Model = [System.IO.Path]::GetFullPath($Model)
$Audio = [System.IO.Path]::GetFullPath($Audio)

if ($DryRun) {
	Write-Step "Whisper transcription smoke plan"
	Write-Host "  tests: $testsDir"
	Write-Host "  build: $BuildDir"
	Write-Host "  include: $whisperInclude"
	Write-Host "  ggml include: $ggmlInclude"
	Write-Host "  library: $whisperLib"
	Write-Host "  model: $Model"
	Write-Host "  audio: $Audio"
	Write-Host "  expected text: $ExpectedText"
	Write-Host "  clean: $(if ($Clean) { 'ON' } else { 'OFF' })"
	Write-Step "Dry run complete; no files were changed"
	return
}

Assert-File $whisperHeader "Whisper header" "scripts\build-whisper.bat"
Assert-File $ggmlHeader "ofxGgmlCore ggml header" "..\ofxGgmlCore\scripts\setup-ggml.bat -Auto"
Assert-File $whisperLib "Whisper library" "scripts\build-whisper.bat"
if (Test-WindowsHost) {
	Assert-File $whisperDll "Whisper DLL" "scripts\build-whisper.bat"
}
Assert-File $Model "Whisper model" "scripts\download-whisper-assets.bat"
Assert-File $Audio "WAV input" "scripts\download-whisper-assets.bat"

if ($Clean -and (Test-Path -LiteralPath $BuildDir)) {
	Write-Step "Cleaning $BuildDir"
	Remove-Item -LiteralPath $BuildDir -Recurse -Force
}

if (Test-WindowsHost) {
	$vsDevCmd = Get-VisualStudioDevCmd
	if ([string]::IsNullOrWhiteSpace($vsDevCmd)) {
		throw "Visual Studio C++ build tools were not found."
	}

	$configure = "cmake -S $(Convert-ToCmdArgument $testsDir) -B $(Convert-ToCmdArgument $BuildDir) -G $(Convert-ToCmdArgument "NMake Makefiles") -DCMAKE_BUILD_TYPE=$Configuration -DOFXGGMLAUDIO_BUILD_WHISPER_SMOKE=ON -DOFXGGMLAUDIO_WHISPER_INCLUDE_DIR=$(Convert-ToCmdArgument $whisperInclude) -DOFXGGMLAUDIO_GGML_INCLUDE_DIR=$(Convert-ToCmdArgument $ggmlInclude) -DOFXGGMLAUDIO_WHISPER_LIBRARY=$(Convert-ToCmdArgument $whisperLib)"
	$build = "cmake --build $(Convert-ToCmdArgument $BuildDir) --target ofxGgmlAudio_whisper_smoke"
	$copyDll = "copy /Y $(Convert-ToCmdArgument $whisperDll) $(Convert-ToCmdArgument $BuildDir) >nul"
	$exe = Join-Path $BuildDir "ofxGgmlAudio_whisper_smoke.exe"
	$run = "$(Convert-ToCmdArgument $exe) $(Convert-ToCmdArgument $Model) $(Convert-ToCmdArgument $Audio) $(Convert-ToCmdArgument $ExpectedText)"
	$command = "call $(Convert-ToCmdArgument $vsDevCmd) -arch=x64 -host_arch=x64 >nul && $configure && $build && $copyDll && $run"

	Write-Step "Building and running Whisper transcription smoke with Visual Studio tools"
	Invoke-CheckedCmd "Whisper transcription smoke" $command
} else {
	Write-Step "Configuring Whisper transcription smoke"
	Invoke-CheckedNative "cmake configure Whisper transcription smoke" {
		cmake -S $testsDir -B $BuildDir -DCMAKE_BUILD_TYPE=$Configuration `
			-DOFXGGMLAUDIO_BUILD_WHISPER_SMOKE=ON `
			-DOFXGGMLAUDIO_WHISPER_INCLUDE_DIR=$whisperInclude `
			-DOFXGGMLAUDIO_GGML_INCLUDE_DIR=$ggmlInclude `
			-DOFXGGMLAUDIO_WHISPER_LIBRARY=$whisperLib
	}
	Write-Step "Building Whisper transcription smoke"
	Invoke-CheckedNative "cmake build Whisper transcription smoke" {
		cmake --build $BuildDir --target ofxGgmlAudio_whisper_smoke --config $Configuration
	}
	Write-Step "Running Whisper transcription smoke"
	$exe = Join-Path $BuildDir "ofxGgmlAudio_whisper_smoke"
	Invoke-CheckedNative "Whisper transcription smoke" {
		& $exe $Model $Audio $ExpectedText
	}
}
