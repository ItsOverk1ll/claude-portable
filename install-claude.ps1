# Installs Claude Code CLI for the current user only (no admin needed).
# Uses Anthropic's official installer; files land under the user's profile.

$ErrorActionPreference = 'Stop'
Start-Transcript -Path "$env:TEMP\claude-portable-install.log" -Force | Out-Null
trap { Write-Host "ERROR: $_"; Stop-Transcript | Out-Null; exit 1 }

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Warning "Git for Windows was not found. Claude Code on Windows needs it (Git Bash)."
    Write-Warning "Install it first, or Claude may not start. Continuing anyway."
}

Write-Host "64-bit PowerShell: $([Environment]::Is64BitProcess)"
Write-Host "Installing Claude Code to $env:USERPROFILE\.local\bin ..."
Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression

$exe = Join-Path $env:USERPROFILE '.local\bin\claude.exe'
if (Test-Path $exe) {
    Write-Host "Installed: $exe"
    Write-Host "Open a NEW terminal and run: claude"
    Write-Host "When finished, run /logout inside Claude, then uninstall: uninstall-claude.bat,"
    Write-Host "or 'Claude Code (portable)' in Apps & features if you used the .exe installer."
    Stop-Transcript | Out-Null
} else {
    throw "claude.exe not found at expected path. Check the installer output above."
}
