# Records the user profile file list and raw user PATH before a test install.

Get-ChildItem $env:USERPROFILE -Force -Recurse -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty FullName | Sort-Object | Set-Content $env:RUNNER_TEMP\before.txt
# Raw registry value (unexpanded) and its type, so the check catches %VAR% flattening too.
$k = Get-Item HKCU:\Environment
"$($k.GetValueKind('Path'))|$($k.GetValue('Path', '', 'DoNotExpandEnvironmentNames'))" |
    Set-Content $env:RUNNER_TEMP\path_before.txt -NoNewline
