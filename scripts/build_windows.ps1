param(
  [ValidateSet('x64', 'arm64', 'all')]
  [string[]]$Arch = @('all'),
  [ValidateSet('Debug', 'Profile', 'Release')]
  [string]$Mode = 'Release',
  [switch]$SkipPubGet,
  [switch]$SkipZip,
  [switch]$Clean
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-Step {
  param(
    [Parameter(Mandatory = $true)]
    [string]$FilePath,
    [string[]]$Arguments = @(),
    [string]$WorkingDirectory = (Get-Location).Path
  )

  Write-Host "==> $FilePath $($Arguments -join ' ')" -ForegroundColor Cyan
  $oldLocation = Get-Location
  try {
    Set-Location $WorkingDirectory
    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
      throw "Command failed with exit code ${LASTEXITCODE}: $FilePath $($Arguments -join ' ')"
    }
  } finally {
    Set-Location $oldLocation
  }
}

function Resolve-RepoRoot {
  return (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}

function Get-ProjectVersion {
  param(
    [Parameter(Mandatory = $true)]
    [string]$PubspecPath
  )

  $versionLine = Select-String -Path $PubspecPath -Pattern '^\s*version:\s*(.+)\s*$' | Select-Object -First 1
  if ($null -eq $versionLine) {
    return 'unknown'
  }
  return $versionLine.Matches[0].Groups[1].Value.Trim()
}

function Get-DisplayVersion {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Version
  )

  if ($Version.Contains('+')) {
    return $Version.Split('+')[0]
  }

  return $Version
}

function Get-VisualStudioGeneratorInfo {
  $vswherePath = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
  if (Test-Path $vswherePath) {
    $installPath = & $vswherePath -latest -requires Microsoft.VisualStudio.Component.VC.Tools.ARM64 -property installationPath
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($installPath)) {
      return [pscustomobject]@{
        Generator = 'Visual Studio 17 2022'
        InstancePath = $installPath.Trim()
      }
    }

    $installPath = & $vswherePath -latest -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($installPath)) {
      return [pscustomobject]@{
        Generator = 'Visual Studio 17 2022'
        InstancePath = $installPath.Trim()
      }
    }
  }
  return [pscustomobject]@{
    Generator = 'Visual Studio 17 2022'
    InstancePath = $null
  }
}

function Get-ArchMatrix {
  param(
    [string[]]$RequestedArch
  )

  $normalized = @()
  foreach ($item in $RequestedArch) {
    if ($item -eq 'all') {
      $normalized += @('x64', 'arm64')
    } else {
      $normalized += $item
    }
  }

  return $normalized |
    Select-Object -Unique |
    ForEach-Object {
      if ($_ -eq 'x64') {
        [pscustomobject]@{
          Name = 'x64'
          CmakeArch = 'x64'
          FlutterTargetPlatform = 'windows-x64'
        }
      } else {
        [pscustomobject]@{
          Name = 'arm64'
          CmakeArch = 'ARM64'
          FlutterTargetPlatform = 'windows-arm64'
        }
      }
    }
}

function Test-FlutterWindowsArm64Artifacts {
  param(
    [Parameter(Mandatory = $true)]
    [string]$FlutterRoot
  )

  $arm64ReleaseDir = Join-Path $FlutterRoot 'bin\cache\artifacts\engine\windows-arm64-release'
  return Test-Path $arm64ReleaseDir
}

function Clear-SharedFlutterWindowsOutputs {
  param(
    [Parameter(Mandatory = $true)]
    [string]$RepoRoot
  )

  $sharedPaths = @(
    (Join-Path $RepoRoot 'build\native_assets\windows'),
    (Join-Path $RepoRoot 'build\flutter_assets'),
    (Join-Path $RepoRoot 'build\windows\app.so')
  )

  foreach ($path in $sharedPaths) {
    if (Test-Path $path) {
      Remove-Item -Recurse -Force $path
    }
  }
}

