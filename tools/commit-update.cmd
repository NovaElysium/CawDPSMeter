@echo off
REM ===================================================================
REM  Double-click this AFTER extracting a colleague ZIP over the addon
REM  folder. It restores the .toc metadata, shows the diff, then commits
REM  and pushes (asks you first). Type a short message when prompted.
REM ===================================================================
cd /d "%~dp0.."
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0commit-update.ps1"
echo.
pause
