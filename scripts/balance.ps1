# Balance harness (ROADMAP 0.1). Measures the shipped game over a few hundred
# headless matches; it is not a gate.
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\balance.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\balance.ps1 --credits=320,640
param([Parameter(ValueFromRemainingArguments = $true)] $HarnessArgs)

. (Join-Path $PSScriptRoot "find_godot.ps1")

$root = Split-Path -Parent $PSScriptRoot
$godot = Find-Godot
if (-not $godot) { Show-GodotNotFound; exit 1 }

Write-Host "Using: $godot" -ForegroundColor DarkGray
Write-Host ""

if ($HarnessArgs) {
    & $godot --headless --path $root --script "res://tests/run_balance.gd" -- @HarnessArgs
} else {
    & $godot --headless --path $root --script "res://tests/run_balance.gd"
}
$status = $LASTEXITCODE

Write-Host ""
if ($status -eq 0) {
    Write-Host "HARNESS RAN CLEAN - read the numbers above" -ForegroundColor Green
} else {
    Write-Host "HARNESS FAILED (exit code $status) - the numbers are not trustworthy" -ForegroundColor Red
}
exit $status
