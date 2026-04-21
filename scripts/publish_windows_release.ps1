param(
  [ValidateSet('x64', 'arm64')]
  [string]$Arch = 'x64',
  [ValidateSet('Debug', 'Profile', 'Release')]
  [string]$Mode = 'Release',
  [string]$ReleaseEnvFile = '.release.env.local',
  [string]$ZipPath,
  [string]$UploadTarget,
  [string]$DownloadBaseUrl,
  [string]$ManifestFile = 'docs/public/latest.json',
  [string[]]$Note = @(),
  [string]$CommitMessage = 'docs(release): update windows latest manifest',
  [string]$GitRemote = 'origin',
  [string]$GitBranch = 'main',
  [switch]$SkipBuild,
  [switch]$SkipPubGet,
  [switch]$Clean,
  [switch]$SkipUpload,
  [switch]$SkipManifest,
  [switch]$CommitManifest,
  [switch]$Push,
  [switch]$DryRun
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
  }
  finally {
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
    throw "Failed to read version from $PubspecPath"
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

function Get-BuildNumber {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Version
  )

  if ($Version.Contains('+')) {
    return [int]$Version.Split('+')[1]
  }

  return 0
}

function Get-ReleaseEnvContent {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  if (-not (Test-Path $Path)) {
    return $null
  }

  return Get-Content $Path -Raw
}

function Get-ReleaseEnvValue {
  param(
    [string]$Content,
    [Parameter(Mandatory = $true)]
    [string]$Name
  )

  if ([string]::IsNullOrWhiteSpace($Content)) {
    return $null
  }

  $quotedMatch = [regex]::Match(
    $Content,
    "(?ms)^$([regex]::Escape($Name))='(.*?)'\s*(?:\r?\n|$)"
  )
  if ($quotedMatch.Success) {
    return $quotedMatch.Groups[1].Value
  }

  $plainMatch = [regex]::Match(
    $Content,
    "(?m)^$([regex]::Escape($Name))=(.+)$"
  )
  if ($plainMatch.Success) {
    $value = $plainMatch.Groups[1].Value.Trim()
    if (
      ($value.StartsWith("'") -and $value.EndsWith("'")) -or
      ($value.StartsWith('"') -and $value.EndsWith('"'))
    ) {
      return $value.Substring(1, $value.Length - 2)
    }

    return $value
  }

  return $null
}

function Resolve-DartCommand {
  $flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
  if ($null -ne $flutterCommand) {
    $flutterRoot = Split-Path -Parent (Split-Path -Parent $flutterCommand.Source)
    $flutterDart = Join-Path $flutterRoot 'bin\cache\dart-sdk\bin\dart.bat'
    if (Test-Path $flutterDart) {
      return $flutterDart
    }
  }

  $dartCommand = Get-Command dart -ErrorAction SilentlyContinue
  if ($null -ne $dartCommand) {
    return $dartCommand.Source
  }

  throw 'Unable to resolve dart or flutter.'
}

