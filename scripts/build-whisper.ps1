param(
	[string]$Repo = "https://github.com/ggml-org/whisper.cpp.git",
	[string]$Revision = "v1.9.2",
	[string]$Configuration = "Release",
	[string]$Generator = "",
	[int]$Jobs = 0,
	[string]$SourceDir = "",
	[string]$BuildDir = "",
	[string]$InstallDir = "",
	[string]$OfxGgmlCorePath = "",
	[switch]$Auto,
	[Alias("Cpu")][switch]$CpuOnly,
	[Alias("Gpu")][switch]$Cuda,
	[switch]$Vulkan,
	[switch]$Metal,
	[switch]$OpenCL,
	[switch]$BundledGgml,
	[switch]$BuildExamples,
	[switch]$BuildServer,
	[switch]$Clean,
	[switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Write-Step {
	param([string]$Message)
	Write-Host "==> $Message"
}

function Get-CommandPathOrNull {
	param([string]$Name)
	try {
		return (Get-Command $Name -ErrorAction Stop).Source
	} catch {
		return $null
	}
}

function Test-WindowsHost {
	return !($IsLinux -or $IsMacOS)
}

function Test-CudaAvailable {
	if ($env:CUDA_PATH -and (Test-Path -LiteralPath $env:CUDA_PATH)) {
		return $true
	}
	return [bool](Get-CommandPathOrNull "nvcc")
}

function Test-VulkanAvailable {
	if ($env:VULKAN_SDK -and (Test-Path -LiteralPath $env:VULKAN_SDK)) {
		return $true
	}
	return [bool](Get-CommandPathOrNull "glslc") -or [bool](Get-CommandPathOrNull "vulkaninfo")
}

function Test-MetalAvailable {
	return $IsMacOS -and [bool](Get-CommandPathOrNull "xcrun")
}

function Test-OpenCLAvailable {
	return [bool]$env:OPENCL_ROOT -or [bool](Get-CommandPathOrNull "clinfo")
}

function Test-CoreGgmlLibraryAvailable {
	param(
		[string]$CorePath,
		[string]$WindowsLibraryName,
		[string]$UnixLibraryName
	)
	if ([string]::IsNullOrWhiteSpace($CorePath)) {
		return $false
	}
	$libraryName = if (Test-WindowsHost) { $WindowsLibraryName } else { $UnixLibraryName }
	$candidateDirs = @(
		(Join-Path $CorePath "libs\ggml\lib"),
		(Join-Path $CorePath "libs\ggml\build-cuda\src\Release"),
		(Join-Path $CorePath "libs\ggml\build-cuda\src\ggml-cuda\Release"),
		(Join-Path $CorePath "libs\ggml\build-native\src\Release"),
		(Join-Path $CorePath "libs\ggml\build-native\src")
	)
	foreach ($libDir in $candidateDirs) {
		if ((Test-Path -LiteralPath $libDir -PathType Container) -and
			(Test-Path -LiteralPath (Join-Path $libDir $libraryName) -PathType Leaf)) {
			return $true
		}
	}
	return $false
}

function Get-DefaultGenerator {
	if (![string]::IsNullOrWhiteSpace($Generator)) {
		return $Generator
	}
	if (Test-WindowsHost) {
		return "Visual Studio 18 2026"
	}
	return ""
}

function Invoke-Checked {
	param(
		[string]$Step,
		[string]$FilePath,
		[string[]]$Arguments
	)
	& $FilePath @Arguments
	if ($LASTEXITCODE -ne 0) {
		throw "$Step failed with exit code $LASTEXITCODE"
	}
}

function Get-GitOutput {
	param(
		[string]$Source,
		[string[]]$Arguments,
		[string]$Step
	)
	$output = & git -C $Source @Arguments 2>&1
	if ($LASTEXITCODE -ne 0) {
		throw "$Step failed with exit code $LASTEXITCODE`n$($output -join [Environment]::NewLine)"
	}
	return (($output | ForEach-Object { [string]$_ }) -join [Environment]::NewLine).Trim()
}

function Test-SourceRevisionMatches {
	param(
		[string]$Source,
		[string]$Revision
	)
	$tags = Get-GitOutput -Source $Source -Arguments @("tag", "--points-at", "HEAD") -Step "git inspect whisper.cpp revision"
	return @($tags -split "\r?\n") -contains $Revision
}

function Update-WhisperSource {
	param(
		[string]$Source,
		[string]$Revision
	)
	if (Test-SourceRevisionMatches -Source $Source -Revision $Revision) {
		Write-Step "whisper.cpp source already at $Revision; skipping fetch"
		return
	}
	$dirty = Get-GitOutput -Source $Source -Arguments @("status", "--porcelain") -Step "git status whisper.cpp"
	if (![string]::IsNullOrWhiteSpace($dirty)) {
		throw "whisper.cpp source has local changes and cannot be updated safely: $Source"
	}
	Write-Step "Fetching whisper.cpp $Revision"
	$isVersionTag = $Revision -match "^v[0-9]"
	$fetchRevision = if ($isVersionTag) { "refs/tags/${Revision}:refs/tags/${Revision}" } else { $Revision }
	$checkoutRevision = if ($isVersionTag) { $Revision } else { "FETCH_HEAD" }
	Invoke-Checked "git fetch whisper.cpp" "git" @("-C", $Source, "fetch", "--depth", "1", "origin", $fetchRevision)
	Invoke-Checked "git checkout whisper.cpp" "git" @("-C", $Source, "checkout", "--detach", $checkoutRevision)
	Invoke-Checked "git update whisper.cpp submodules" "git" @("-C", $Source, "submodule", "update", "--init", "--recursive", "--depth", "1")
}

function Convert-ToOnOff {
	param([bool]$Value)
	if ($Value) { return "ON" }
	return "OFF"
}

function Convert-ToCMakePath {
	param([string]$Path)
	return ([System.IO.Path]::GetFullPath($Path) -replace "\\", "/")
}

function Read-CmakeCacheValue {
	param(
		[string]$BuildDir,
		[string]$Name
	)
	$cacheFile = Join-Path $BuildDir "CMakeCache.txt"
	if (!(Test-Path -LiteralPath $cacheFile -PathType Leaf)) {
		return ""
	}
	$pattern = "^{0}:[^=]*=(.*)$" -f [regex]::Escape($Name)
	foreach ($line in Get-Content -LiteralPath $cacheFile) {
		$match = [regex]::Match($line, $pattern)
		if ($match.Success) {
			return $match.Groups[1].Value.Trim()
		}
	}
	return ""
}

function Test-CmakeCacheBoolOn {
	param(
		[string]$BuildDir,
		[string]$Name
	)
	$value = Read-CmakeCacheValue -BuildDir $BuildDir -Name $Name
	return $value -match "^(ON|TRUE|1|YES)$"
}

function Get-InstalledFiles {
	param(
		[string]$Directory,
		[string[]]$Patterns
	)
	if (!(Test-Path -LiteralPath $Directory -PathType Container)) {
		return @()
	}
	$files = @()
	foreach ($pattern in $Patterns) {
		$files += @(Get-ChildItem -LiteralPath $Directory -File -Filter $pattern -ErrorAction SilentlyContinue)
	}
	return @($files | Sort-Object -Property Name -Unique)
}

function Join-FileNames {
	param([object[]]$Files)
	if ($Files.Count -eq 0) {
		return "none"
	}
	return (($Files | ForEach-Object { $_.Name }) -join ", ")
}

function Clear-InstalledWhisperArtifacts {
	param([string]$InstallDir)
	$targets = @(
		@{ Dir = Join-Path $InstallDir "bin"; Patterns = @("whisper*.dll", "whisper*.so", "libwhisper*.so", "libwhisper*.dylib", "parakeet*.dll", "libparakeet*.so", "libparakeet*.dylib") },
		@{ Dir = Join-Path $InstallDir "lib"; Patterns = @("whisper*.lib", "libwhisper*.a", "libwhisper*.dylib", "parakeet*.lib", "libparakeet*.a", "libparakeet*.dylib") },
		@{ Dir = Join-Path $InstallDir "include"; Patterns = @("whisper.h", "parakeet.h") },
		@{ Dir = Join-Path $InstallDir "lib\pkgconfig"; Patterns = @("whisper.pc", "parakeet.pc") }
	)
	foreach ($target in $targets) {
		foreach ($pattern in $target.Patterns) {
			foreach ($file in @(Get-InstalledFiles -Directory $target.Dir -Patterns @($pattern))) {
				try {
					Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
				} catch {
					throw "Could not replace installed Whisper artifact '$($file.FullName)'. Stop any running Whisper example/smoke process and retry. $($_.Exception.Message)"
				}
			}
		}
	}
	foreach ($directory in @(
		(Join-Path $InstallDir "lib\cmake\whisper"),
		(Join-Path $InstallDir "lib\cmake\parakeet")
	)) {
		if (Test-Path -LiteralPath $directory -PathType Container) {
			Remove-Item -LiteralPath $directory -Recurse -Force
		}
	}
}

function Find-BuiltWhisperArtifact {
	param(
		[string]$BuildDir,
		[string[]]$Names
	)
	foreach ($name in $Names) {
		$match = Get-ChildItem -LiteralPath $BuildDir -Recurse -File -Filter $name -ErrorAction SilentlyContinue |
			Sort-Object LastWriteTime -Descending |
			Select-Object -First 1
		if ($match) {
			return $match.FullName
		}
	}
	return ""
}

function Install-WhisperRuntime {
	param(
		[string]$BuildDir,
		[string]$SourceDir,
		[string]$InstallDir
	)
	$includeDir = Join-Path $InstallDir "include"
	$libraryDir = Join-Path $InstallDir "lib"
	$binaryDir = Join-Path $InstallDir "bin"
	New-Item -ItemType Directory -Path $includeDir,$libraryDir,$binaryDir -Force | Out-Null

	$header = Join-Path $SourceDir "include\whisper.h"
	if (!(Test-Path -LiteralPath $header -PathType Leaf)) {
		throw "Built whisper.cpp header was not found: $header"
	}
	Copy-Item -LiteralPath $header -Destination (Join-Path $includeDir "whisper.h") -Force

	if (Test-WindowsHost) {
		$library = Find-BuiltWhisperArtifact -BuildDir $BuildDir -Names @("whisper.lib")
		$runtime = Find-BuiltWhisperArtifact -BuildDir $BuildDir -Names @("whisper.dll")
		if ([string]::IsNullOrWhiteSpace($library) -or [string]::IsNullOrWhiteSpace($runtime)) {
			throw "Built whisper.cpp Windows artifacts were not found under: $BuildDir"
		}
		Copy-Item -LiteralPath $library -Destination (Join-Path $libraryDir "whisper.lib") -Force
		Copy-Item -LiteralPath $runtime -Destination (Join-Path $binaryDir "whisper.dll") -Force
		return
	}

	$library = Find-BuiltWhisperArtifact -BuildDir $BuildDir -Names @("libwhisper.a", "libwhisper.dylib", "libwhisper.so")
	if ([string]::IsNullOrWhiteSpace($library)) {
		throw "Built whisper.cpp library was not found under: $BuildDir"
	}
	Copy-Item -LiteralPath $library -Destination (Join-Path $libraryDir ([System.IO.Path]::GetFileName($library))) -Force
}

function Write-WhisperBackendReport {
	param(
		[string]$BuildDir,
		[string]$InstallDir,
		[string]$CorePath,
		[bool]$BundledGgml
	)
	$whisperDlls = Get-InstalledFiles -Directory (Join-Path $InstallDir "bin") -Patterns @("whisper*.dll", "whisper*.so", "libwhisper*.so", "libwhisper*.dylib")
	$coreCuda = Test-CoreGgmlLibraryAvailable -CorePath $CorePath -WindowsLibraryName "ggml-cuda.lib" -UnixLibraryName "libggml-cuda.a"
	$coreVulkan = Test-CoreGgmlLibraryAvailable -CorePath $CorePath -WindowsLibraryName "ggml-vulkan.lib" -UnixLibraryName "libggml-vulkan.a"
	$coreMetal = Test-CoreGgmlLibraryAvailable -CorePath $CorePath -WindowsLibraryName "ggml-metal.lib" -UnixLibraryName "libggml-metal.a"
	$coreOpenCL = Test-CoreGgmlLibraryAvailable -CorePath $CorePath -WindowsLibraryName "ggml-opencl.lib" -UnixLibraryName "libggml-opencl.a"

	Write-Step "Whisper backend summary"
	Write-Host "  ggml: $(if ($BundledGgml) { 'Bundled whisper.cpp ggml' } else { 'ofxGgmlCore ggml' })"
	Write-Host ("  CMakeCache: WHISPER_USE_SYSTEM_GGML={0} GGML_CUDA={1} GGML_VULKAN={2} GGML_METAL={3} GGML_OPENCL={4}" -f `
		(Convert-ToOnOff (Test-CmakeCacheBoolOn -BuildDir $BuildDir -Name "WHISPER_USE_SYSTEM_GGML")),
		(Convert-ToOnOff (Test-CmakeCacheBoolOn -BuildDir $BuildDir -Name "GGML_CUDA")),
		(Convert-ToOnOff (Test-CmakeCacheBoolOn -BuildDir $BuildDir -Name "GGML_VULKAN")),
		(Convert-ToOnOff (Test-CmakeCacheBoolOn -BuildDir $BuildDir -Name "GGML_METAL")),
		(Convert-ToOnOff (Test-CmakeCacheBoolOn -BuildDir $BuildDir -Name "GGML_OPENCL")))
	Write-Host ("  Core ggml accelerator libs: CUDA={0} Vulkan={1} Metal={2} OpenCL={3}" -f `
		(Convert-ToOnOff $coreCuda),
		(Convert-ToOnOff $coreVulkan),
		(Convert-ToOnOff $coreMetal),
		(Convert-ToOnOff $coreOpenCL))
	Write-Host "  installed Whisper runtime artifacts: $(Join-FileNames $whisperDlls)"
}

function Add-RequiredLibraryPath {
	param(
		[System.Collections.Generic.List[string]]$Libraries,
		[string]$Path,
		[string]$Description
	)
	if (!(Test-Path -LiteralPath $Path)) {
		throw "$Description was not found at: $Path"
	}
	$Libraries.Add($Path)
}

function New-OfxGgmlCoreCmakePackage {
	param(
		[string]$CorePath,
		[string]$PackageRoot,
		[bool]$EnableCuda,
		[bool]$EnableVulkan
	)

	$corePath = [System.IO.Path]::GetFullPath($CorePath)
	$includeDir = Join-Path $corePath "libs\ggml\include"
	$libDir = Join-Path $corePath "libs\ggml\lib"
	$packageDir = Join-Path $PackageRoot "ggml"
	$libraries = [System.Collections.Generic.List[string]]::new()

	if (!(Test-Path -LiteralPath $includeDir -PathType Container)) {
		throw "ofxGgmlCore ggml headers were not found at: $includeDir"
	}
	if (!(Test-Path -LiteralPath $libDir -PathType Container)) {
		throw "ofxGgmlCore ggml libraries were not found at: $libDir"
	}

	if (Test-WindowsHost) {
		Add-RequiredLibraryPath -Libraries $libraries -Path (Join-Path $libDir "ggml.lib") -Description "ofxGgmlCore ggml.lib"
		Add-RequiredLibraryPath -Libraries $libraries -Path (Join-Path $libDir "ggml-base.lib") -Description "ofxGgmlCore ggml-base.lib"
		Add-RequiredLibraryPath -Libraries $libraries -Path (Join-Path $libDir "ggml-cpu.lib") -Description "ofxGgmlCore ggml-cpu.lib"
		if ($EnableCuda) {
			Add-RequiredLibraryPath -Libraries $libraries -Path (Join-Path $libDir "ggml-cuda.lib") -Description "ofxGgmlCore ggml-cuda.lib"
			$cudaLibDir = if ($env:CUDA_PATH) { Join-Path $env:CUDA_PATH "lib\x64" } else { "" }
			Add-RequiredLibraryPath -Libraries $libraries -Path (Join-Path $cudaLibDir "cublas.lib") -Description "CUDA cublas.lib"
			Add-RequiredLibraryPath -Libraries $libraries -Path (Join-Path $cudaLibDir "cudart.lib") -Description "CUDA cudart.lib"
			Add-RequiredLibraryPath -Libraries $libraries -Path (Join-Path $cudaLibDir "cuda.lib") -Description "CUDA cuda.lib"
		}
		if ($EnableVulkan) {
			Add-RequiredLibraryPath -Libraries $libraries -Path (Join-Path $libDir "ggml-vulkan.lib") -Description "ofxGgmlCore ggml-vulkan.lib"
			$vulkanLibDir = if ($env:VULKAN_SDK) { Join-Path $env:VULKAN_SDK "Lib" } else { "" }
			Add-RequiredLibraryPath -Libraries $libraries -Path (Join-Path $vulkanLibDir "vulkan-1.lib") -Description "Vulkan vulkan-1.lib"
		}
	} else {
		Add-RequiredLibraryPath -Libraries $libraries -Path (Join-Path $libDir "libggml.a") -Description "ofxGgmlCore libggml.a"
		Add-RequiredLibraryPath -Libraries $libraries -Path (Join-Path $libDir "libggml-base.a") -Description "ofxGgmlCore libggml-base.a"
		Add-RequiredLibraryPath -Libraries $libraries -Path (Join-Path $libDir "libggml-cpu.a") -Description "ofxGgmlCore libggml-cpu.a"
	}

	New-Item -ItemType Directory -Force -Path $packageDir | Out-Null
	$cmakeIncludeDir = Convert-ToCMakePath $includeDir
	$cmakeLibraryEntries = ($libraries | ForEach-Object { "`t`"" + (Convert-ToCMakePath $_) + "`"" }) -join "`n"
	$configPath = Join-Path $packageDir "ggml-config.cmake"
	$versionPath = Join-Path $packageDir "ggml-version.cmake"

	$configContent = @"
include_guard(GLOBAL)

set(ggml_FOUND TRUE)
set(_ofxggmlcore_include_dir "$cmakeIncludeDir")
set(_ofxggmlcore_libraries
$cmakeLibraryEntries
)

if (NOT TARGET ggml::ggml)
	add_library(ggml::ggml INTERFACE IMPORTED)
	set_target_properties(ggml::ggml PROPERTIES
		INTERFACE_INCLUDE_DIRECTORIES "`${_ofxggmlcore_include_dir}"
		INTERFACE_COMPILE_DEFINITIONS "GGML_MAX_NAME=128"
		INTERFACE_LINK_LIBRARIES "`${_ofxggmlcore_libraries}"
	)
endif()
"@

	$versionContent = @"
set(PACKAGE_VERSION "ofxGgmlCore")
set(PACKAGE_VERSION_COMPATIBLE TRUE)
"@

	Set-Content -LiteralPath $configPath -Value $configContent -Encoding ASCII
	Set-Content -LiteralPath $versionPath -Value $versionContent -Encoding ASCII
	return $packageDir
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonRoot = Split-Path -Parent $scriptRoot
$runtimeRoot = Join-Path $addonRoot "libs\whisper"
if ([string]::IsNullOrWhiteSpace($SourceDir)) {
	$SourceDir = Join-Path $runtimeRoot ".source"
}
if ([string]::IsNullOrWhiteSpace($BuildDir)) {
	$BuildDir = Join-Path $runtimeRoot "build"
}
if ([string]::IsNullOrWhiteSpace($InstallDir)) {
	$InstallDir = $runtimeRoot
}
if ([string]::IsNullOrWhiteSpace($OfxGgmlCorePath)) {
	$OfxGgmlCorePath = [System.IO.Path]::Combine($addonRoot, "..", "ofxGgmlCore")
}
$OfxGgmlCorePath = [System.IO.Path]::GetFullPath($OfxGgmlCorePath)
if ($Jobs -le 0) {
	$Jobs = [Math]::Max(1, [Environment]::ProcessorCount)
}

$explicitBackend = $Cuda -or $Vulkan -or $Metal -or $OpenCL -or $CpuOnly
if (!$explicitBackend) {
	$Auto = $true
}

$enableCuda = $false
$enableVulkan = $false
$enableMetal = $false
$enableOpenCL = $false
$mode = "Auto"
$ggmlMode = if ($BundledGgml) { "Bundled" } else { "ofxGgmlCore" }
$coreGgmlPackageRoot = Join-Path $BuildDir "ofxggmlcore-cmake"
$coreGgmlPackageDir = Join-Path $coreGgmlPackageRoot "ggml"

if ($CpuOnly) {
	$mode = "CpuOnly"
} else {
	if ($Auto) {
		$enableCuda = Test-CudaAvailable
		$enableVulkan = Test-VulkanAvailable
		$enableMetal = Test-MetalAvailable
		$enableOpenCL = Test-OpenCLAvailable
		if (!$BundledGgml) {
			$enableCuda = $enableCuda -and (Test-CoreGgmlLibraryAvailable -CorePath $OfxGgmlCorePath -WindowsLibraryName "ggml-cuda.lib" -UnixLibraryName "libggml-cuda.a")
			$enableVulkan = $enableVulkan -and (Test-CoreGgmlLibraryAvailable -CorePath $OfxGgmlCorePath -WindowsLibraryName "ggml-vulkan.lib" -UnixLibraryName "libggml-vulkan.a")
			$enableMetal = $enableMetal -and (Test-CoreGgmlLibraryAvailable -CorePath $OfxGgmlCorePath -WindowsLibraryName "ggml-metal.lib" -UnixLibraryName "libggml-metal.a")
			$enableOpenCL = $enableOpenCL -and (Test-CoreGgmlLibraryAvailable -CorePath $OfxGgmlCorePath -WindowsLibraryName "ggml-opencl.lib" -UnixLibraryName "libggml-opencl.a")
		}
	} else {
		$enableCuda = [bool]$Cuda
		$enableVulkan = [bool]$Vulkan
		$enableMetal = [bool]$Metal
		$enableOpenCL = [bool]$OpenCL
		$mode = "Explicit"
	}
}

if ($enableCuda -and !(Test-CudaAvailable)) {
	$enableCuda = $false
}
if ($enableVulkan -and !(Test-VulkanAvailable)) {
	$enableVulkan = $false
}
if ($enableMetal -and !(Test-MetalAvailable)) {
	$enableMetal = $false
}
if ($enableOpenCL -and !(Test-OpenCLAvailable)) {
	$enableOpenCL = $false
}
if (!$BundledGgml) {
	if ($enableCuda -and !(Test-CoreGgmlLibraryAvailable -CorePath $OfxGgmlCorePath -WindowsLibraryName "ggml-cuda.lib" -UnixLibraryName "libggml-cuda.a")) {
		$enableCuda = $false
	}
	if ($enableVulkan -and !(Test-CoreGgmlLibraryAvailable -CorePath $OfxGgmlCorePath -WindowsLibraryName "ggml-vulkan.lib" -UnixLibraryName "libggml-vulkan.a")) {
		$enableVulkan = $false
	}
	if ($enableMetal -and !(Test-CoreGgmlLibraryAvailable -CorePath $OfxGgmlCorePath -WindowsLibraryName "ggml-metal.lib" -UnixLibraryName "libggml-metal.a")) {
		$enableMetal = $false
	}
	if ($enableOpenCL -and !(Test-CoreGgmlLibraryAvailable -CorePath $OfxGgmlCorePath -WindowsLibraryName "ggml-opencl.lib" -UnixLibraryName "libggml-opencl.a")) {
		$enableOpenCL = $false
	}
}

if ($Cuda -and !$enableCuda) {
	throw "CUDA was requested but CUDA Toolkit or ofxGgmlCore ggml-cuda runtime was not found. Build Core with CUDA first or use default -Auto to skip unavailable backends."
}
if ($Vulkan -and !$enableVulkan) {
	throw "Vulkan was requested but Vulkan SDK/tools or ofxGgmlCore ggml-vulkan runtime was not found. Build Core with Vulkan first or use default -Auto to skip unavailable backends."
}
if ($Metal -and !$enableMetal) {
	throw "Metal was requested but this host does not look like a macOS/Xcode environment or ofxGgmlCore ggml-metal runtime was not found."
}
if ($OpenCL -and !$enableOpenCL) {
	throw "OpenCL was requested but OpenCL tools/root or ofxGgmlCore ggml-opencl runtime was not found. Use default -Auto to skip unavailable backends."
}

$resolvedGenerator = Get-DefaultGenerator
$cmakeConfigure = @()
if (![string]::IsNullOrWhiteSpace($resolvedGenerator)) {
	$cmakeConfigure += @("-G", $resolvedGenerator)
	if (Test-WindowsHost -and $resolvedGenerator -like "Visual Studio*") {
		$cmakeConfigure += @("-A", "x64")
		if ($enableCuda -and $env:CUDA_PATH) {
			$cmakeConfigure += @("-T", "host=x64,cuda=$env:CUDA_PATH")
		}
	}
}
$cmakeConfigure += @(
	"-S", $SourceDir,
	"-B", $BuildDir,
	"-DCMAKE_INSTALL_PREFIX=$InstallDir",
	"-DWHISPER_BUILD_TESTS=OFF",
	"-DWHISPER_BUILD_EXAMPLES=$(Convert-ToOnOff $BuildExamples)",
	"-DWHISPER_BUILD_SERVER=$(Convert-ToOnOff $BuildServer)",
	"-DWHISPER_USE_SYSTEM_GGML=$(Convert-ToOnOff (!$BundledGgml))",
	"-DGGML_CUDA=$(Convert-ToOnOff $enableCuda)",
	"-DGGML_VULKAN=$(Convert-ToOnOff $enableVulkan)",
	"-DGGML_METAL=$(Convert-ToOnOff $enableMetal)",
	"-DGGML_OPENCL=$(Convert-ToOnOff $enableOpenCL)"
)
if (!$BundledGgml) {
	$cmakeConfigure += @(
		"-DCMAKE_PREFIX_PATH=$coreGgmlPackageRoot",
		"-Dggml_DIR=$coreGgmlPackageDir"
	)
}

if ($DryRun) {
	Write-Step "Dry run: whisper.cpp setup plan"
	Write-Host "  repo: $Repo"
	Write-Host "  revision: $Revision"
	Write-Host "  root: $runtimeRoot"
	Write-Host "  source: $SourceDir"
	Write-Host "  build: $BuildDir"
	Write-Host "  install: $InstallDir"
	Write-Host "  mode: $mode"
	Write-Host "  enabled backends: CPU=ON CUDA=$(Convert-ToOnOff $enableCuda) Vulkan=$(Convert-ToOnOff $enableVulkan) Metal=$(Convert-ToOnOff $enableMetal) OpenCL=$(Convert-ToOnOff $enableOpenCL)"
	Write-Host "  ggml: $ggmlMode"
	if (!$BundledGgml) {
		Write-Host "  ofxGgmlCore: $OfxGgmlCorePath"
		Write-Host "  generated ggml package: $coreGgmlPackageDir"
	}
	Write-Host "  examples: $(Convert-ToOnOff $BuildExamples)"
	Write-Host "  server: $(Convert-ToOnOff $BuildServer)"
	Write-Host "  jobs: $Jobs"
	Write-Host "  clean: $(Convert-ToOnOff $Clean)"
	Write-Host "cmake $($cmakeConfigure -join ' ')"
	Write-Host "cmake --build $BuildDir --config $Configuration --target whisper --parallel $Jobs"
	Write-Host "install selected whisper runtime artifacts from $BuildDir"
	Write-Step "Dry run complete; no files were changed"
	return
}

foreach ($tool in @("git", "cmake")) {
	if (!(Get-CommandPathOrNull $tool)) {
		throw "$tool was not found on PATH."
	}
}

if ($Clean -and (Test-Path -LiteralPath $BuildDir)) {
	Write-Step "Cleaning $BuildDir"
	Remove-Item -LiteralPath $BuildDir -Recurse -Force
}

if (!(Test-Path -LiteralPath $SourceDir -PathType Container)) {
	Write-Step "Cloning whisper.cpp"
	Invoke-Checked "git clone whisper.cpp" "git" @(
		"clone", "--recursive", "--depth", "1", "--branch", $Revision, $Repo, $SourceDir)
} else {
	Update-WhisperSource -Source $SourceDir -Revision $Revision
}

if (!$BundledGgml) {
	if (!(Test-Path -LiteralPath $OfxGgmlCorePath -PathType Container)) {
		throw "ofxGgmlCore was not found at: $OfxGgmlCorePath. Use -OfxGgmlCorePath or pass -BundledGgml."
	}
	Write-Step "Generating ggml CMake package from ofxGgmlCore"
	New-OfxGgmlCoreCmakePackage `
		-CorePath $OfxGgmlCorePath `
		-PackageRoot $coreGgmlPackageRoot `
		-EnableCuda:$enableCuda `
		-EnableVulkan:$enableVulkan | Out-Null
}

Write-Step "Configuring whisper.cpp"
Invoke-Checked "cmake configure whisper.cpp" "cmake" $cmakeConfigure

Write-Step "Building whisper.cpp"
Invoke-Checked "cmake build whisper.cpp" "cmake" @(
	"--build", $BuildDir,
	"--config", $Configuration,
	"--target", "whisper",
	"--parallel", [string]$Jobs)

Write-Step "Installing whisper.cpp runtime"
Clear-InstalledWhisperArtifacts -InstallDir $InstallDir
Install-WhisperRuntime -BuildDir $BuildDir -SourceDir $SourceDir -InstallDir $InstallDir

Write-WhisperBackendReport `
	-BuildDir $BuildDir `
	-InstallDir $InstallDir `
	-CorePath $OfxGgmlCorePath `
	-BundledGgml ([bool]$BundledGgml)

Write-Step "Done. whisper.cpp runtime installed under $InstallDir"
