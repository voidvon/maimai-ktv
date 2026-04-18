param(
  [Parameter(Mandatory = $true)]
  [string]$Repo,
  [Parameter(Mandatory = $true)]
  [string]$ZipPath,
  [string]$Tag,
  [string]$Token,
  [string]$AssetPrefix = 'maimai-ktv'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Require-Command {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Name
  )

  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Missing required command: $Name"
  }
}

function Get-ApiHeaders {
  param(
    [Parameter(Mandatory = $true)]
    [string]$GitHubToken
  )

  return @{
    Authorization = "token $GitHubToken"
    'User-Agent' = 'codex-windows-release-publisher'
  }
}

function Get-NormalizedVersion {
  param(
    [Parameter(Mandatory = $true)]
    [string]$FileName
  )

  if ($FileName -match '(\d+\.\d+\.\d+(?:-[A-Za-z0-9.\-]+)?)(?:\+\d+)?-windows-x64\.zip$') {
    return $Matches[1]
  }

  throw "Could not derive version from file name: $FileName"
}

function Get-ReleaseTag {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Repository,
    [Parameter(Mandatory = $true)]
    [string]$GitHubToken,
    [string]$RequestedTag
  )

  if (-not [string]::IsNullOrWhiteSpace($RequestedTag)) {
    return $RequestedTag
  }

  $headers = Get-ApiHeaders -GitHubToken $GitHubToken
  $release = Invoke-RestMethod -Headers $headers -Uri "https://api.github.com/repos/$Repository/releases/latest"
  return $release.tag_name
}

function Remove-ExistingAsset {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Repository,
    [Parameter(Mandatory = $true)]
    [string]$GitHubToken,
    [Parameter(Mandatory = $true)]
    [string]$ReleaseTag,
    [Parameter(Mandatory = $true)]
    [string]$AssetName
  )

  $headers = Get-ApiHeaders -GitHubToken $GitHubToken
  $release = Invoke-RestMethod -Headers $headers -Uri "https://api.github.com/repos/$Repository/releases/tags/$ReleaseTag"
  $existing = $release.assets | Where-Object { $_.name -eq $AssetName } | Select-Object -First 1
  if ($existing) {
    Invoke-RestMethod -Method Delete -Headers $headers -Uri "https://api.github.com/repos/$Repository/releases/assets/$($existing.id)" | Out-Null
  }
}

Require-Command -Name 'gh'

$resolvedZipPath = (Resolve-Path -LiteralPath $ZipPath).Path
$gitHubToken = if ([string]::IsNullOrWhiteSpace($Token)) { $env:GH_TOKEN } else { $Token }
if ([string]::IsNullOrWhiteSpace($gitHubToken)) {
  throw 'Provide -Token or set GH_TOKEN before uploading.'
}

$zipFileName = [System.IO.Path]::GetFileName($resolvedZipPath)
$version = Get-NormalizedVersion -FileName $zipFileName
$releaseTag = Get-ReleaseTag -Repository $Repo -GitHubToken $gitHubToken -RequestedTag $Tag
$assetName = "$AssetPrefix-v$version-windows-x64.zip"
$normalizedZipPath = Join-Path ([System.IO.Path]::GetDirectoryName($resolvedZipPath)) $assetName

if ($normalizedZipPath -ne $resolvedZipPath) {
  Copy-Item -LiteralPath $resolvedZipPath -Destination $normalizedZipPath -Force
}

Remove-ExistingAsset -Repository $Repo -GitHubToken $gitHubToken -ReleaseTag $releaseTag -AssetName $assetName

$env:GH_TOKEN = $gitHubToken
gh release upload $releaseTag $normalizedZipPath --repo $Repo --clobber

Write-Host "Uploaded $assetName to $Repo release $releaseTag" -ForegroundColor Green
