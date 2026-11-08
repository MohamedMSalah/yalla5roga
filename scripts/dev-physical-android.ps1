#Requires -Version 5.1
<#
.SYNOPSIS
  Prepare (and optionally launch) Flutter against a physical Android device
  talking to the local Express API on this PC's LAN IPv4.

.DESCRIPTION
  - Detects an active LAN IPv4 (prefers Wi-Fi / default-route interfaces).
  - Copies flutter/.env -> flutter/.env.device and overrides API_BASE_URL.
  - Does not start an Android emulator.
  - Does not hardcode an IP into committed source.

.PARAMETER PrepareOnly
  Only write .env.device; do not run flutter.

.PARAMETER DeviceId
  Flutter/ADB device id. Default: first connected android-* device that is not an emulator.

.PARAMETER Port
  Backend port (default 3000).

.PARAMETER SkipRun
  Alias-friendly switch equivalent to -PrepareOnly.
#>
[CmdletBinding()]
param(
  [switch]$PrepareOnly,
  [switch]$SkipRun,
  [string]$DeviceId = "",
  [int]$Port = 3000
)

$ErrorActionPreference = "Stop"

# Script lives at <repo>/scripts/dev-physical-android.ps1
$repoRoot = Split-Path -Parent $PSScriptRoot
$flutterDir = Join-Path $repoRoot "flutter"
if (-not (Test-Path $flutterDir)) {
  throw "Flutter project not found at $flutterDir"
}
$envSource = Join-Path $flutterDir ".env"
$envDevice = Join-Path $flutterDir ".env.device"
$adb = Join-Path $env:LOCALAPPDATA "Android\sdk\platform-tools\adb.exe"

function Get-PreferredLanIPv4 {
  # Prefer the interface used by the default IPv4 route, Wi-Fi first on ties.
  $routes = @(Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue |
    Sort-Object RouteMetric, InterfaceMetric)

  $preferredAliases = @()
  foreach ($route in $routes) {
    $preferredAliases += $route.InterfaceAlias
  }

  $candidates = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object {
      $_.IPAddress -notlike "127.*" -and
      $_.IPAddress -notlike "169.254.*" -and
      $_.PrefixOrigin -ne "WellKnown"
    })

  # Prefer Wi-Fi among default-route interfaces first.
  foreach ($alias in ($preferredAliases | Select-Object -Unique)) {
    if ($alias -notmatch "Wi-?Fi|WLAN") { continue }
    $match = $candidates | Where-Object { $_.InterfaceAlias -eq $alias } |
      Select-Object -First 1
    if ($null -ne $match) { return $match.IPAddress }
  }

  foreach ($alias in ($preferredAliases | Select-Object -Unique)) {
    $match = $candidates | Where-Object { $_.InterfaceAlias -eq $alias } |
      Select-Object -First 1
    if ($null -ne $match) { return $match.IPAddress }
  }

  $wifi = $candidates | Where-Object { $_.InterfaceAlias -match "Wi-?Fi|WLAN" } |
    Select-Object -First 1
  if ($null -ne $wifi) { return $wifi.IPAddress }

  $first = $candidates | Select-Object -First 1
  if ($null -ne $first) { return $first.IPAddress }

  throw "No usable LAN IPv4 address found. Connect this PC to the same network as the phone."
}

function Write-DeviceEnv {
  param([string]$LanIp)

  if (-not (Test-Path $envSource)) {
    throw "Missing $envSource. Copy flutter/.env.example to flutter/.env and fill Firebase client values first."
  }

  $content = Get-Content -LiteralPath $envSource -Raw
  $apiLine = "API_BASE_URL=http://${LanIp}:${Port}"
  if ($content -match "(?m)^API_BASE_URL=.*$") {
    $content = [regex]::Replace($content, "(?m)^API_BASE_URL=.*$", $apiLine)
  }
  else {
    $content = $apiLine + [Environment]::NewLine + $content
  }

  # Ensure APP_ENV stays development for physical-device debug work.
  if ($content -match "(?m)^APP_ENV=.*$") {
    $content = [regex]::Replace($content, "(?m)^APP_ENV=.*$", "APP_ENV=development")
  }

  Set-Content -LiteralPath $envDevice -Value $content -NoNewline
  Write-Host "Wrote $envDevice"
  Write-Host "  $apiLine"
}

function Get-PhysicalAndroidDeviceId {
  Push-Location $flutterDir
  try {
    $lines = @(flutter devices --machine 2>$null | Out-String)
    if ([string]::IsNullOrWhiteSpace($lines)) {
      # Fallback: parse text output
      $text = flutter devices 2>&1 | Out-String
      if ($text -match "•\s+(\S+)\s+•\s+android-arm") {
        return $Matches[1]
      }
      throw "No physical Android device detected via flutter devices."
    }

    $jsonText = (flutter devices --machine 2>&1 | Where-Object { $_ -is [string] }) -join "`n"
    # flutter devices --machine prints JSON array
    $devices = $jsonText | ConvertFrom-Json
    $physical = @(
      $devices |
        Where-Object {
          $_.targetPlatform -like "android-*" -and
          -not $_.emulator -and
          $_.id -notlike "emulator-*"
        }
    )
    if ($physical.Count -eq 0) {
      throw "No physical Android device detected. Enable USB debugging and authorize this PC."
    }
    return $physical[0].id
  }
  finally {
    Pop-Location
  }
}

Write-Host "Detecting LAN IPv4..."
$lanIp = Get-PreferredLanIPv4
Write-Host "Using LAN IP: $lanIp (port $Port)"

Write-DeviceEnv -LanIp $lanIp

if ($PrepareOnly -or $SkipRun) {
  Write-Host "Prepare-only complete. Launch with:"
  Write-Host "  cd flutter"
  Write-Host "  flutter run -d <deviceId> --dart-define-from-file=.env.device"
  exit 0
}

if (Test-Path $adb) {
  Write-Host "ADB devices:"
  & $adb devices -l
}
else {
  Write-Host "Warning: adb.exe not found at $adb (Flutter may still see the device)."
}

if ([string]::IsNullOrWhiteSpace($DeviceId)) {
  $DeviceId = Get-PhysicalAndroidDeviceId
}
Write-Host "Flutter device: $DeviceId"

Push-Location $flutterDir
try {
  flutter run -d $DeviceId --dart-define-from-file=.env.device
}
finally {
  Pop-Location
}
