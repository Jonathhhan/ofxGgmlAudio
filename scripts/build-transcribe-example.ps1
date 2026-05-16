param(
	[ValidateSet("transcribe", "whisper")]
	[string]$Example = "transcribe",
	[string]$Configuration = "Release",
	[string]$Platform = "x64",
	[switch]$Clean,
	[switch]$WithWhisper,
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

function Invoke-ProjectGeneratorForExample {
	param(
		[string]$ProjectGenerator,
		[string]$OfRoot,
		[string]$ExampleRoot,
		[string]$ProjectPath,
		[string]$ExampleName
	)
	& $ProjectGenerator "-o$OfRoot" "-aofxGgmlCore,ofxGgmlAudio,ofxImGui" "-pvs" $ExampleRoot
	$exitCode = $LASTEXITCODE
	if ($exitCode -eq 0) {
		return
	}
	if (Test-Path -LiteralPath $ProjectPath -PathType Leaf) {
		Write-Warning "projectGenerator exited with code $exitCode after writing $ExampleName.vcxproj; continuing with project repair and build."
		return
	}
	throw "projectGenerator $ExampleName failed with exit code $exitCode"
}

function Get-RelativeProjectPath {
	param(
		[string]$ProjectDir,
		[string]$FilePath
	)
	$projectUri = [System.Uri]((Resolve-Path -LiteralPath $ProjectDir).Path.TrimEnd("\") + "\")
	$fileUri = [System.Uri](Resolve-Path -LiteralPath $FilePath).Path
	return [System.Uri]::UnescapeDataString(
		$projectUri.MakeRelativeUri($fileUri).ToString()).Replace("/", "\")
}

function Add-VisualStudioProjectItem {
	param(
		[xml]$Doc,
		[System.Xml.XmlNamespaceManager]$Namespace,
		[string]$Tag,
		[string]$Include,
		[string]$Filter = ""
	)
	$existing = $Doc.SelectSingleNode("//msb:$Tag[@Include='$Include']", $Namespace)
	if ($existing) {
		return $false
	}
	$itemGroups = @($Doc.SelectNodes("//msb:ItemGroup", $Namespace))
	$itemGroup = $null
	foreach ($group in $itemGroups) {
		if ($group.SelectSingleNode("msb:$Tag", $Namespace)) {
			$itemGroup = $group
			break
		}
	}
	if (!$itemGroup -and $itemGroups.Count -gt 0) {
		$itemGroup = $itemGroups[0]
	}
	if (!$itemGroup) {
		return $false
	}
	$item = $Doc.CreateElement($Tag, $Doc.DocumentElement.NamespaceURI)
	$item.SetAttribute("Include", $Include)
	if (![string]::IsNullOrWhiteSpace($Filter)) {
		$filterNode = $Doc.CreateElement("Filter", $Doc.DocumentElement.NamespaceURI)
		$filterNode.InnerText = $Filter
		[void]$item.AppendChild($filterNode)
	}
	[void]$itemGroup.AppendChild($item)
	return $true
}

function Test-GeneratedAddonPath {
	param([string]$Path)
	if ([string]::IsNullOrWhiteSpace($Path)) {
		return $false
	}
	$normalized = $Path -replace "/", "\"
	return ($normalized -match '(^|\\)libs\\ggml\\\.source(\\|$)') -or
		($normalized -match '(^|\\)libs\\ggml\\build[^\\]*(\\|$)') -or
		($normalized -match '(^|\\)libs\\whisper\\\.source(\\|$)') -or
		($normalized -match '(^|\\)libs\\whisper\\build[^\\]*(\\|$)')
}

function Add-AddonFilesToProject {
	param(
		[xml]$Doc,
		[System.Xml.XmlNamespaceManager]$Namespace,
		[string]$ProjectFile,
		[string]$AddonName,
		[string]$AddonPath,
		[string[]]$SourceRoots,
		[string[]]$Excludes = @()
	)
	$changed = $false
	$projectDir = Split-Path -Parent $ProjectFile
	$isFilters = $ProjectFile.EndsWith(".vcxproj.filters", [System.StringComparison]::OrdinalIgnoreCase)
	foreach ($sourceRootName in $SourceRoots) {
		$sourceRoot = Join-Path $AddonPath $sourceRootName
		if (!(Test-Path -LiteralPath $sourceRoot -PathType Container)) {
			continue
		}
		Get-ChildItem -LiteralPath $sourceRoot -Recurse -File | ForEach-Object {
			$relativeToAddon = Get-RelativeProjectPath -ProjectDir $AddonPath -FilePath $_.FullName
			if ($Excludes -contains $relativeToAddon) {
				return
			}
			$extension = $_.Extension.ToLowerInvariant()
			$tag = if ($extension -in @(".cpp", ".cxx", ".cc")) {
				"ClCompile"
			} elseif ($extension -in @(".h", ".hpp")) {
				"ClInclude"
			} else {
				""
			}
			if ([string]::IsNullOrWhiteSpace($tag)) {
				return
			}
			$relative = Get-RelativeProjectPath -ProjectDir $projectDir -FilePath $_.FullName
			$filter = if ($isFilters) {
				("addons\" + $AddonName + "\" + (Split-Path -Parent $relative).TrimStart(".\").Replace("..\", ""))
			} else {
				""
			}
			if (Add-VisualStudioProjectItem -Doc $Doc -Namespace $Namespace -Tag $tag -Include $relative -Filter $filter) {
				$changed = $true
			}
		}
	}
	return $changed
}

function Add-IncludeDirectory {
	param(
		[xml]$Doc,
		[System.Xml.XmlNamespaceManager]$Namespace,
		[string]$IncludeDir
	)
	$changed = $false
	$nodes = @($Doc.SelectNodes("//msb:AdditionalIncludeDirectories", $Namespace))
	foreach ($node in $nodes) {
		$parts = @($node.InnerText -split ";" | Where-Object { $_ })
		if ($parts -notcontains $IncludeDir) {
			$parts = @($IncludeDir) + $parts
			$node.InnerText = $parts -join ";"
			$changed = $true
		}
	}
	return $changed
}

function Get-OrCreateProjectChild {
	param(
		[xml]$Doc,
		[System.Xml.XmlNode]$Parent,
		[string]$Name
	)
	$child = $Parent.SelectSingleNode("msb:$Name", $script:ProjectNamespace)
	if ($child) {
		return $child
	}
	$child = $Doc.CreateElement($Name, $Doc.DocumentElement.NamespaceURI)
	[void]$Parent.AppendChild($child)
	return $child
}

function Add-ListValue {
	param(
		[System.Xml.XmlNode]$Node,
		[string]$Value,
		[string]$InheritedMacro = ""
	)
	$parts = @($Node.InnerText -split ";" | Where-Object { $_ })
	if ($parts -contains $Value) {
		$changed = $false
	} else {
		$parts = @($Value) + $parts
		$changed = $true
	}
	if (![string]::IsNullOrWhiteSpace($InheritedMacro) -and $parts -notcontains $InheritedMacro) {
		$parts += $InheritedMacro
		$changed = $true
	}
	$inherited = @($parts | Where-Object { $_ -like "%(*" })
	$regular = @($parts | Where-Object { $_ -notlike "%(*" })
	$Node.InnerText = ($regular + $inherited) -join ";"
	return $changed
}

function Add-CompilerDefinition {
	param(
		[xml]$Doc,
		[System.Xml.XmlNamespaceManager]$Namespace,
		[string]$Definition
	)
	$changed = $false
	$itemGroups = @($Doc.SelectNodes("//msb:ItemDefinitionGroup", $Namespace))
	foreach ($group in $itemGroups) {
		$clCompile = Get-OrCreateProjectChild -Doc $Doc -Parent $group -Name "ClCompile"
		$definitions = Get-OrCreateProjectChild -Doc $Doc -Parent $clCompile -Name "PreprocessorDefinitions"
		if (Add-ListValue -Node $definitions -Value $Definition -InheritedMacro "%(PreprocessorDefinitions)") {
			$changed = $true
		}
	}
	return $changed
}

function Add-LinkerLibraryDirectory {
	param(
		[xml]$Doc,
		[System.Xml.XmlNamespaceManager]$Namespace,
		[string]$LibraryDirectory
	)
	$changed = $false
	$itemGroups = @($Doc.SelectNodes("//msb:ItemDefinitionGroup", $Namespace))
	foreach ($group in $itemGroups) {
		$link = Get-OrCreateProjectChild -Doc $Doc -Parent $group -Name "Link"
		$directories = Get-OrCreateProjectChild -Doc $Doc -Parent $link -Name "AdditionalLibraryDirectories"
		if (Add-ListValue -Node $directories -Value $LibraryDirectory -InheritedMacro "%(AdditionalLibraryDirectories)") {
			$changed = $true
		}
	}
	return $changed
}

function Add-LinkerDependency {
	param(
		[xml]$Doc,
		[System.Xml.XmlNamespaceManager]$Namespace,
		[string]$Dependency
	)
	$changed = $false
	$itemGroups = @($Doc.SelectNodes("//msb:ItemDefinitionGroup", $Namespace))
	foreach ($group in $itemGroups) {
		$link = Get-OrCreateProjectChild -Doc $Doc -Parent $group -Name "Link"
		$dependencies = Get-OrCreateProjectChild -Doc $Doc -Parent $link -Name "AdditionalDependencies"
		if (Add-ListValue -Node $dependencies -Value $Dependency -InheritedMacro "%(AdditionalDependencies)") {
			$changed = $true
		}
	}
	return $changed
}

function Assert-WhisperRuntime {
	param([string]$AudioRoot)
	$required = @(
		(Join-Path $AudioRoot "libs\whisper\include\whisper.h"),
		(Join-Path $AudioRoot "libs\whisper\lib\whisper.lib"),
		(Join-Path $AudioRoot "libs\whisper\bin\whisper.dll")
	)
	foreach ($path in $required) {
		if (!(Test-Path -LiteralPath $path -PathType Leaf)) {
			throw "Whisper runtime is incomplete. Missing: $path. Run scripts\build-whisper.bat first, then rebuild with -WithWhisper."
		}
	}
}

function Assert-CoreGgmlRuntime {
	param([string]$CoreRoot)
	$required = @(
		(Join-Path $CoreRoot "libs\ggml\include\ggml.h"),
		(Join-Path $CoreRoot "libs\ggml\lib\ggml.lib"),
		(Join-Path $CoreRoot "libs\ggml\lib\ggml-base.lib"),
		(Join-Path $CoreRoot "libs\ggml\lib\ggml-cpu.lib")
	)
	foreach ($path in $required) {
		if (!(Test-Path -LiteralPath $path -PathType Leaf)) {
			throw "ofxGgmlCore ggml runtime is incomplete. Missing: $path. Run ..\ofxGgmlCore\scripts\setup-ggml.bat first."
		}
	}
}

function Copy-WhisperRuntimeDll {
	param(
		[string]$AudioRoot,
		[string]$ExampleRoot
	)
	$dllSource = Join-Path $AudioRoot "libs\whisper\bin\whisper.dll"
	$binRoot = Join-Path $ExampleRoot "bin"
	if (!(Test-Path -LiteralPath $dllSource -PathType Leaf)) {
		throw "Whisper runtime DLL was not found: $dllSource"
	}
	New-Item -ItemType Directory -Force -Path $binRoot | Out-Null
	Copy-Item -LiteralPath $dllSource -Destination (Join-Path $binRoot "whisper.dll") -Force
	Write-Step "Copied whisper.dll into the example bin folder"
}

function Repair-VisualStudioProjectFile {
	param(
		[string]$Path,
		[string]$CoreRoot,
		[string]$AudioRoot,
		[string]$ImguiRoot,
		[bool]$WithWhisper
	)
	if (!(Test-Path -LiteralPath $Path -PathType Leaf)) {
		return
	}

	[xml]$doc = Get-Content -LiteralPath $Path -Raw
	$namespace = New-Object System.Xml.XmlNamespaceManager($doc.NameTable)
	$namespace.AddNamespace("msb", "http://schemas.microsoft.com/developer/msbuild/2003")
	$script:ProjectNamespace = $namespace
	$changed = $false

	foreach ($tag in @("ClCompile", "ClInclude", "None", "CustomBuild", "CudaCompile", "Filter")) {
		$nodes = @($doc.SelectNodes("//msb:$tag[@Include]", $namespace))
		foreach ($node in $nodes) {
			$extension = [System.IO.Path]::GetExtension(($node.Include -replace "/", "\"))
			$headerCompiledAsSource = $tag -eq "ClCompile" -and $extension -in @(".h", ".hpp")
			if ((Test-GeneratedAddonPath $node.Include) -or $headerCompiledAsSource) {
				[void]$node.ParentNode.RemoveChild($node)
				$changed = $true
			}
		}
	}

	if ($Path.EndsWith(".vcxproj", [System.StringComparison]::OrdinalIgnoreCase)) {
		foreach ($includeDir in @(
			"..\..\ofxGgmlCore\src",
			"..\..\ofxGgmlCore\libs\ggml\include",
			"..\..\ofxGgmlAudio\src",
			"..\..\ofxGgmlAudio\libs\whisper\include",
			"..\..\ofxImGui\src",
			"..\..\ofxImGui\libs\imgui",
			"..\..\ofxImGui\libs\imgui\src",
			"..\..\ofxImGui\libs\imgui\backends",
			"..\..\ofxImGui\libs\imgui\extras"
		)) {
			if (Add-IncludeDirectory -Doc $doc -Namespace $namespace -IncludeDir $includeDir) {
				$changed = $true
			}
		}
		if ($WithWhisper) {
			if (Add-CompilerDefinition -Doc $doc -Namespace $namespace -Definition "OFXGGMLAUDIO_WITH_WHISPER") {
				$changed = $true
			}
			if (Add-LinkerLibraryDirectory -Doc $doc -Namespace $namespace -LibraryDirectory "..\..\ofxGgmlAudio\libs\whisper\lib") {
				$changed = $true
			}
			if (Add-LinkerDependency -Doc $doc -Namespace $namespace -Dependency "whisper.lib") {
				$changed = $true
			}
		}
		if (Add-LinkerLibraryDirectory -Doc $doc -Namespace $namespace -LibraryDirectory "..\..\ofxGgmlCore\libs\ggml\lib") {
			$changed = $true
		}
		foreach ($dependency in @("ggml.lib", "ggml-base.lib", "ggml-cpu.lib")) {
			if (Add-LinkerDependency -Doc $doc -Namespace $namespace -Dependency $dependency) {
				$changed = $true
			}
		}
	}

	if (Test-Path -LiteralPath $CoreRoot -PathType Container) {
		if (Add-AddonFilesToProject -Doc $doc -Namespace $namespace -ProjectFile $Path -AddonName "ofxGgmlCore" -AddonPath $CoreRoot -SourceRoots @("src")) {
			$changed = $true
		}
	}
	if (Add-AddonFilesToProject -Doc $doc -Namespace $namespace -ProjectFile $Path -AddonName "ofxGgmlAudio" -AddonPath $AudioRoot -SourceRoots @("src")) {
		$changed = $true
	}
	if (Test-Path -LiteralPath $ImguiRoot -PathType Container) {
		if (Add-AddonFilesToProject -Doc $doc -Namespace $namespace -ProjectFile $Path -AddonName "ofxImGui" -AddonPath $ImguiRoot -SourceRoots @("src", "libs\imgui\src", "libs\imgui\backends", "libs\imgui\extras") -Excludes @("src\EngineVk.cpp")) {
			$changed = $true
		}
	}

	if ($changed) {
		$doc.Save($Path)
		Write-Step "Updated generated project metadata in $(Split-Path -Leaf $Path)"
	}
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonRoot = Resolve-Path (Join-Path $scriptRoot "..")
$ofRoot = Split-Path -Parent (Split-Path -Parent $addonRoot)
$exampleName = if ($Example -eq "whisper") { "ofxGgmlAudioWhisperExample" } else { "ofxGgmlAudioTranscribeExample" }
$exampleLabel = if ($Example -eq "whisper") { "Whisper" } else { "Transcribe" }
$exampleRoot = Join-Path $addonRoot $exampleName
$projectPath = Join-Path $exampleRoot "$exampleName.vcxproj"
$addonsRoot = Split-Path -Parent $addonRoot
$coreRoot = Join-Path $addonsRoot "ofxGgmlCore"
$imguiRoot = Join-Path $addonsRoot "ofxImGui"

if (!(Test-Path -LiteralPath $exampleRoot -PathType Container)) {
	throw "Example directory was not found: $exampleRoot"
}

Normalize-WindowsPathEnvironment

if ($DryRun) {
	Write-Step "$exampleLabel example build plan"
	Write-Host "  example: $exampleRoot"
	Write-Host "  project: $projectPath"
	Write-Host "  configuration: $Configuration"
	Write-Host "  platform: $Platform"
	Write-Host "  clean: $(if ($Clean) { 'ON' } else { 'OFF' })"
	Write-Host "  with whisper: $(if ($WithWhisper) { 'ON' } else { 'OFF' })"
	Write-Host "  whisper runtime: $(Join-Path $addonRoot 'libs\whisper')"
	Write-Host "  projectGenerator: $(Find-ProjectGenerator -OfRoot $ofRoot)"
	Write-Host "  msbuild: $(Get-MsBuild)"
	return
}

if (Test-WindowsHost) {
	Assert-CoreGgmlRuntime -CoreRoot $coreRoot
	if (!(Test-Path -LiteralPath $projectPath -PathType Leaf)) {
		$projectGenerator = Find-ProjectGenerator -OfRoot $ofRoot
		if ([string]::IsNullOrWhiteSpace($projectGenerator)) {
			throw "Visual Studio project not found and projectGenerator.exe was not found under $ofRoot."
		}
		Write-Step "Generating $exampleName Visual Studio project"
		Invoke-ProjectGeneratorForExample -ProjectGenerator $projectGenerator -OfRoot $ofRoot -ExampleRoot $exampleRoot -ProjectPath $projectPath -ExampleName $exampleName
	}
	if ($WithWhisper) {
		Assert-WhisperRuntime -AudioRoot $addonRoot
	}
	Repair-VisualStudioProjectFile -Path $projectPath -CoreRoot $coreRoot -AudioRoot $addonRoot -ImguiRoot $imguiRoot -WithWhisper ([bool]$WithWhisper)
	Repair-VisualStudioProjectFile -Path "$projectPath.filters" -CoreRoot $coreRoot -AudioRoot $addonRoot -ImguiRoot $imguiRoot -WithWhisper $false

	$msbuild = Get-MsBuild
	if ([string]::IsNullOrWhiteSpace($msbuild)) {
		throw "MSBuild.exe was not found."
	}
	$target = if ($Clean) { "Rebuild" } else { "Build" }
	Write-Step "Building $exampleName $Configuration $Platform"
	Invoke-Checked "MSBuild $exampleName" {
		& $msbuild $projectPath /t:$target /p:Configuration=$Configuration /p:Platform=$Platform /p:TrackFileAccess=false /m:1 /nr:false
	}
	if ($WithWhisper) {
		Copy-WhisperRuntimeDll -AudioRoot $addonRoot -ExampleRoot $exampleRoot
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
