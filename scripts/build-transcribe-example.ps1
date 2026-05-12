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

function Repair-VisualStudioProjectFile {
	param(
		[string]$Path,
		[string]$CoreRoot,
		[string]$AudioRoot,
		[string]$ImguiRoot
	)
	if (!(Test-Path -LiteralPath $Path -PathType Leaf)) {
		return
	}

	[xml]$doc = Get-Content -LiteralPath $Path -Raw
	$namespace = New-Object System.Xml.XmlNamespaceManager($doc.NameTable)
	$namespace.AddNamespace("msb", "http://schemas.microsoft.com/developer/msbuild/2003")
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
$exampleName = "ofxGgmlAudioTranscribeExample"
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
	Repair-VisualStudioProjectFile -Path $projectPath -CoreRoot $coreRoot -AudioRoot $addonRoot -ImguiRoot $imguiRoot
	Repair-VisualStudioProjectFile -Path "$projectPath.filters" -CoreRoot $coreRoot -AudioRoot $addonRoot -ImguiRoot $imguiRoot

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
