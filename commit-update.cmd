@echo off
REM ===================================================================
REM  Double-click this AFTER extracting a colleague ZIP over this folder.
REM  It restores the .toc metadata, shows the diff, then commits and
REM  pushes (asks you first). You type a short message when prompted.
REM ===================================================================
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\commit-update.ps1"
echo.
pause
