@echo off
REM Balance harness (ROADMAP 0.1). Double-click me. Takes about 15 seconds.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0balance.ps1" %*
REM Capture before echo/pause - both reset ERRORLEVEL.
set "STATUS=%ERRORLEVEL%"
echo.
pause
exit /b %STATUS%
