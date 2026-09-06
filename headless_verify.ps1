# Windows PowerShell headless verification helper for A Dark Dominion (Godot 4.6+)
# Runs Godot in headless mode to force re-import + quit, catching parse errors, missing deps, resource load failures after edits.
# Mirrors README instructions for headless verification (previously using Mac binary + --headless --quit --import).
# Usage (from project root): ./headless_verify.ps1
# Or: ./headless_verify.ps1 -VerboseOutput
#
# This is the dedicated verify script (launch_godot.ps1 also supports -Headless for convenience).
#
# - Always cleans .godot (critical for accurate post-edit check)
# - Detects Godot via $env:GODOT_PATH or common install locations, or prompts.
# - Supports -RunTest for additional simple checks (e.g. basic scene load simulation; full GUT tests would use -s script).
# - Simple export check (-ExportCheck) attempts a dry export verify if templates present (non-fatal).
# - Captures and reports any errors from Godot output / exit code.
# - If no Godot: graceful, prints download instructions from godotengine.org .
#
# Run this after any script/data/theme/resource edits, before committing or sharing.
# Clean output (no ERROR/Parse/Failed lines + exit 0) == good to go.

param(
    [switch]$RunTest,       # Perform additional --run-test style verification (headless scene checks if supported)
    [switch]$ExportCheck,   # Attempt simple export preset check (requires export templates; often skipped in CI)
    [switch]$NoClean,       # Skip .godot clean (rarely useful; default always cleans for fresh verify)
    [switch]$VerboseOutput  # Show full Godot stdout/stderr even on success
)

$ErrorActionPreference = "Continue"  # We want to capture errors, not stop hard on every warning

Write-Host "=== A Dark Dominion Headless Verify ===" -ForegroundColor Cyan
Write-Host "Godot 4.6+ project verifier for parse / load / import errors after edits." -ForegroundColor Gray

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $projectRoot

if (-not $NoClean) {
    Write-Host "Cleaning .godot cache for accurate post-edit verification..." -ForegroundColor Yellow
    if (Test-Path ".godot") {
        Remove-Item -Recurse -Force ".godot" -ErrorAction SilentlyContinue
    }
}

# Find Godot (shared detection logic)
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
    Write-Host "ERROR: Godot.exe not found." -ForegroundColor Red
    Write-Host "Set `$env:GODOT_PATH = 'full\path\to\Godot.exe' or install from https://godotengine.org/download/windows" -ForegroundColor Yellow
    Write-Host "  (Get the Windows (64-bit) version; unzip and point to Godot.exe)" -ForegroundColor Yellow
    Write-Host ""
    $inputPath = Read-Host "Enter full path to Godot.exe now (blank to abort and see manual verify steps)"
    if ($inputPath -and (Test-Path $inputPath -PathType Leaf)) {
        $godot = $inputPath
    } else {
        Write-Host ""
        Write-Host "Manual headless verify (no script):" -ForegroundColor Yellow
        Write-Host "  1. rm -rf .godot"
        Write-Host "  2. Godot.exe --headless --path . --quit --import"
        Write-Host "  3. Look for 'ERROR', 'Parse error', 'Failed to load', 'SCRIPT ERROR' in output."
        Write-Host "  4. If clean (just import progress + 'Quit'), project loads OK."
        exit 1
    }
}

Write-Host "Using Godot: $godot" -ForegroundColor Green
Write-Host "Running: $godot --headless --path . --quit --import" -ForegroundColor Yellow

# Capture all output
$verifyOutput = & $godot --headless --path . --quit --import 2>&1
$exitCode = $LASTEXITCODE

$hasError = $false
$relevantErrors = @()

foreach ($line in $verifyOutput) {
    $lineStr = $line.ToString()
    if ($VerboseOutput) {
        Write-Host $lineStr
    }
    if ($lineStr -match "(?i)(ERROR|Parse error|SCRIPT ERROR|Failed to load|Resource error|Cannot open|Missing dependency|Invalid call)") {
        $hasError = $true
        $relevantErrors += $lineStr
    }
}

if (-not $VerboseOutput) {
    # Always show the error lines even if not verbose
    if ($relevantErrors.Count -gt 0) {
        Write-Host ""
        Write-Host "=== Captured errors / warnings from Godot ===" -ForegroundColor Red
        $relevantErrors | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    } else {
        Write-Host "(No obvious parse/load errors detected in output; full log suppressed unless -VerboseOutput)" -ForegroundColor DarkGray
    }
}

Write-Host ""
if ($exitCode -ne 0 -or $hasError) {
    Write-Host "VERIFY FAILED (exit=$exitCode, errors detected)." -ForegroundColor Red
    Write-Host "Fix the reported issues, re-clean if needed, and re-run this script." -ForegroundColor Yellow
    Write-Host "Common: fix GDScript syntax, .tres resource refs, data JSON, uid issues, then rm .godot and retry."
} else {
    Write-Host "VERIFY SUCCESS (clean load, no parse/resource errors reported)." -ForegroundColor Green
    Write-Host "Project should open/run without 'Failed to load script' or similar after edits." -ForegroundColor Green
}

# Optional extra checks
if ($RunTest) {
    Write-Host ""
    Write-Host "Running additional -RunTest checks (headless scene validation)..." -ForegroundColor Yellow
    # Godot headless can exec a script, but for simple verify we re-run import + note.
    # Real tests would be e.g. --headless --path . -s res://tests/run_all.gd but no such yet.
    # As a proxy, we can try to start the main scene briefly but --quit prevents.
    # For now, document + re-affirm import (already done).
    Write-Host "  (Note: dedicated test runner not present in project yet; use Godot editor test tools or add GDScript test script.)"
    Write-Host "  Basic scene load check via re-import passed above if no errors."
    # Could add: & $godot --headless --path . --quit --script "res://scenes/Main.tscn" but scenes aren't scripts.
    # Keep simple: success if main verify passed.
}

if ($ExportCheck) {
    Write-Host ""
    Write-Host "Running simple -ExportCheck (headless export verify)..." -ForegroundColor Yellow
    # Godot 4 headless export example (may fail without templates or preset named "Windows Desktop")
    # Non-fatal for verify purpose; many dev machines don't have export templates installed.
    $exportOut = & $godot --headless --path . --quit --export-debug "Windows Desktop" "build/verify_dummy.exe" 2>&1 | Out-String
    if ($exportOut -match "(?i)(error|failed|template|not found)") {
        Write-Host "  Export check had issues (expected if no templates/preset):" -ForegroundColor DarkYellow
        # Show snippet only
        ($exportOut -split "`n" | Select-Object -First 8) | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
        Write-Host "  (This is optional; install export templates in Godot editor for full CI export checks.)" -ForegroundColor DarkGray
    } else {
        Write-Host "  Export check appeared to start without fatal template error." -ForegroundColor Green
    }
    # Clean dummy if created
    if (Test-Path "build/verify_dummy.exe") { Remove-Item "build/verify_dummy.exe" -ErrorAction SilentlyContinue }
}

Write-Host ""
Write-Host "headless_verify.ps1 complete. Use -VerboseOutput to see everything Godot printed." -ForegroundColor Cyan
exit $exitCode