@echo off
REM Launch the game. Double-click me.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0play.ps1"
if not "%ERRORLEVEL%"=="0" pause
exit /b %ERRORLEVEL%
