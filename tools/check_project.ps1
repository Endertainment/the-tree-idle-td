<#
.SYNOPSIS
    Headless sanity check for the Godot project: imports assets, scans scripts, fails on parse errors.

.DESCRIPTION
    Resolves the Godot executable from -GodotBin, $env:GODOT_BIN, or tools/godot_path.txt.
    Runs `--headless --import` and treats any parse/script error as a failure.
    Exit codes: 0 = clean, 1 = project errors, 2 = Godot binary not found, 3 = Godot crashed.

.EXAMPLE
    pwsh -File tools/check_project.ps1

.EXAMPLE
    pwsh -File tools/check_project.ps1 -VerboseLog
#>
[CmdletBinding()]
param(
    [string]$GodotBin = $env:GODOT_BIN,
    [switch]$VerboseLog
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot

if (-not $GodotBin) {
    $pathFile = Join-Path $PSScriptRoot 'godot_path.txt'
    if (Test-Path $pathFile) {
        $GodotBin = (Get-Content $pathFile -Raw).Trim()
    }
}

if (-not $GodotBin -or -not (Test-Path $GodotBin)) {
    Write-Host "[check] Godot binary not found. Set GODOT_BIN or edit tools/godot_path.txt" -ForegroundColor Red
    exit 2
}

Write-Host "[check] godot: $GodotBin" -ForegroundColor DarkGray
Write-Host "[check] project: $repo" -ForegroundColor DarkGray

$raw = & $GodotBin --headless --path $repo --import 2>&1 | Out-String
$code = $LASTEXITCODE

$patterns = @(
    'Parse Error',
    'SCRIPT ERROR',
    'Failed to load',
    'Cannot open file',
    'Invalid call',
    'Attempt to call',
    'nonexistent function',
    'Identifier .* not declared'
)

$hits = @($raw -split "`r?`n" | Where-Object { $line = $_; $patterns | Where-Object { $line -match $_ } })

if ($VerboseLog) {
    Write-Host $raw
}

if ($code -ne 0 -and $hits.Count -eq 0) {
    Write-Host "[check] Godot exited with code $code" -ForegroundColor Red
    Write-Host ($raw -split "`r?`n" | Select-Object -Last 20) -ForegroundColor DarkGray
    exit 3
}

if ($hits.Count -gt 0) {
    Write-Host "[check] FAILED - $($hits.Count) error line(s):" -ForegroundColor Red
    $hits | Select-Object -First 40 | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    exit 1
}

Write-Host "[check] OK - project imports and all scripts parse" -ForegroundColor Green
exit 0
