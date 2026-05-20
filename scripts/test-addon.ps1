param(
	[string]$Configuration = "Release",
	[string]$BuildDir = "",
	[switch]$Clean
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

function Test-GeneratedBuildDir {
	param([string]$Path)
	if ([string]::IsNullOrWhiteSpace($Path)) {
		return $false
	}
	$fullPath = [System.IO.Path]::GetFullPath($Path)
	$tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd("\", "/") + [System.IO.Path]::DirectorySeparatorChar
	$addonBuildRoot = [System.IO.Path]::GetFullPath((Join-Path $addonRoot.Path "build")).TrimEnd("\", "/") + [System.IO.Path]::DirectorySeparatorChar
	return $fullPath.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
		$fullPath.StartsWith($addonBuildRoot, [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-CachedCxxCompiler {
	param([string]$BuildDir)
	$cachePath = Join-Path $BuildDir "CMakeCache.txt"
	if (!(Test-Path -LiteralPath $cachePath -PathType Leaf)) {
		return ""
	}
	foreach ($line in (Get-Content -LiteralPath $cachePath -ErrorAction SilentlyContinue)) {
		if ($line -match "^CMAKE_CXX_COMPILER:FILEPATH=(.+)$") {
			return $Matches[1]
		}
	}
	return ""
}

function Clear-StaleCMakeBuildDir {
	param([string]$BuildDir)
	if (!(Test-GeneratedBuildDir -Path $BuildDir)) {
		return
	}
	$compiler = Get-CachedCxxCompiler -BuildDir $BuildDir
	if (![string]::IsNullOrWhiteSpace($compiler) -and !(Test-Path -LiteralPath $compiler -PathType Leaf)) {
		Write-Step "Cleaning stale CMake cache in $BuildDir"
		Remove-Item -LiteralPath $BuildDir -Recurse -Force
	}
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonRoot = Resolve-Path (Join-Path $scriptRoot "..")
$testsDir = Join-Path $addonRoot "tests"
if ([string]::IsNullOrWhiteSpace($BuildDir)) {
	$BuildDir = Join-Path ([System.IO.Path]::GetTempPath()) "ofxGgmlAudio-tests"
}
Clear-StaleCMakeBuildDir -BuildDir $BuildDir

if ($Clean -and (Test-Path -LiteralPath $BuildDir)) {
	Write-Step "Cleaning $BuildDir"
	Remove-Item -LiteralPath $BuildDir -Recurse -Force
}

if (Test-WindowsHost) {
	$vsDevCmd = Get-VisualStudioDevCmd
	if ([string]::IsNullOrWhiteSpace($vsDevCmd)) {
		throw "Visual Studio C++ build tools were not found."
	}

	$configure = "cmake -S $(Convert-ToCmdArgument $testsDir) -B $(Convert-ToCmdArgument $BuildDir) -G $(Convert-ToCmdArgument "NMake Makefiles") -DCMAKE_BUILD_TYPE=$Configuration"
	$build = "cmake --build $(Convert-ToCmdArgument $BuildDir)"
	$test = "ctest --test-dir $(Convert-ToCmdArgument $BuildDir) --output-on-failure"
	$command = "call $(Convert-ToCmdArgument $vsDevCmd) -arch=x64 -host_arch=x64 >nul && $configure && $build && $test"

	Write-Step "Configuring and running ofxGgmlAudio tests with Visual Studio tools"
	Invoke-CheckedCmd "ofxGgmlAudio tests" $command
} else {
	Write-Step "Configuring ofxGgmlAudio tests"
	Invoke-CheckedNative "cmake configure ofxGgmlAudio tests" {
		cmake -S $testsDir -B $BuildDir -DCMAKE_BUILD_TYPE=$Configuration
	}
	Write-Step "Building ofxGgmlAudio tests"
	Invoke-CheckedNative "cmake build ofxGgmlAudio tests" {
		cmake --build $BuildDir --config $Configuration
	}
	Write-Step "Running ofxGgmlAudio tests"
	Invoke-CheckedNative "ctest ofxGgmlAudio tests" {
		ctest --test-dir $BuildDir --output-on-failure
	}
}
