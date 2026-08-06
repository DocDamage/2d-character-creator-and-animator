# Verification Method

1. Run `tests/completion_qa_runner.tscn` with Godot headless. It starts the
   normal project application environment, including autoloads, then invokes the
   scoped test modules directly and checks their expected result counts.
2. Confirm the clean-consumer check starts a separate Godot project copied into
   `user://`, containing only the runtime addon and generated `.tres`/`.tscn`
   artifacts. It must report `CLEAN_CONSUMER_PASS` with no loader or script
   error.
3. Run the complete suite and static gates listed in `commands.log`.
4. Package-level Windows installation and interactive smoke acceptance are not
   part of this bundle; execute the release guide and record those results under
   `QA-REL-001`.