function Get-RepoRelativePath {
  param(
    [Parameter(Mandatory = $true)]
    [string]$RepoRoot,
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  $repoUri = [System.Uri]((Resolve-Path $RepoRoot).Path.TrimEnd('\') + '\')
  $pathUri = [System.Uri](Resolve-Path $Path).Path
  return [System.Uri]::UnescapeDataString(
    $repoUri.MakeRelativeUri($pathUri).ToString().Replace('/', '\')
  )
}

function Ensure-BuildToolsOnPath {
  $pathEntries = New-Object System.Collections.Generic.List[string]
  $currentPath = ($env:Path -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  foreach ($entry in $currentPath) {
    $pathEntries.Add($entry)
  }

  if (-not [string]::IsNullOrWhiteSpace($env:FLUTTER_HOME)) {
    $flutterBin = Join-Path $env:FLUTTER_HOME 'bin'
    if ((Test-Path $flutterBin) -and -not $pathEntries.Contains($flutterBin)) {
      $pathEntries.Insert(0, $flutterBin)
    }
  }

  $cmakeCandidates = @(
    'C:\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin',
    'C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin',
    'C:\Program Files\CMake\bin'
  )
  foreach ($candidate in $cmakeCandidates) {
    if ((Test-Path $candidate) -and -not $pathEntries.Contains($candidate)) {
      $pathEntries.Insert(0, $candidate)
      break
    }
  }

  $env:Path = ($pathEntries | Select-Object -Unique) -join ';'
}

function Get-Sha256 {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  return (Get-FileHash -Path $Path -Algorithm SHA256).Hash
}

function Join-RemotePath {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Base,
    [Parameter(Mandatory = $true)]
    [string]$Leaf
  )

  return $Base.TrimEnd('/') + '/' + $Leaf
}

function New-TemporarySshKeyFile {
  param(
    [Parameter(Mandatory = $true)]
    [string]$PrivateKey
  )

  $sshDir = Join-Path $env:USERPROFILE '.ssh'
  New-Item -ItemType Directory -Path $sshDir -Force | Out-Null

  $keyFile = Join-Path $sshDir ('maimai_release_key_' + [guid]::NewGuid().ToString('N'))
  $encoding = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($keyFile, (($PrivateKey -replace "`r`n", "`n") + "`n"), $encoding)

  $acl = New-Object System.Security.AccessControl.FileSecurity
  $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    "${env:USERDOMAIN}\${env:USERNAME}",
    'FullControl',
    'Allow'
  )
  $acl.SetAccessRuleProtection($true, $false)
  $acl.AddAccessRule($rule)
  [System.IO.File]::SetAccessControl($keyFile, $acl)

  return $keyFile
}

function Upload-AssetWithScp {
  param(
    [Parameter(Mandatory = $true)]
    [string]$AssetPath,
    [Parameter(Mandatory = $true)]
    [string]$RemoteTarget,
    [string]$PrivateKey,
    [string]$KnownHostsFile
  )

  if ($RemoteTarget -notmatch '^[^:]+:.+$') {
    throw "Remote upload target must use host:path, got: $RemoteTarget"
  }

  $parts = $RemoteTarget -split ':', 2
  $remoteHost = $parts[0]
  $remotePath = $parts[1]

  $sshArgs = @('-o', 'IdentitiesOnly=yes')
  if ([string]::IsNullOrWhiteSpace($KnownHostsFile)) {
    $sshArgs += @('-o', 'StrictHostKeyChecking=accept-new')
  }
  else {
    $sshArgs += @('-o', "UserKnownHostsFile=$KnownHostsFile", '-o', 'StrictHostKeyChecking=yes')
  }

  $keyFile = $null
  if (-not [string]::IsNullOrWhiteSpace($PrivateKey)) {
    $keyFile = New-TemporarySshKeyFile -PrivateKey $PrivateKey
    $sshArgs = @('-i', $keyFile) + $sshArgs
  }

  try {
    if ($null -ne $keyFile) {
      Invoke-Step -FilePath 'C:\Windows\System32\OpenSSH\ssh-keygen.exe' -Arguments @('-l', '-f', $keyFile)
    }
    Invoke-Step -FilePath 'C:\Windows\System32\OpenSSH\ssh.exe' -Arguments ($sshArgs + @($remoteHost, "mkdir -p '$remotePath'"))
    Invoke-Step -FilePath 'C:\Windows\System32\OpenSSH\scp.exe' -Arguments ($sshArgs + @($AssetPath, "${remoteHost}:${remotePath}/"))
    Invoke-Step -FilePath 'C:\Windows\System32\OpenSSH\ssh.exe' -Arguments ($sshArgs + @($remoteHost, "ls -l '$remotePath'"))
  }
  finally {
    if ($null -ne $keyFile -and (Test-Path $keyFile)) {
      Remove-Item -LiteralPath $keyFile -Force -ErrorAction SilentlyContinue
    }
  }
}

function Invoke-GitCommitForPath {
  param(
    [Parameter(Mandatory = $true)]
    [string]$RepoRoot,
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [Parameter(Mandatory = $true)]
    [string]$Message
  )

  $relativePath = Get-RepoRelativePath -RepoRoot $RepoRoot -Path $Path
  Invoke-Step -FilePath 'git' -Arguments @('add', '--', $relativePath) -WorkingDirectory $RepoRoot

  & git -C $RepoRoot diff --cached --quiet -- $relativePath
  if ($LASTEXITCODE -eq 0) {
    Write-Host "No staged changes for $relativePath, skipping commit." -ForegroundColor Yellow
    return $false
  }
  if ($LASTEXITCODE -ne 1) {
    throw "git diff --cached failed with exit code $LASTEXITCODE"
  }

  Invoke-Step -FilePath 'git' -Arguments @(
    '-c', 'user.name=Codex',
    '-c', 'user.email=codex@local',
    'commit',
    '--only',
    '--message', $Message,
    '--',
    $relativePath
  ) -WorkingDirectory $RepoRoot
  return $true
}

function Invoke-GitPush {
  param(
    [Parameter(Mandatory = $true)]
    [string]$RepoRoot,
    [Parameter(Mandatory = $true)]
    [string]$Remote,
    [Parameter(Mandatory = $true)]
    [string]$Branch
  )

  Invoke-Step -FilePath 'git' -Arguments @('push', $Remote, $Branch) -WorkingDirectory $RepoRoot
}

if ($env:OS -ne 'Windows_NT') {
  throw 'This script must run on a Windows host.'
}

$repoRoot = Resolve-RepoRoot
Set-Location $repoRoot
Ensure-BuildToolsOnPath

if ($Push -and -not $CommitManifest) {
  throw '-Push requires -CommitManifest so the script only pushes the manifest change it just wrote.'
}

$releaseEnvPath = if ([System.IO.Path]::IsPathRooted($ReleaseEnvFile)) {
  $ReleaseEnvFile
}
else {
  Join-Path $repoRoot $ReleaseEnvFile
}
$releaseEnvContent = Get-ReleaseEnvContent -Path $releaseEnvPath

$pubspecPath = Join-Path $repoRoot 'pubspec.yaml'
$version = Get-ProjectVersion -PubspecPath $pubspecPath
$displayVersion = Get-DisplayVersion -Version $version
$buildNumber = Get-BuildNumber -Version $version
$versionDirectory = "v$displayVersion"

if ([string]::IsNullOrWhiteSpace($UploadTarget)) {
  $UploadTarget = Get-ReleaseEnvValue -Content $releaseEnvContent -Name 'UPLOAD_TARGET'
}
if ([string]::IsNullOrWhiteSpace($DownloadBaseUrl)) {
  $DownloadBaseUrl = Get-ReleaseEnvValue -Content $releaseEnvContent -Name 'DOWNLOAD_BASE_URL'
}

$sshPrivateKey = Get-ReleaseEnvValue -Content $releaseEnvContent -Name 'SSH_PRIVATE_KEY'
$sshKnownHostsFile = Get-ReleaseEnvValue -Content $releaseEnvContent -Name 'SSH_KNOWN_HOSTS_FILE'

if (-not $SkipBuild) {
  $buildScript = Join-Path $repoRoot 'scripts\build_windows.ps1'
  $buildArguments = @(
    '-ExecutionPolicy', 'Bypass',
    '-File', $buildScript,
    '-Arch', $Arch,
    '-Mode', $Mode
  )
  if ($SkipPubGet) {
    $buildArguments += '-SkipPubGet'
  }
  if ($Clean) {
    $buildArguments += '-Clean'
  }
  Invoke-Step -FilePath 'powershell' -Arguments $buildArguments -WorkingDirectory $repoRoot
}

if ([string]::IsNullOrWhiteSpace($ZipPath)) {
  $ZipPath = Join-Path $repoRoot "dist\windows\maimai-ktv-v$displayVersion-windows-$Arch.zip"
}
elseif (-not [System.IO.Path]::IsPathRooted($ZipPath)) {
  $ZipPath = Join-Path $repoRoot $ZipPath
}

if (-not (Test-Path $ZipPath)) {
  throw "Windows ZIP not found: $ZipPath"
}

$assetName = Split-Path -Leaf $ZipPath
$publishedAt = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
$sha256 = Get-Sha256 -Path $ZipPath
$remoteTarget = if (-not [string]::IsNullOrWhiteSpace($UploadTarget)) {
  Join-RemotePath -Base $UploadTarget -Leaf $versionDirectory
}
else {
  $null
}
$publicBaseUrl = if (-not [string]::IsNullOrWhiteSpace($DownloadBaseUrl)) {
  Join-RemotePath -Base $DownloadBaseUrl -Leaf $versionDirectory
}
else {
  $null
}
$publicUrl = if ($null -ne $publicBaseUrl) {
  Join-RemotePath -Base $publicBaseUrl -Leaf $assetName
}
else {
  $null
}

if ($Note.Count -eq 0) {
  $Note = @(
    'Windows x64 desktop test package updated.',
    'This is an alpha prerelease build for testing.'
  )
}

if ($DryRun) {
  Write-Host 'Dry run only.' -ForegroundColor Yellow
  Write-Host "Version: $displayVersion"
  Write-Host "ZIP: $ZipPath"
  if (-not $SkipUpload) {
    Write-Host "Upload target: $remoteTarget"
    Write-Host "Public URL: $publicUrl"
  }
  if (-not $SkipManifest) {
    Write-Host "Manifest file: $ManifestFile"
  }
  if ($CommitManifest) {
    Write-Host "Commit manifest: yes"
    Write-Host "Commit message: $CommitMessage"
  }
  if ($Push) {
    Write-Host "Push target: $GitRemote/$GitBranch"
  }
  exit 0
}

if (-not $SkipUpload) {
  if ([string]::IsNullOrWhiteSpace($remoteTarget)) {
    throw 'UploadTarget is required unless -SkipUpload is set.'
  }

  Upload-AssetWithScp `
    -AssetPath $ZipPath `
    -RemoteTarget $remoteTarget `
    -PrivateKey $sshPrivateKey `
    -KnownHostsFile $sshKnownHostsFile
}

if (-not $SkipManifest) {
  if ([string]::IsNullOrWhiteSpace($publicUrl)) {
    throw 'DownloadBaseUrl is required unless -SkipManifest is set.'
  }

  $dartCommand = Resolve-DartCommand
  $manifestPath = if ([System.IO.Path]::IsPathRooted($ManifestFile)) {
    $ManifestFile
  }
  else {
    Join-Path $repoRoot $ManifestFile
  }

  $manifestArguments = @(
    'scripts/update_latest_manifest.dart',
    '--file', $manifestPath,
    '--platform', 'windows',
    '--version', $displayVersion,
    '--build-number', $buildNumber,
    '--published-at', $publishedAt,
    '--mode', 'external',
    '--url', $publicUrl,
    '--sha256', $sha256
  )
  foreach ($line in $Note) {
    if (-not [string]::IsNullOrWhiteSpace($line)) {
      $manifestArguments += @('--note', $line.Trim())
    }
  }

  Invoke-Step -FilePath $dartCommand -Arguments $manifestArguments -WorkingDirectory $repoRoot
}

$didCommitManifest = $false
if ($CommitManifest) {
  if ($SkipManifest) {
    throw '-CommitManifest cannot be used together with -SkipManifest.'
  }
  $didCommitManifest = Invoke-GitCommitForPath -RepoRoot $repoRoot -Path $manifestPath -Message $CommitMessage
}

if ($Push) {
  if (-not $didCommitManifest) {
    Write-Host 'Manifest commit was skipped because there was no diff to commit. Skipping push.' -ForegroundColor Yellow
  }
  else {
    Invoke-GitPush -RepoRoot $repoRoot -Remote $GitRemote -Branch $GitBranch
  }
}

Write-Host "Windows release ZIP: $ZipPath" -ForegroundColor Green
if ($null -ne $publicUrl) {
  Write-Host "Public URL: $publicUrl" -ForegroundColor Green
}
Write-Host "SHA256: $sha256" -ForegroundColor Green
if (-not $CommitManifest) {
  Write-Host 'Next step: commit and push docs/public/latest.json if you want VitePress /latest.json to go live.' -ForegroundColor Yellow
}
