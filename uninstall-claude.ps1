# Removes Claude Code CLI and its per-user data (login tokens, settings, history, cache).

$ErrorActionPreference = 'Continue'
$home_ = $env:USERPROFILE

Get-Process claude -ErrorAction SilentlyContinue | Stop-Process -Force

$targets = @(
    "$home_\.local\bin\claude.exe",
    "$home_\.local\share\claude",
    "$home_\.local\state\claude",
    "$home_\.cache\claude",
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
    # Edit the raw registry value so other entries keep their %VARS% and the value keeps its type.
    $key = Get-Item HKCU:\Environment
    $raw = $key.GetValue('Path', $null, 'DoNotExpandEnvironmentNames')
    if ($null -ne $raw) {
        $kind = $key.GetValueKind('Path')
        $kept = $raw -split ';' | Where-Object { [Environment]::ExpandEnvironmentVariables($_).TrimEnd('\') -ne $bin }
        Set-ItemProperty HKCU:\Environment -Name Path -Value ($kept -join ';') -Type $kind
        # Set and clear a dummy variable so Windows broadcasts the environment change to new terminals.
        [Environment]::SetEnvironmentVariable('ClaudePortableRefresh', '1', 'User')
        [Environment]::SetEnvironmentVariable('ClaudePortableRefresh', $null, 'User')
        Write-Host "Removed $bin from user PATH"
    }
}
# Remove parent folders the installer created, but only if they are now empty.
foreach ($d in "$home_\.local\share", "$home_\.local\state", "$home_\.local", "$home_\.cache") {
    if ((Test-Path $d) -and -not (Get-ChildItem $d -Force)) { Remove-Item $d -Force }
}

Write-Host "`nDone. Leftover check:"
Get-ChildItem $home_ -Force -Filter '.claude*' -ErrorAction SilentlyContinue
if (Get-Command claude -ErrorAction SilentlyContinue) { Write-Warning "'claude' is still on PATH (open a new terminal to confirm)." }
