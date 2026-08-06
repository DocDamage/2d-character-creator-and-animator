# Manual Verification Scenario

1. Bind a rig with non-zero local position/rotation and non-unit scale.
2. Choose **Additive offsets**, capture a pose containing position/rotation
   deltas and scale multipliers, then apply it.
3. Confirm the resulting position/rotation equal base plus delta, while scale
   equals the component-wise product.
4. Capture an absolute pose in the same panel and confirm it replaces, rather
   than composes with, the current local transforms.
5. Try application against a different rig ID or missing bones and confirm the
   recoverable diagnostic prevents unrelated data changes.
