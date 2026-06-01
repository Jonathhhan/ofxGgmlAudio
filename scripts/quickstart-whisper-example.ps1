param(
	[string]$ModelName = "tiny.en",
	[string]$ModelPath = "",
	[string]$AudioPath = "",
	[string]$Language = "auto",
	[int]$Threads = 0,
	[string]$Configuration = "Release",
	[string]$Platform = "x64",
	[switch]$CpuOnly,
	[switch]$Cuda,
	[switch]$Vulkan,
	[switch]$BundledGgml,
	[switch]$Translate,
	[switch]$NoTimestamps,
	[switch]$SkipRuntime,
	[switch]$ForceRuntime,
	[switch]$SkipAssets,
	[switch]$BuildOnly,
	[switch]$DryRun
)

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $scriptRoot "quickstart-transcribe-example.ps1") `
	-Example whisper `
	-ModelName $ModelName `
	-ModelPath $ModelPath `
	-AudioPath $AudioPath `
	-Language $Language `
	-Threads $Threads `
	-Configuration $Configuration `
	-Platform $Platform `
	-CpuOnly:$CpuOnly `
	-Cuda:$Cuda `
	-Vulkan:$Vulkan `
	-BundledGgml:$BundledGgml `
	-Translate:$Translate `
	-NoTimestamps:$NoTimestamps `
	-SkipRuntime:$SkipRuntime `
	-ForceRuntime:$ForceRuntime `
	-SkipAssets:$SkipAssets `
	-BuildOnly:$BuildOnly `
	-DryRun:$DryRun
exit $LASTEXITCODE
