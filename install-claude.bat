@echo off
set PSModulePath=
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-claude.ps1"
pause