function Compress-DirectoryToZip {
  param(
    [Parameter(Mandatory = $true)]
    [string]$SourceDirectory,
    [Parameter(Mandatory = $true)]
    [string]$DestinationPath
  )

  if (Test-Path $DestinationPath) {
    Remove-Item -Force $DestinationPath
  }

  $tarCommand = Get-Command tar.exe -ErrorAction SilentlyContinue
  if ($null -ne $tarCommand) {
    Invoke-Step -FilePath $tarCommand.Source -Arguments @(
      '-a',
      '-c',
      '-f',
      $DestinationPath,
      '-C',
      $SourceDirectory,
      '.'
    )
    return
  }

  Compress-Archive -Path (Join-Path $SourceDirectory '*') -DestinationPath $DestinationPath -CompressionLevel Optimal
}

if ($env:OS -ne 'Windows_NT') {
  throw 'This script must run on a Windows host.'
}

$repoRoot = Resolve-RepoRoot
$pubspecPath = Join-Path $repoRoot 'pubspec.yaml'
$version = Get-ProjectVersion -PubspecPath $pubspecPath
$displayVersion = Get-DisplayVersion -Version $version
$generatorInfo = Get-VisualStudioGeneratorInfo
$generator = $generatorInfo.Generator
$modeLower = $Mode.ToLowerInvariant()
$architectures = Get-ArchMatrix -RequestedArch $Arch

$distRoot = Join-Path $repoRoot 'dist\windows'
if (-not (Test-Path $distRoot)) {
  New-Item -ItemType Directory -Path $distRoot | Out-Null
}

if (-not $SkipPubGet) {
  Invoke-Step -FilePath 'flutter' -Arguments @('pub', 'get') -WorkingDirectory $repoRoot
}

foreach ($archConfig in $architectures) {
  $buildDir = Join-Path $repoRoot ("build\windows\{0}" -f $archConfig.Name)
  $outputDir = Join-Path $buildDir ("runner\{0}" -f $Mode)
  $zipPath = Join-Path $distRoot ("maimai-ktv-v{0}-windows-{1}.zip" -f $displayVersion, $archConfig.Name)

  if ($Clean -and (Test-Path $buildDir)) {
    Remove-Item -Recurse -Force $buildDir
  }
  if ($Clean) {
    Clear-SharedFlutterWindowsOutputs -RepoRoot $repoRoot
  }

  if ($archConfig.Name -eq 'arm64') {
    $flutterCommand = Get-Command flutter -ErrorAction Stop
    $flutterRoot = Split-Path -Parent (Split-Path -Parent $flutterCommand.Source)
    if (-not (Test-FlutterWindowsArm64Artifacts -FlutterRoot $flutterRoot)) {
      throw "Flutter SDK at '$flutterRoot' does not contain Windows ARM64 engine artifacts. Install an SDK that includes 'bin\\cache\\artifacts\\engine\\windows-arm64-release' before building arm64."
    }
  }

  Invoke-Step -FilePath 'flutter' -Arguments @(
    'build', 'windows',
    "--$modeLower",
    '--config-only',
    '--no-pub'
  ) -WorkingDirectory $repoRoot

  # Flutter desktop writes native assets and AOT outputs into shared `build/`
  # paths. Clear them here so the following CMake/tool_backend pass must
  # regenerate the current architecture's artifacts.
  Clear-SharedFlutterWindowsOutputs -RepoRoot $repoRoot

  $cmakeArguments = @(
    '-S', 'windows',
    '-B', $buildDir,
    '-G', $generator,
    '-A', $archConfig.CmakeArch,
    "-DFLUTTER_TARGET_PLATFORM=$($archConfig.FlutterTargetPlatform)"
  )

  if (-not [string]::IsNullOrWhiteSpace($generatorInfo.InstancePath)) {
    $cmakeArguments += "-DCMAKE_GENERATOR_INSTANCE=$($generatorInfo.InstancePath)"
  }

  Invoke-Step -FilePath 'cmake' -Arguments $cmakeArguments -WorkingDirectory $repoRoot

  Invoke-Step -FilePath 'cmake' -Arguments @(
    '--build', $buildDir,
    '--config', $Mode,
    '--target', 'INSTALL'
  ) -WorkingDirectory $repoRoot

  if (-not (Test-Path $outputDir)) {
    throw "Expected output directory not found: $outputDir"
  }

  if (-not $SkipZip) {
    Compress-DirectoryToZip -SourceDirectory $outputDir -DestinationPath $zipPath
    Write-Host "Created archive: $zipPath" -ForegroundColor Green
  } else {
    Write-Host "Build output: $outputDir" -ForegroundColor Green
  }
}
