# Manual Verification

1. Open every project under `samples/` and walk its named scenario.
2. Follow the User, Asset Authoring, Weapon Authoring, Runtime Plugin API, and
   Release Build guides against the current application shell.
3. The configured Windows preset compiled on 2026-08-06; validate the recorded
   hashes before distributing that package.
4. On a clean Windows machine, run the smoke sequence in
   `docs/guides/RELEASE_BUILD_GUIDE.md` against the generated package.
5. Attach the Windows package and smoke log to `QA-REL-001`; do not promote this
   implementation evidence to final acceptance before that run.
