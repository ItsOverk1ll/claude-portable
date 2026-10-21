; Per-user installer for Claude Code. Runs install-claude.ps1, then registers
; an uninstaller (Apps & features) that runs uninstall-claude.ps1 and removes itself.
; Build: makensis /DVERSION=1.0.0 installer.nsi

!include LogicLib.nsh
!include x64.nsh

!ifndef VERSION
  !define VERSION "0.0.0"
!endif
!define UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\ClaudePortable"

Unicode true
Name "Claude Code (portable)"
OutFile "ClaudePortableSetup.exe"
RequestExecutionLevel user
InstallDir "$LOCALAPPDATA\ClaudePortable"
ShowInstDetails show
ShowUninstDetails show

Page instfiles
UninstPage uninstConfirm
UninstPage instfiles

Var PS

; NSIS is 32-bit; Sysnative reaches the 64-bit PowerShell on 64-bit Windows.
!macro FindPowerShell
  ${If} ${RunningX64}
    StrCpy $PS "$WINDIR\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
  ${Else}
    StrCpy $PS "$WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
  ${EndIf}
!macroend

Section "Install"
  !insertmacro FindPowerShell
  SetOutPath "$INSTDIR"
  File "install-claude.ps1"
  File "uninstall-claude.ps1"

  ; Register the uninstaller first so a failed install can still be cleaned up.
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  WriteRegStr HKCU "${UNINST_KEY}" "DisplayName" "Claude Code (portable)"
  WriteRegStr HKCU "${UNINST_KEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKCU "${UNINST_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${UNINST_KEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegStr HKCU "${UNINST_KEY}" "QuietUninstallString" '"$INSTDIR\Uninstall.exe" /S'
  WriteRegDWORD HKCU "${UNINST_KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNINST_KEY}" "NoRepair" 1

  nsExec::ExecToLog '"$PS" -NoProfile -ExecutionPolicy Bypass -File "$INSTDIR\install-claude.ps1"'
  Pop $0
  ${If} $0 != 0
    DetailPrint "Install script failed (exit code $0)."
    MessageBox MB_ICONSTOP "Claude Code install failed. Log: $TEMP\claude-portable-install.log$\nUse 'Claude Code (portable)' in Apps & features to clean up." /SD IDOK
    SetErrorLevel 1
    Abort
  ${EndIf}
SectionEnd

Section "Uninstall"
  !insertmacro FindPowerShell
  nsExec::ExecToLog '"$PS" -NoProfile -ExecutionPolicy Bypass -File "$INSTDIR\uninstall-claude.ps1"'
  Pop $0
  ${If} $0 != 0
    DetailPrint "Uninstall script reported exit code $0."
  ${EndIf}

  Delete "$INSTDIR\install-claude.ps1"
  Delete "$INSTDIR\uninstall-claude.ps1"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"
  DeleteRegKey HKCU "${UNINST_KEY}"
SectionEnd
