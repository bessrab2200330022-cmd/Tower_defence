# Play a whole match headless through the real Level and Hud.
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\autoplay.ps1
. (Join-Path $PSScriptRoot "find_godot.ps1")

$root = Split-Path -Parent $PSScriptRoot
$godot = Find-Godot
if (-not $godot) { Show-GodotNotFound; exit 1 }

Write-Host "Using: $godot" -ForegroundColor DarkGray
Write-Host ""

& $godot --headless --path $root --script "res://tests/run_autoplay.gd"
$status = $LASTEXITCODE

Write-Host ""
if ($status -eq 0) {
    Write-Host "AUTOPLAY PASSED" -ForegroundColor Green
} else {
    Write-Host "AUTOPLAY FAILED (exit code $status)" -ForegroundColor Red
}
exit $status
