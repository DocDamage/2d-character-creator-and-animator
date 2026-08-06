# Remaining Release Acceptance Procedure

1. Transfer the generated executable and `.pck` to a clean Windows machine.
2. Launch the application interactively, then open every project under
   `samples/` and perform its named workflow.
3. Export a package from the application and load its generated runtime scene
   in a clean Godot consumer project with only the distributable addon.
4. Follow `docs/guides/RELEASE_BUILD_GUIDE.md`, record the commands and results
   in this bundle, and update `QA-REL-001` to COMPLETED only if every step passes.
