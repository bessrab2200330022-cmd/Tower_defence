@echo off
REM Play a whole match headless through the real view layer. Double-click me.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0autoplay.ps1"
REM Capture before echo/pause - both reset ERRORLEVEL.
set "STATUS=%ERRORLEVEL%"
echo.
pause
exit /b %STATUS%
