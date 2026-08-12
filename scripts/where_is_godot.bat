@echo off
REM Diagnostic: search for Godot and report what was found, without running anything.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  ". '%~dp0find_godot.ps1'; $p = Find-Godot -Rescan; if ($p) { Write-Host ''; Write-Host 'Found Godot at:' -ForegroundColor Green; Write-Host \"  $p\"; Write-Host ''; Write-Host 'Cached to scripts\godot_path.txt - test.bat and play.bat will use it now.' } else { Show-GodotNotFound }"
echo.
pause
