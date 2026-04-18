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
      throw "Command failed with exit code $LASTEXITCODE: $FilePath $($Arguments -join ' ')"
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

function Get-VisualStudioGenerator {
  $vswherePath = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
  if (Test-Path $vswherePath) {
    $installPath = & $vswherePath -latest -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($installPath)) {
      return 'Visual Studio 17 2022'
    }
  }
  return 'Visual Studio 17 2022'
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

if ($env:OS -ne 'Windows_NT') {
  throw 'This script must run on a Windows host.'
}

$repoRoot = Resolve-RepoRoot
$pubspecPath = Join-Path $repoRoot 'pubspec.yaml'
$version = Get-ProjectVersion -PubspecPath $pubspecPath
$generator = Get-VisualStudioGenerator
$modeLower = $Mode.ToLowerInvariant()
$architectures = Get-ArchMatrix -RequestedArch $Arch

$distRoot = Join-Path $repoRoot 'dist\windows'
if (-not (Test-Path $distRoot)) {
  New-Item -ItemType Directory -Path $distRoot | Out-Null
}

if (-not $SkipPubGet) {
  Invoke-Step -FilePath 'flutter' -Arguments @('pub', 'get') -WorkingDirectory $repoRoot
}

Invoke-Step -FilePath 'flutter' -Arguments @('build', 'windows', "--$modeLower", '--config-only', '--no-pub') -WorkingDirectory $repoRoot

foreach ($archConfig in $architectures) {
  $buildDir = Join-Path $repoRoot ("build\windows\{0}" -f $archConfig.Name)
  $outputDir = Join-Path $buildDir ("runner\{0}" -f $Mode)
  $zipPath = Join-Path $distRoot ("ktv2_example-{0}-windows-{1}.zip" -f $version, $archConfig.Name)

  if ($Clean -and (Test-Path $buildDir)) {
    Remove-Item -Recurse -Force $buildDir
  }

  Invoke-Step -FilePath 'cmake' -Arguments @(
    '-S', 'windows',
    '-B', $buildDir,
    '-G', $generator,
    '-A', $archConfig.CmakeArch,
    "-DFLUTTER_TARGET_PLATFORM=$($archConfig.FlutterTargetPlatform)"
  ) -WorkingDirectory $repoRoot

  Invoke-Step -FilePath 'cmake' -Arguments @(
    '--build', $buildDir,
    '--config', $Mode,
    '--target', 'INSTALL'
  ) -WorkingDirectory $repoRoot

  if (-not (Test-Path $outputDir)) {
    throw "Expected output directory not found: $outputDir"
  }

  if (-not $SkipZip) {
    if (Test-Path $zipPath) {
      Remove-Item -Force $zipPath
    }
    Compress-Archive -Path (Join-Path $outputDir '*') -DestinationPath $zipPath -CompressionLevel Optimal
    Write-Host "Created archive: $zipPath" -ForegroundColor Green
  } else {
    Write-Host "Build output: $outputDir" -ForegroundColor Green
  }
}
