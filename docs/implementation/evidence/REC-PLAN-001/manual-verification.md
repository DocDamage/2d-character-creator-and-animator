# Manual Verification

1. The integration test creates a new consumer project in `user://`.
2. It copies only `addons/modular_character_runtime/`, the clean fixture, and
   newly generated native artifacts.
3. A separate `godot --headless --path <consumer>` process loads the resource
   and scene, changes facing, and equips an item.
4. The consumer prints `CLEAN_CONSUMER_PASS` and exits successfully.

Expected and actual result: the generated package runs without a dependency on
the authoring project's `runtime_plugin/`, `facing/`, or `animation/` paths.
