# Rebuild every .glb from the scripts in art/. No Blender window needed.
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build_art.ps1
. (Join-Path $PSScriptRoot "find_blender.ps1")

$root = Split-Path -Parent $PSScriptRoot
$blender = Find-Blender
if (-not $blender) { Show-BlenderNotFound; exit 1 }

Write-Host "Using: $blender" -ForegroundColor DarkGray
Write-Host ""

$output = & $blender -b --python (Join-Path $root "art\build_all.py") 2>&1
$output | ForEach-Object { Write-Host $_ }

if ($output -match "\[FAIL\]") {
    Write-Host ""
    Write-Host "Art build failed." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Art build complete. Reopen the Godot editor to reimport." -ForegroundColor Green
exit 0
