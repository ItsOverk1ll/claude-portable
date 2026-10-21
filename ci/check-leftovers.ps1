# Fails if the profile, user PATH or uninstall registry differs from snapshot.ps1's record.

Get-ChildItem $env:USERPROFILE -Force -Recurse -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty FullName | Sort-Object | Set-Content $env:RUNNER_TEMP\after.txt
# The runner's own background activity (Firefox, Windows caches) also writes to the profile,
# so only fail on paths that are Claude's or new top-level profile entries (e.g. empty .local).
$diff = @(Compare-Object (Get-Content $env:RUNNER_TEMP\before.txt) (Get-Content $env:RUNNER_TEMP\after.txt) |
    Where-Object { $_.InputObject -notmatch '\\AppData\\Local\\Temp(\\|$)' })
$top = '^' + [regex]::Escape($env:USERPROFILE) + '\\[^\\]+$'
$noise, $diff = $diff.Where({ $_.InputObject -notmatch 'claude|anthropic' -and $_.InputObject -notmatch $top }, 'Split')
if ($noise) { Write-Host "Ignored $($noise.Count) unrelated profile changes, e.g. $($noise[0].InputObject)" }
if ($diff) { $diff | Format-Table -AutoSize | Out-String | Write-Host }

$k = Get-Item HKCU:\Environment
$pathAfter = "$($k.GetValueKind('Path'))|$($k.GetValue('Path', '', 'DoNotExpandEnvironmentNames'))"
$pathBefore = Get-Content $env:RUNNER_TEMP\path_before.txt -Raw
Write-Host "PATH before: $pathBefore"
Write-Host "PATH after:  $pathAfter"

$uninstKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\ClaudePortable'

if ($diff) { throw "Leftover files after uninstall (listed above)" }
# Compare type plus entries; an empty trailing ';' is not a meaningful difference.
$norm = { param($s) $t, $p = $s -split '\|', 2; "$t|" + (($p -split ';' | Where-Object { $_ }) -join ';') }
if ((& $norm $pathAfter) -ne (& $norm $pathBefore)) { throw "User PATH not restored (see above)" }
if (Test-Path $uninstKey) { throw "Uninstall registry key still present: $uninstKey" }
Write-Host "No leftovers."
