# Manual Verification

1. Open Quality & Recovery, provide a project path with a backup/autosave, run
   Scan Recovery, review the candidate count, and select Recover Latest only
   after confirming the source.
2. Run Quality Audit and review the 100-character stress count and release
   safety result.
3. Toggle Reduced motion and High contrast, then confirm the selected values
   persist through ThemeService export/import settings and keyboard focus remains
   visible.
4. Attempt a path containing `..` through the security model and confirm it is
   rejected; verify license manifests and `ffmpeg -version` are reported.
