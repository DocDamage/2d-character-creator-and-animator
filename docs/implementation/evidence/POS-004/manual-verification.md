# Manual Verification Scenario

1. Save two compatible absolute poses for the same rig with visibly different
   local position, rotation, and scale values.
2. Select one source and one target under **Blend Saved Poses** and change the
   weight slider to 25%, 50%, and 100%.
3. Choose **Preview Blend on Rig** and confirm the bound rig receives the
   weighted local transforms.
4. Enter a new ID/name and choose **Save Blended Pose**; select and apply the
   stored result to verify it matches the preview.
5. Try poses with incompatible bones, different rig IDs, additive modes, or
   an out-of-range API weight; confirm no pose or rig data is silently changed.
