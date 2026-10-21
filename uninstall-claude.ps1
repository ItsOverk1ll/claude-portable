# Removes Claude Code CLI and its per-user data (login tokens, settings, history, cache).

$ErrorActionPreference = 'Continue'
$home_ = $env:USERPROFILE

Get-Process claude -ErrorAction SilentlyContinue | Stop-Process -Force

$targets = @(
    "$home_\.local\bin\claude.exe",
    "$home_\.local\share\claude",
    "$home_\.claude",
    "$home_\.claude.json",
    "$home_\.claude.json.backup",
    "$env:LOCALAPPDATA\claude-cli-nodejs",
    "$env:LOCALAPPDATA\claude"
)

foreach ($t in $targets) {
    if (Test-Path $t) {
        Remove-Item $t -Recurse -Force -ErrorAction SilentlyContinue
        if (Test-Path $t) { Write-Warning "Could not remove $t" } else { Write-Host "Removed $t" }
    }
}

# Drop ~\.local\bin from the user PATH only if it is now empty (installer added it).
$bin = "$home_\.local\bin"
if ((Test-Path $bin) -and -not (Get-ChildItem $bin -Force)) {
    Remove-Item $bin -Force
    $path = [Environment]::GetEnvironmentVariable('Path', 'User')
    $clean = ($path -split ';' | Where-Object { $_ -and $_.TrimEnd('\') -ne $bin }) -join ';'
    [Environment]::SetEnvironmentVariable('Path', $clean, 'User')
    Write-Host "Removed $bin from user PATH"
}
$share = "$home_\.local\share"
if ((Test-Path $share) -and -not (Get-ChildItem $share -Force)) { Remove-Item $share -Force }
$local = "$home_\.local"
if ((Test-Path $local) -and -not (Get-ChildItem $local -Force)) { Remove-Item $local -Force }

Write-Host "`nDone. Leftover check:"
Get-ChildItem $home_ -Force -Filter '.claude*' -ErrorAction SilentlyContinue
if (Get-Command claude -ErrorAction SilentlyContinue) { Write-Warning "'claude' is still on PATH (open a new terminal to confirm)." }
