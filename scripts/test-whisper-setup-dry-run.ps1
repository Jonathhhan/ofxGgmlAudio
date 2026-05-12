param()

$ErrorActionPreference = "Stop"

function Write-Step {
	param([string]$Message)
	Write-Host "==> $Message"
}

function Assert-Contains {
	param(
		[string]$Text,
		[string]$Needle,
		[string]$Label
	)
	if (!$Text.Contains($Needle)) {
		throw "$Label did not contain expected text: $Needle`n$Text"
	}
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$script = Join-Path $scriptRoot "build-whisper.ps1"

Write-Step "whisper.cpp default dry-run"
$defaultOutput = & $script -DryRun 2>&1 6>&1 | Out-String
Assert-Contains $defaultOutput "Dry run: whisper.cpp setup plan" "default dry-run"
Assert-Contains $defaultOutput "mode: Auto" "default dry-run"
Assert-Contains $defaultOutput "ggml: ofxGgmlCore" "default dry-run"
Assert-Contains $defaultOutput "generated ggml package:" "default dry-run"
Assert-Contains $defaultOutput "-DWHISPER_USE_SYSTEM_GGML=ON" "default dry-run"
Assert-Contains $defaultOutput "-DWHISPER_BUILD_EXAMPLES=OFF" "default dry-run"
Assert-Contains $defaultOutput "Dry run complete; no files were changed" "default dry-run"

Write-Step "whisper.cpp Core-constrained auto dry-run"
$fakeCore = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgmlAudio-fake-core"
$fakeInclude = Join-Path $fakeCore "libs\ggml\include"
$fakeLib = Join-Path $fakeCore "libs\ggml\lib"
New-Item -ItemType Directory -Force -Path $fakeInclude | Out-Null
New-Item -ItemType Directory -Force -Path $fakeLib | Out-Null
foreach ($file in @(
	(Join-Path $fakeInclude "ggml.h"),
	(Join-Path $fakeLib "ggml.lib"),
	(Join-Path $fakeLib "ggml-base.lib"),
	(Join-Path $fakeLib "ggml-cpu.lib")
)) {
	if (!(Test-Path -LiteralPath $file -PathType Leaf)) {
		New-Item -ItemType File -Path $file | Out-Null
	}
}
$coreConstrainedOutput = & $script -DryRun -OfxGgmlCorePath $fakeCore 2>&1 6>&1 | Out-String
Assert-Contains $coreConstrainedOutput "mode: Auto" "Core-constrained dry-run"
Assert-Contains $coreConstrainedOutput "CUDA=OFF" "Core-constrained dry-run"
Assert-Contains $coreConstrainedOutput "Vulkan=OFF" "Core-constrained dry-run"

Write-Step "whisper.cpp CPU-only dry-run"
$cpuOutput = & $script -DryRun -CpuOnly 2>&1 6>&1 | Out-String
Assert-Contains $cpuOutput "mode: CpuOnly" "CPU-only dry-run"
Assert-Contains $cpuOutput "CUDA=OFF" "CPU-only dry-run"
Assert-Contains $cpuOutput "Vulkan=OFF" "CPU-only dry-run"

Write-Step "whisper.cpp bundled ggml dry-run"
$bundledOutput = & $script -DryRun -CpuOnly -BundledGgml 2>&1 6>&1 | Out-String
Assert-Contains $bundledOutput "ggml: Bundled" "bundled ggml dry-run"
Assert-Contains $bundledOutput "-DWHISPER_USE_SYSTEM_GGML=OFF" "bundled ggml dry-run"

Write-Step "whisper.cpp examples dry-run"
$examplesOutput = & $script -DryRun -CpuOnly -BuildExamples -BuildServer 2>&1 6>&1 | Out-String
Assert-Contains $examplesOutput "-DWHISPER_BUILD_EXAMPLES=ON" "examples dry-run"
Assert-Contains $examplesOutput "-DWHISPER_BUILD_SERVER=ON" "server dry-run"

Write-Step "whisper.cpp setup dry-run coverage passed"
