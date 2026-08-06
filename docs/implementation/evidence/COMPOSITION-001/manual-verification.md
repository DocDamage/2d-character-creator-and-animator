# Manual Verification

1. Bind an `AnimationBlendStack`, `StateMachineAuthoringModel`, and
   `RuleGraphAuthoringModel` through `MainWindow.bind_animation_composition_context`.
2. Open Animation Composition, inspect the populated graph nodes, enter a time,
   and press Preview; confirm the state, fired rules, and diagnostics update.
3. Put an event-producing rule inside a time window and confirm the cascade
   applies its downstream action once while reporting the repeated action safely.
4. Link a source project through `LinkedProjectService`, set a local override,
   refresh a changed source, resolve its conflict, then inspect package and
   multi-character preview results.
