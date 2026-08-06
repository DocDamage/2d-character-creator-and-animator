# Manual Verification

1. Create a `WeaponDefinition`, give it an asset ID, and add one primary and one secondary `GripDefinition`.
2. Create a `WeaponPoseProfile`; use `WeaponPosingEditor.bind_hand_to_grip` for each arm chain.
3. Set the editor preview context and weapon transform; `get_preview` returns world-space grip targets and compatibility status.
4. Call `align_hands` with a rig and optional `HandPoseLibrary`; each valid binding sets shoulder, elbow, and wrist rotation toward its grip and reports reachability/gap diagnostics.
5. Add action-point, collision, event, audio-cue, viseme, and script-parameter tracks to a timeline registry; serialize and restore them through `TrackRegistry`.

Expected and actual: both hands bind to their assigned grips, primary hand target is reached in the automated fixture, and specialized metadata tracks retain their behavior after reload.
