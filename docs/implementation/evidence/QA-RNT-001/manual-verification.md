# Verification Scenario

`tests/integration/test_clean_consumer_export.gd` performs the acceptance
scenario without relying on the authoring project at runtime. It copies the
fixture and distributable addon into a new temporary Godot project, exports
native data and a scene into that project, starts its editor to import the
fixture `.chrproj`, and starts a second runtime process to load and exercise
both imported and generated resources.

The scenario asserts automatic player initialization, data reload, north-facing
resolution, two-bone IK, state transition, rule and timeline event delivery,
`Polygon2D` construction, and main-hand equipment storage. It fails on any
editor plugin load failure, script error, or runtime assertion failure.

No interactive visual step is needed for this data/runtime acceptance; visual
authoring and broader consumer examples are tracked by the remaining `GDT-*`
master-plan tasks.
