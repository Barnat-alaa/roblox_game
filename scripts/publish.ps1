# Publish THE LOCAL SOURCE to the Roblox place, in one command.
#
# Why this exists: Studio's "Publish to Roblox" uploads whatever is currently
# OPEN in Studio, which is not necessarily what is on disk. If you forget to
# reopen the rebuilt SocialCafe.rbxlx first, you silently ship stale scripts.
# This script removes Studio from the loop entirely: it builds straight from
# src/ and uploads that, so what you publish is always exactly your local code.
#
# Usage:
#   $env:ROBLOX_API_KEY = "<your Open Cloud key>"
#   ./scripts/publish.ps1              # gates, build, upload
#   ./scripts/publish.ps1 -SkipGates   # skip lint/format/test-build (not advised)
#
# Get the key at https://create.roblox.com/dashboard/credentials
#   - Add API key -> name it (e.g. "social-cafe-publish")
#   - Access Permissions: add the "universe-places" API System, pick this
#     universe, and enable the "write" scope
#   - Accepted IP: 0.0.0.0/0 (or your IP)
# NEVER commit the key. .gitignore already covers .env / *.key.

[CmdletBinding()]
param(
    [switch]$SkipGates,
    [string]$PlaceId = $env:ROBLOX_PLACE_ID,
    [string]$UniverseId = $env:ROBLOX_UNIVERSE_ID
)

$ErrorActionPreference = 'Stop'

# Defaults recorded in HANDOFF.md. Override with env vars to target another place.
if (-not $PlaceId) { $PlaceId = '85898641225605' }
if (-not $UniverseId) { $UniverseId = '10501568035' }

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

if (-not $env:ROBLOX_API_KEY) {
    Write-Host ''
    Write-Host 'ROBLOX_API_KEY is not set.' -ForegroundColor Red
    Write-Host 'Create one at https://create.roblox.com/dashboard/credentials with'
    Write-Host 'universe-places:write on this universe, then:'
    Write-Host '  $env:ROBLOX_API_KEY = "<key>"' -ForegroundColor Yellow
    exit 1
}

if (-not $SkipGates) {
    Write-Host '==> Gates' -ForegroundColor Cyan

    stylua --check src tests
    if ($LASTEXITCODE -ne 0) { Write-Host 'StyLua failed - run: stylua src tests' -ForegroundColor Red; exit 1 }

    selene src tests
    if ($LASTEXITCODE -ne 0) { Write-Host 'Selene failed' -ForegroundColor Red; exit 1 }

    # Both project files must build; the test place catches broken spec requires.
    rojo build test.project.json --output "$env:TEMP\socialcafe_test_check.rbxlx"
    if ($LASTEXITCODE -ne 0) { Write-Host 'Test place build failed' -ForegroundColor Red; exit 1 }

    Write-Host 'gates green' -ForegroundColor Green
}

Write-Host '==> Building local place file' -ForegroundColor Cyan
rojo build default.project.json --output SocialCafe.rbxlx
if ($LASTEXITCODE -ne 0) { Write-Host 'Build failed' -ForegroundColor Red; exit 1 }
$size = [math]::Round((Get-Item SocialCafe.rbxlx).Length / 1KB)
Write-Host "built SocialCafe.rbxlx ($size KB)" -ForegroundColor Green

Write-Host "==> Uploading to place $PlaceId (universe $UniverseId)" -ForegroundColor Cyan
rojo upload default.project.json `
    --asset_id $PlaceId `
    --universe_id $UniverseId `
    --api_key $env:ROBLOX_API_KEY
if ($LASTEXITCODE -ne 0) { Write-Host 'Upload failed' -ForegroundColor Red; exit 1 }

Write-Host ''
Write-Host 'PUBLISHED - the live place now runs your local source.' -ForegroundColor Green
Write-Host 'Live servers resolve the PROD DataStore; Studio playtests stay on DEV.' -ForegroundColor DarkGray
Write-Host "https://www.roblox.com/games/$PlaceId" -ForegroundColor DarkGray
