# Launch the game.
. (Join-Path $PSScriptRoot "find_godot.ps1")

$root = Split-Path -Parent $PSScriptRoot
$godot = Find-Godot
if (-not $godot) { Show-GodotNotFound; exit 1 }

Write-Host "Using: $godot" -ForegroundColor DarkGray
& $godot --path $root
exit $LASTEXITCODE
