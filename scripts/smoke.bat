@echo off
REM Boot the real game headless and fail on any engine error. Double-click me.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0smoke.ps1"
REM Capture before echo/pause - both reset ERRORLEVEL.
set "STATUS=%ERRORLEVEL%"
echo.
pause
exit /b %STATUS%
