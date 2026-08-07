; Paper Quest Character Studio -- NSIS installer template.
; Build through ReleaseBuilder.build_windows_installer after exporting the
; portable Windows EXE + PCK.  The installer itself contains no project art
; beyond the application resources exported by Godot.

!ifndef APP_VERSION
  !define APP_VERSION "0.1.0-dev"
!endif
!ifndef APP_EXE
  !define APP_EXE "PaperQuestCharacterStudio.exe"
!endif
!ifndef APP_PCK
  !define APP_PCK "PaperQuestCharacterStudio.pck"
!endif
!ifndef OUTPUT_EXE
  !define OUTPUT_EXE "PaperQuestCharacterStudio-setup.exe"
!endif

Unicode true
Name "Paper Quest Character Studio ${APP_VERSION}"
OutFile "${OUTPUT_EXE}"
InstallDir "$LOCALAPPDATA\Paper Quest Character Studio"
InstallDirRegKey HKCU "Software\Paper Quest Studio\Character Studio" "InstallDir"
RequestExecutionLevel user
ShowInstDetails show
ShowUninstDetails show

Page directory
Page instfiles
UninstPage uninstConfirm
UninstPage instfiles

Section "Paper Quest Character Studio" SecMain
  SetOutPath "$INSTDIR"
  File "${APP_EXE}"
  File "${APP_PCK}"
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  CreateDirectory "$SMPROGRAMS\Paper Quest Studio"
  CreateShortCut "$SMPROGRAMS\Paper Quest Studio\Paper Quest Character Studio.lnk" "$INSTDIR\${APP_EXE}"
  CreateShortCut "$DESKTOP\Paper Quest Character Studio.lnk" "$INSTDIR\${APP_EXE}"
  WriteRegStr HKCU "Software\Paper Quest Studio\Character Studio" "InstallDir" "$INSTDIR"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Paper Quest Character Studio" "DisplayName" "Paper Quest Character Studio"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Paper Quest Character Studio" "DisplayVersion" "${APP_VERSION}"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Paper Quest Character Studio" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Paper Quest Character Studio" "NoModify" 1
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Paper Quest Character Studio" "NoRepair" 1
SectionEnd

Section "Uninstall"
  Delete "$INSTDIR\${APP_EXE}"
  Delete "$INSTDIR\${APP_PCK}"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"
  Delete "$SMPROGRAMS\Paper Quest Studio\Paper Quest Character Studio.lnk"
  RMDir "$SMPROGRAMS\Paper Quest Studio"
  Delete "$DESKTOP\Paper Quest Character Studio.lnk"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Paper Quest Character Studio"
  DeleteRegKey HKCU "Software\Paper Quest Studio\Character Studio"
SectionEnd
