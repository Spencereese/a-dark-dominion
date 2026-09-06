# Windows PowerShell launcher for A Dark Dominion (Godot 4.6+ project)
# Mirrors the Mac launch_godot.sh that cleans .godot, optionally wipes save, launches Godot.
# Usage: From project root (where this .ps1 is): ./launch_godot.ps1
# Or right-click -> Run with PowerShell.
#
# Requirements: Godot 4.6+ .exe
# - Set env: $env:GODOT_PATH = "C:\Path\To\Godot.exe"
# - Or place in common location (script searches Downloads, Program Files, etc.)
# - Or the script will prompt you for the path.
#
# Save wipe (user://save_auto.json) path is %APPDATA%\Godot\app_userdata\<SaveName>\
# - Configurable via -SaveName "A Dark Dominion" or $env:GODOT_SAVEDATA_NAME
# - Use -NoCleanSave to keep progress between launches (commented in sh equivalent).
#
# After any .gd / theme / resource / data edit: always run this (or headless_verify.ps1) or manually clean .godot to avoid parse errors.
# In game: use "Reset (New Game)" button for different moral paths (kind vs harsh choices affect faction visuals, Memory, available production/defenses).
# Print instructions for clean start.

param(
    [switch]$Headless,          # Run in headless mode for verification (import/quit) - convenience; prefer headless_verify.ps1 for dedicated checks
    [switch]$NoCleanSave,       # Keep previous save (default cleans for fresh "first ember" start)
    [string]$SaveName = $env:GODOT_SAVEDATA_NAME   # Override Godot app_userdata folder name (defaults to project name "A Dark Dominion")
)

$ErrorActionPreference = "Stop"

if (-not $SaveName) { $SaveName = "A Dark Dominion" }

Write-Host "=== A Dark Dominion Windows Launcher ===" -ForegroundColor Cyan

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $projectRoot

Write-Host "Cleaning .godot cache (required after edits to prevent parse/missing dep errors)..." -ForegroundColor Yellow
if (Test-Path ".godot") {
    Remove-Item -Recurse -Force ".godot" -ErrorAction SilentlyContinue
}

if (-not $NoCleanSave) {
    Write-Host "Preparing clean start for play session (deleting previous auto save)..." -ForegroundColor Yellow
    $appdata = $env:APPDATA
    if (-not $appdata) { $appdata = "$env:USERPROFILE\AppData\Roaming" }
    $saveDir = Join-Path $appdata "Godot\app_userdata\$SaveName"
    Write-Host "  (using save dir for '$SaveName': $saveDir )" -ForegroundColor DarkGray
    if (Test-Path $saveDir) {
        Remove-Item -Force (Join-Path $saveDir "save_auto.json") -ErrorAction SilentlyContinue
        Remove-Item -Force (Join-Path $saveDir "save_auto.json.bak") -ErrorAction SilentlyContinue
    }
}

# Find Godot
$godot = $env:GODOT_PATH
if (-not $godot -or -not (Test-Path $godot -PathType Leaf)) {
    $candidates = @(
        "$env:LOCALAPPDATA\Programs\Godot\Godot.exe",
        "C:\Program Files\Godot\Godot.exe",
        "C:\Program Files (x86)\Godot\Godot.exe",
        "$env:USERPROFILE\Downloads\Godot\Godot.exe",
        "$env:USERPROFILE\Downloads\Godot_v*_*_*\Godot.exe",
        "$env:USERPROFILE\Downloads\Godot*.exe",
        "C:\Users\PC\Tools\Godot\Godot_v4.6.3-stable_win64_console.exe",
        "C:\Users\PC\Tools\Godot\Godot_v4.6.3-stable_win64.exe",
        "C:\Godot\Godot.exe",
        "$env:ProgramFiles\Godot\Godot.exe"
    )
    foreach ($c in $candidates) {
        try {
            $found = Get-ChildItem -Path $c -File -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
            if ($found) {
                $godot = $found
                break
            }
        } catch {}
    }
}

if (-not $godot -or -not (Test-Path $godot -PathType Leaf)) {
    Write-Host "ERROR: Godot.exe not found in common locations or via `$env:GODOT_PATH." -ForegroundColor Red
    Write-Host ""
    Write-Host "To fix:" -ForegroundColor Yellow
    Write-Host "  1. Download Godot 4.6+ for Windows from https://godotengine.org/download/windows (get the .zip or installer, Godot.exe)" -ForegroundColor Yellow
    Write-Host "  2. Set permanent env var: `$env:GODOT_PATH = 'C:\Path\To\Your\Godot.exe'  (add to your profile for persistence)"
    Write-Host "  3. Or re-run and provide path when prompted."
    Write-Host ""
    $inputPath = Read-Host "Enter full path to Godot.exe now (blank to abort)"
    if ($inputPath -and (Test-Path $inputPath -PathType Leaf)) {
        $godot = $inputPath
    } else {
        Write-Host "No valid Godot path provided. Aborting." -ForegroundColor Red
        Write-Host "After installing, you can also just run: Godot.exe --path .   (after manual rm -rf .godot)"
        exit 1
    }
}

Write-Host "Using Godot: $godot" -ForegroundColor Green

if ($Headless) {
    Write-Host "Running headless verify (import + quit) to check for parse/resource errors after edits..." -ForegroundColor Yellow
    & $godot --headless --path . --quit --import
    Write-Host "Headless verify complete. Check output above for errors (clean means good)." -ForegroundColor Green
} else {
    Write-Host "Ensuring fresh import (after .godot clean) so textures/resources are ready before _ready loads..." -ForegroundColor Yellow
    & $godot --headless --path . --quit --import 2>&1 | Out-Null
    Write-Host "Launching: $godot --path ." -ForegroundColor Green
    Write-Host "(Clean start. Use the in-game 'Reset (New Game)' button anytime to restart / try different moral paths. Look to the right sidebar under 'Actions' for buttons like 'Nurture the Ember'. Watch the log and map for the story. After edits always clean .godot or re-run this script.)" -ForegroundColor Gray
    & $godot --path .
}

Write-Host "Done." -ForegroundColor Cyan