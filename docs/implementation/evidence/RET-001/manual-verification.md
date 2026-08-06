# Manual Verification Scenario

1. Create a named profile for a selected rig and map the required `root` role
   plus meaningful roles such as `hand_left`.
2. Save/reopen it and confirm its rig identity, role names, bone IDs, and
   metadata persist in a stable order.
3. Assign the same bone to two semantic roles or reference a bone absent from
   the bound rig; confirm profile validation gives a recoverable error.
