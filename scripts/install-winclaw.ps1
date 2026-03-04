# WinClaw native Windows installer (PowerShell, no WSL)
# Usage:
#   iwr -useb https://raw.githubusercontent.com/slimelab-ai/winclaw/main/scripts/install-winclaw.ps1 | iex

$ErrorActionPreference = "Stop"

function Test-Admin {
  $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
  Write-Error "Run this installer from an Administrator PowerShell window."
  exit 1
}

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
  winget install OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements | Out-Null
}
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  winget install Git.Git --accept-package-agreements --accept-source-agreements | Out-Null
}
if (-not (Get-Command pnpm -ErrorAction SilentlyContinue)) {
  npm install -g pnpm | Out-Null
}

$serviceUser = $env:WINCLAW_SERVICE_USER
if ([string]::IsNullOrWhiteSpace($serviceUser)) {
  $serviceUser = Read-Host "Windows user for Gateway scheduled task (e.g. spongebob or PC\spongebob)"
}
if ([string]::IsNullOrWhiteSpace($serviceUser)) {
  Write-Error "Service user cannot be empty."
  exit 1
}
$serviceUser = $serviceUser.Trim()
$env:OPENCLAW_WINDOWS_SERVICE_USER = $serviceUser

function Resolve-UserProfilePath([string]$Account) {
  $leaf = if ($Account -match "\\") { ($Account -split "\\")[-1] } else { $Account }
  $profile = Get-CimInstance Win32_UserProfile |
    Where-Object { $_.LocalPath -match ("\\" + [regex]::Escape($leaf) + "$") } |
    Select-Object -First 1 -ExpandProperty LocalPath
  if ([string]::IsNullOrWhiteSpace($profile)) {
    return "C:\Users\$leaf"
  }
  return $profile
}

$serviceProfile = Resolve-UserProfilePath $serviceUser
$serviceHome = Join-Path $serviceProfile ".openclaw"

# Install/configure using the selected service user's home paths.
$env:USERPROFILE = $serviceProfile
$env:HOME = $serviceProfile
$env:OPENCLAW_HOME = $serviceHome
$env:NPM_CONFIG_PREFIX = Join-Path $serviceProfile "AppData\Roaming\npm"

$repoDir = Join-Path $serviceProfile "winclaw"
if (Test-Path $repoDir) {
  git -C $repoDir fetch origin
  git -C $repoDir reset --hard origin/main
} else {
  git clone https://github.com/slimelab-ai/winclaw.git $repoDir
}

pnpm --dir $repoDir install
pnpm --dir $repoDir build
npm install -g $repoDir

Write-Host ""
Write-Host "OPENCLAW_WINDOWS_SERVICE_USER=$($env:OPENCLAW_WINDOWS_SERVICE_USER)"
Write-Host "OPENCLAW_HOME=$($env:OPENCLAW_HOME)"
openclaw onboard
