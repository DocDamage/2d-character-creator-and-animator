# Manual Verification Scenario

1. Bind a rig, capture an asymmetric source pose, and select it in **Saved
   Poses**.
2. Enter a new pose ID and name plus pairs such as
   `hand_left:hand_right; foot_left:foot_right`.
3. Choose **Mirror Selected to Named Pose**; confirm the original remains in
   the list and the newly named pose is selected.
4. Inspect paired transforms: target X position and rotation must be negated,
   while Y position and scale are retained.
5. Enter a malformed pair or reuse the source pose ID; confirm the status
   reports a recoverable issue and the library remains unchanged.
