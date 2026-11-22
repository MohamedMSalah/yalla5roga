param([string] $DeviceId)

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $repo
try {
    if ($DeviceId) {
        pnpm run:android:device $DeviceId
    } else {
        pnpm build:apk:device
    }
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} finally {
    Pop-Location
}
