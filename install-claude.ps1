# Installs Claude Code CLI for the current user only (no admin needed).
# Uses Anthropic's official installer; files land under the user's profile.
# Installs Git for Windows through winget first if it's missing (Claude Code needs Git Bash),
# and records it in installed.txt so uninstall-claude.ps1 removes only what this installed.
# winget handling follows BetterHotkeys' install.ps1.

$ErrorActionPreference = 'Stop'
Start-Transcript -Path "$env:TEMP\claude-portable-install.log" -Force | Out-Null
trap { Write-Host "ERROR: $_"; Stop-Transcript | Out-Null; exit 1 }

$appDir = Join-Path $env:LOCALAPPDATA 'ClaudePortable'
$manifest = Join-Path $appDir 'installed.txt'
$installedNow = @()

# Runs a program and returns its output (including error output) as text. Windows PowerShell 5.1
# turns any error output from a program into a script-stopping error while $ErrorActionPreference
# is 'Stop', even when it's redirected, so this relaxes it for the call.
function Invoke-Program([scriptblock]$programCall) {
    $ErrorActionPreference = 'Continue'
    & $programCall 2>&1 | ForEach-Object { "$_" }
}

# ---------------------------------------------------------------- winget

# Path to a working winget, or $null
function Find-Winget {
    $candidates = @((Get-Command winget -ErrorAction SilentlyContinue).Source, "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe")
    foreach ($path in $candidates) {
        if ($path -and (Test-Path $path)) {
            try { if ((Invoke-Program { & $path --version }) -match '^v\d') { return $path } } catch {}
        }
    }
    $null
}

# "v1.29.380" -> [version] 1.29.380, or $null
function Get-WingetVersion($path) {
    $text = (Invoke-Program { & $path --version }) | Select-Object -First 1
    if ($text -match '^v(\d+\.\d+(\.\d+)?)') { [version]$Matches[1] }
}

# Installs (or updates) App Installer, which contains winget, and its dependencies from winget's
# GitHub releases
function Install-WingetFromGitHub {
    $tmp = Join-Path $env:TEMP 'claude-portable-winget'
    try {
        New-Item -ItemType Directory -Force $tmp | Out-Null
        $base = 'https://github.com/microsoft/winget-cli/releases/latest/download'
        $ProgressPreference = 'SilentlyContinue'
        Write-Host 'Downloading winget dependencies...'
        Invoke-WebRequest "$base/DesktopAppInstaller_Dependencies.zip" -OutFile "$tmp\deps.zip" -UseBasicParsing
        Write-Host 'Downloading winget...'
        Invoke-WebRequest "$base/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" -OutFile "$tmp\winget.msixbundle" -UseBasicParsing
        Write-Host 'Installing winget (this can take a minute)...'
        Expand-Archive "$tmp\deps.zip" "$tmp\deps" -Force
        # The zip has a folder per architecture (x64, arm64, ...)
        $arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'x64' }
        $deps = @(Get-ChildItem "$tmp\deps" -Recurse -Include *.appx, *.msix |
            Where-Object { $_.FullName -match "\\$arch\\" } | Select-Object -ExpandProperty FullName)
        if ($deps) { Add-AppxPackage -Path "$tmp\winget.msixbundle" -DependencyPath $deps -ForceApplicationShutdown }
        else { Add-AppxPackage -Path "$tmp\winget.msixbundle" -ForceApplicationShutdown }
    } catch { Write-Host "  that didn't work: $($_.Exception.Message)" }
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

# winget comes with "App Installer". If it's missing or broken, first try registering the copy
# Windows already has, then install it from GitHub. An old winget (older Windows 10 images)
# doesn't know options used here, so it's updated the same way.
function Get-Winget {
    $winget = Find-Winget
    if (-not $winget) {
        Write-Host 'Registering App Installer...'
        try { Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe } catch {}
        $winget = Find-Winget
    }
    if (-not $winget) {
        Write-Host 'Downloading winget from GitHub (about 300 MB)...'
        Install-WingetFromGitHub
        $winget = Find-Winget
    } else {
        $version = Get-WingetVersion $winget
        if ($version -and $version -lt [version]'1.6.0') {
            Write-Host "winget $version is too old, updating it from GitHub (about 300 MB)..."
            Install-WingetFromGitHub
            # If the update didn't work, carry on with the old one
            $winget = Find-Winget
        }
    }
    $winget
}

# Runs winget install; returns its exit code. winget gets 10 minutes before it's stopped.
function Invoke-WingetInstall($winget, $id, [string[]]$extra) {
    $log = Join-Path $env:TEMP "claude-portable-winget-$id.log"
    $wingetArgs = @('install', '--id', $id, '-e', '--source', 'winget', '--silent', '--accept-source-agreements',
        '--accept-package-agreements', '--disable-interactivity') + $extra
    $proc = Start-Process $winget -ArgumentList $wingetArgs -NoNewWindow -PassThru -RedirectStandardOutput $log
    $handle = $proc.Handle  # needed for ExitCode to be readable later
    if (-not $proc.WaitForExit(600000)) { $proc.Kill(); return 'timeout' }
    Get-Content $log -ErrorAction SilentlyContinue | Where-Object { $_ -match '^\s*(Found|Successfully|Starting|The installer|No applicable)' } |
        ForEach-Object { Write-Host "  $($_.Trim())" }
    $proc.ExitCode
}

# ---------------------------------------------------------------- Git

function Test-Git {
    if (Get-Command git -ErrorAction SilentlyContinue) { return $true }
    foreach ($p in "$env:ProgramFiles\Git\cmd\git.exe", "${env:ProgramFiles(x86)}\Git\cmd\git.exe", "$env:LOCALAPPDATA\Programs\Git\cmd\git.exe") {
        if (Test-Path $p) { return $true }
    }
    $false
}

# Windows PowerShell 5.1 may not use TLS 1.2 by default, which GitHub requires
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

Write-Host "64-bit PowerShell: $([Environment]::Is64BitProcess)"
Write-Host 'Checking Git for Windows...'
if (Test-Git) {
    Write-Host '  already installed, skipping'
} else {
    $winget = Get-Winget
    if (-not $winget) {
        Write-Warning 'Could not get winget, so Git was not installed. Claude may not start without it.'
        Write-Warning 'Install Git from https://git-scm.com/download/win, or "App Installer" from the Microsoft Store.'
    } else {
        Write-Host "  installing Git with winget $(Invoke-Program { & $winget --version })"
        # Per-user first (no admin prompt); fall back to the default installer if there's no user-scope one.
        $code = Invoke-WingetInstall $winget 'Git.Git' @('--scope', 'user')
        if ($code -notin 0, -1978334967) {
            Write-Host "  per-user install not available (exit $code), trying the default installer (may ask for admin)"
            $code = Invoke-WingetInstall $winget 'Git.Git' @()
        }
        # 0x8A150109 (-1978334967): installed, finishes after a restart
        if ($code -in 0, -1978334967) {
            $installedNow += 'Git.Git'
            # Make git visible to the Claude install below without opening a new window
            $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
        } else {
            Write-Warning "winget failed to install Git (exit $code), see $env:TEMP\claude-portable-winget-Git.Git.log"
        }
    }
}

# Add to the record kept for uninstall-claude.ps1 (re-runs keep what earlier runs installed)
if ($installedNow) {
    New-Item -ItemType Directory -Force $appDir | Out-Null
    $record = @(Get-Content $manifest -ErrorAction SilentlyContinue) + $installedNow | Where-Object { $_ } | Sort-Object -Unique
    Set-Content $manifest $record
}

# ---------------------------------------------------------------- Claude Code

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
