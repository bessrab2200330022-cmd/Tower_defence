# Locates the Blender executable on Windows. Same approach as find_godot.ps1:
# explicit override, then cache, then PATH, then a search of likely roots.

$script:BlenderCache = Join-Path $PSScriptRoot "blender_path.txt"

function Save-BlenderPath([string]$Path) {
    try { Set-Content -Path $script:BlenderCache -Value $Path -NoNewline -Encoding UTF8 } catch { }
}

function Find-Blender {
    param([switch]$Rescan)

    if ($env:BLENDER -and (Test-Path -LiteralPath $env:BLENDER)) {
        return (Resolve-Path -LiteralPath $env:BLENDER).Path
    }

    if (-not $Rescan -and (Test-Path -LiteralPath $script:BlenderCache)) {
        $cached = (Get-Content -LiteralPath $script:BlenderCache -Raw).Trim()
        if ($cached -and (Test-Path -LiteralPath $cached)) { return $cached }
    }

    $cmd = Get-Command "blender.exe" -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) { Save-BlenderPath $cmd.Source; return $cmd.Source }

    $roots = @(
        "${env:ProgramFiles(x86)}\Steam\steamapps\common\Blender",
        "$env:ProgramFiles\Steam\steamapps\common\Blender",
        "$env:ProgramFiles\Blender Foundation",
        "${env:ProgramFiles(x86)}\Blender Foundation",
        "$env:LOCALAPPDATA\Programs",
        "$env:USERPROFILE\scoop\apps"
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique

    foreach ($root in $roots) {
        $hit = Get-ChildItem -LiteralPath $root -Filter "blender.exe" -Recurse -Depth 4 -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch "launcher" } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($hit) { Save-BlenderPath $hit.FullName; return $hit.FullName }
    }

    return $null
}

function Show-BlenderNotFound {
    Write-Host ""
    Write-Host "Could not find Blender." -ForegroundColor Red
    Write-Host 'Set it for this terminal:  $env:BLENDER = "C:\path\to\blender.exe"'
    Write-Host "Or write the path into:    $script:BlenderCache"
    Write-Host ""
}
