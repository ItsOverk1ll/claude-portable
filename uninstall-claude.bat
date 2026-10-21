@echo off
set PSModulePath=
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall-claude.ps1"
pause
