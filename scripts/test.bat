@echo off
REM Run the headless test suite. Double-click me.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0test.ps1"
REM Capture before echo/pause - both reset ERRORLEVEL.
set "STATUS=%ERRORLEVEL%"
echo.
pause
exit /b %STATUS%
