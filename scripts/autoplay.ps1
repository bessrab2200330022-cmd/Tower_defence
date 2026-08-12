# Play a whole match headless through the real Level and Hud.
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\autoplay.ps1
. (Join-Path $PSScriptRoot "find_godot.ps1")

$root = Split-Path -Parent $PSScriptRoot
$godot = Find-Godot
if (-not $godot) { Show-GodotNotFound; exit 1 }

Write-Host "Using: $godot" -ForegroundColor DarkGray
Write-Host ""

# Same two-part gate as autoplay.sh: exit code AND no engine errors. Godot
# prints those to stderr rather than raising them, so a run can report PASS and
# exit 0 while emitting dozens. Redirecting to files rather than using 2>&1
# because Windows PowerShell wraps native stderr in ErrorRecords and corrupts
# $LASTEXITCODE in the process.
$outFile = [IO.Path]::GetTempFileName()
$errFile = [IO.Path]::GetTempFileName()
$proc = Start-Process -FilePath $godot `
    -ArgumentList "--headless", "--path", $root, "--script", "res://tests/run_autoplay.gd" `
    -NoNewWindow -Wait -PassThru -RedirectStandardOutput $outFile -RedirectStandardError $errFile
$status = $proc.ExitCode

Get-Content $outFile
$engineErrors = @(Get-Content $errFile | Select-String -Pattern "(SCRIPT ERROR|ERROR:|Parse Error)")
Remove-Item $outFile, $errFile -Force -ErrorAction SilentlyContinue

Write-Host ""
if ($engineErrors.Count -gt 0) {
    Write-Host "AUTOPLAY FAILED - $($engineErrors.Count) engine error line(s):" -ForegroundColor Red
    $engineErrors | Select-Object -First 10 | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkRed }
    exit 1
}
if ($status -eq 0) {
    Write-Host "AUTOPLAY PASSED - no engine errors" -ForegroundColor Green
} else {
    Write-Host "AUTOPLAY FAILED (exit code $status)" -ForegroundColor Red
}
exit $status
