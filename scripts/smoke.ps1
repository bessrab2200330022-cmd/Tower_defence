# Boot the real game headless and fail on any engine error.
# Catches the class of bug unit tests miss: bad scene wiring, null nodes,
# resources that load in isolation but not together.
#
# --quit-after counts FRAMES, not simulation ticks, and nothing starts a
# wave here. See autoplay.ps1 for a run that actually plays the game.
. (Join-Path $PSScriptRoot "find_godot.ps1")

$root = Split-Path -Parent $PSScriptRoot
$godot = Find-Godot
if (-not $godot) { Show-GodotNotFound; exit 1 }

$frames = if ($env:FRAMES) { $env:FRAMES } elseif ($env:TICKS) { $env:TICKS } else { "600" }

Write-Host "Using: $godot" -ForegroundColor DarkGray
Write-Host ""

$output = & $godot --headless --path $root --quit-after $frames 2>&1
$output | ForEach-Object { Write-Host $_ }

Write-Host ""
if ($output -match "SCRIPT ERROR|ERROR:|Parse Error") {
    Write-Host "FAIL: the headless run reported engine errors." -ForegroundColor Red
    exit 1
}

Write-Host "PASS: clean headless run over $frames frames." -ForegroundColor Green
exit 0
