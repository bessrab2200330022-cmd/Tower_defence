# Locates the Godot executable on Windows.
#
# Order of preference:
#   1. $env:GODOT           - explicit override, always wins
#   2. scripts/godot_path.txt - cached from a previous successful search
#   3. godot / godot.exe on PATH
#   4. A recursive search of the places Godot actually ends up
#
# Dot-source this file and call Find-Godot. On a successful search the result is
# cached, so the slow path runs at most once.

$script:CacheFile = Join-Path $PSScriptRoot "godot_path.txt"

function Save-GodotPath([string]$Path) {
    try { Set-Content -Path $script:CacheFile -Value $Path -NoNewline -Encoding UTF8 } catch { }
}

function Find-Godot {
    param([switch]$Rescan)

    if ($env:GODOT -and (Test-Path -LiteralPath $env:GODOT)) {
        return (Resolve-Path -LiteralPath $env:GODOT).Path
    }

    if (-not $Rescan -and (Test-Path -LiteralPath $script:CacheFile)) {
        $cached = (Get-Content -LiteralPath $script:CacheFile -Raw).Trim()
        if ($cached -and (Test-Path -LiteralPath $cached)) { return $cached }
    }

    foreach ($name in @("godot", "godot.exe", "Godot.exe", "godot4", "godot4.exe")) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($cmd -and $cmd.Source) {
            Save-GodotPath $cmd.Source
            return $cmd.Source
        }
    }

    Write-Host "Searching for Godot..." -ForegroundColor DarkGray

    # Ordered by how likely a hit is, so the common cases return fast.
    $roots = @(
        "$env:USERPROFILE\Downloads",
        "$env:USERPROFILE\Desktop",
        "$env:LOCALAPPDATA\Programs",
        "$env:LOCALAPPDATA\Microsoft\WinGet\Packages",
        "$env:USERPROFILE\scoop\apps",
        "$env:ProgramData\chocolatey\lib",
        "$env:ProgramFiles",
        "${env:ProgramFiles(x86)}",
        "$env:USERPROFILE\Documents",
        "$env:USERPROFILE\OneDrive\Desktop",
        "$env:USERPROFILE\OneDrive\Documents",
        "$env:USERPROFILE\AppData\Roaming\Godot",
        "C:\Godot",
        "D:\Godot",
        "$env:ProgramFiles\Steam\steamapps\common",
        "${env:ProgramFiles(x86)}\Steam\steamapps\common"
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique

    foreach ($root in $roots) {
        $hit = Get-ChildItem -LiteralPath $root -Filter "*odot*.exe" -Recurse -Depth 4 -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch "console" -and $_.Name -notmatch "uninst" } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($hit) {
            Save-GodotPath $hit.FullName
            return $hit.FullName
        }
    }

    # Last resort: sweep the whole user profile. Slow, but it runs once.
    $hit = Get-ChildItem -LiteralPath $env:USERPROFILE -Filter "*odot*.exe" -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch "console" -and $_.Name -notmatch "uninst" } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($hit) {
        Save-GodotPath $hit.FullName
        return $hit.FullName
    }

    return $null
}

function Show-GodotNotFound {
    Write-Host ""
    Write-Host "Could not find Godot on this machine." -ForegroundColor Red
    Write-Host ""
    Write-Host "Find the exe: open Task Manager while Godot is running, right-click the"
    Write-Host "Godot process, choose 'Open file location'. Then either:"
    Write-Host ""
    Write-Host "  A) Set it for this terminal only:" -ForegroundColor Yellow
    Write-Host '     $env:GODOT = "C:\full\path\to\Godot_v4.7-stable_win64.exe"'
    Write-Host ""
    Write-Host "  B) Set it permanently:" -ForegroundColor Yellow
    Write-Host '     [Environment]::SetEnvironmentVariable("GODOT", "C:\full\path\to\Godot.exe", "User")'
    Write-Host "     (then open a new terminal)"
    Write-Host ""
    Write-Host "  C) Write the path straight into the cache file:" -ForegroundColor Yellow
    Write-Host "     $script:CacheFile"
    Write-Host ""
}
