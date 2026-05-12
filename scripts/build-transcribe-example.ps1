param(
	[string]$Configuration = "Release",
	[string]$Platform = "x64",
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

function Normalize-WindowsPathEnvironment {
	if (!(Test-WindowsHost)) {
		return
	}
	$variables = [Environment]::GetEnvironmentVariables("Process")
	$pathNames = New-Object System.Collections.Generic.List[string]
	foreach ($key in $variables.Keys) {
		$name = [string]$key
		if ($name.Equals("Path", [System.StringComparison]::OrdinalIgnoreCase)) {
			$pathNames.Add($name)
		}
	}
	if ($pathNames.Count -le 1) {
		return
	}
	$preferredName = if ($pathNames.Contains("Path")) { "Path" } else { $pathNames[0] }
	$pathValue = [string]$variables[$preferredName]
	foreach ($name in $pathNames) {
		if (!$name.Equals("Path", [System.StringComparison]::Ordinal)) {
			[Environment]::SetEnvironmentVariable($name, $null, "Process")
		}
	}
	[Environment]::SetEnvironmentVariable("Path", $pathValue, "Process")
}

function Find-ProjectGenerator {
	param([string]$OfRoot)
	$candidates = @(
		(Join-Path $OfRoot "projectGenerator\resources\app\app\projectGenerator.exe"),
		(Join-Path $OfRoot "projectGenerator\projectGenerator.exe"),
		(Join-Path $OfRoot "projectGenerator-jan2026\resources\app\app\projectGenerator.exe"),
		(Join-Path $OfRoot "projectGenerator-jan2026\projectGenerator.exe")
	)
	foreach ($candidate in $candidates) {
		if (Test-Path -LiteralPath $candidate -PathType Leaf) {
			return (Resolve-Path -LiteralPath $candidate).Path
		}
	}
	return ""
}

function Get-MsBuild {
	$vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
	if (Test-Path -LiteralPath $vswhere) {
		$installPath = & $vswhere -latest -products * -requires Microsoft.Component.MSBuild -property installationPath 2>$null
		if ($installPath) {
			$candidate = Join-Path $installPath "MSBuild\Current\Bin\MSBuild.exe"
			if (Test-Path -LiteralPath $candidate) {
				return $candidate
			}
		}
	}
	foreach ($version in @("18", "17", "16")) {
		foreach ($edition in @("Community", "Professional", "Enterprise", "BuildTools")) {
			$candidate = "C:\Program Files\Microsoft Visual Studio\$version\$edition\MSBuild\Current\Bin\MSBuild.exe"
			if (Test-Path -LiteralPath $candidate) {
				return $candidate
			}
		}
	}
	return ""
}

function Invoke-Checked {
	param(
		[string]$Step,
		[scriptblock]$Command
	)
	& $Command
	if ($LASTEXITCODE -ne 0) {
		throw "$Step failed with exit code $LASTEXITCODE"
	}
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonRoot = Resolve-Path (Join-Path $scriptRoot "..")
$ofRoot = Split-Path -Parent (Split-Path -Parent $addonRoot)
$exampleName = "ofxGgmlAudioTranscribeExample"
$exampleRoot = Join-Path $addonRoot $exampleName
$projectPath = Join-Path $exampleRoot "$exampleName.vcxproj"

if (!(Test-Path -LiteralPath $exampleRoot -PathType Container)) {
	throw "Example directory was not found: $exampleRoot"
}

Normalize-WindowsPathEnvironment

if ($DryRun) {
	Write-Step "Transcribe example build plan"
	Write-Host "  example: $exampleRoot"
	Write-Host "  project: $projectPath"
	Write-Host "  configuration: $Configuration"
	Write-Host "  platform: $Platform"
	Write-Host "  clean: $(if ($Clean) { 'ON' } else { 'OFF' })"
	Write-Host "  projectGenerator: $(Find-ProjectGenerator -OfRoot $ofRoot)"
	Write-Host "  msbuild: $(Get-MsBuild)"
	return
}

if (Test-WindowsHost) {
	if (!(Test-Path -LiteralPath $projectPath -PathType Leaf)) {
		$projectGenerator = Find-ProjectGenerator -OfRoot $ofRoot
		if ([string]::IsNullOrWhiteSpace($projectGenerator)) {
			throw "Visual Studio project not found and projectGenerator.exe was not found under $ofRoot."
		}
		Write-Step "Generating $exampleName Visual Studio project"
		Invoke-Checked "projectGenerator $exampleName" {
			& $projectGenerator "-o$ofRoot" "-aofxGgmlCore,ofxGgmlAudio,ofxImGui" "-pvs" $exampleRoot
		}
	}

	$msbuild = Get-MsBuild
	if ([string]::IsNullOrWhiteSpace($msbuild)) {
		throw "MSBuild.exe was not found."
	}
	$target = if ($Clean) { "Rebuild" } else { "Build" }
	Write-Step "Building $exampleName $Configuration $Platform"
	Invoke-Checked "MSBuild $exampleName" {
		& $msbuild $projectPath /t:$target /p:Configuration=$Configuration /p:Platform=$Platform /p:TrackFileAccess=false /m:1 /nr:false
	}
	return
}

$makefile = Join-Path $exampleRoot "Makefile"
if (Test-Path -LiteralPath $makefile -PathType Leaf) {
	$target = if ($Clean) { "clean Release" } else { "Release" }
	Write-Step "Building $exampleName with make"
	Invoke-Checked "make $exampleName" {
		make -C $exampleRoot $target
	}
	return
}

if ($IsMacOS) {
	$xcodeProject = Get-ChildItem -LiteralPath $exampleRoot -Filter "*.xcodeproj" -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
	if ($xcodeProject) {
		Write-Step "Building $exampleName $Configuration with xcodebuild"
		Invoke-Checked "xcodebuild $exampleName" {
			xcodebuild -project $xcodeProject.FullName -configuration $Configuration
		}
		return
	}
}

throw "No supported generated project was found for $exampleName. Generate it with openFrameworks projectGenerator first."
