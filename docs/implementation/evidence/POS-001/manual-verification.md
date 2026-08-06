# Manual Verification Scenario

1. Create a named pose with a rig-profile ID and transforms for at least two
   bones.
2. Enter transform data using position/rotation/scale or local transform
   aliases and confirm the stored pose uses normalized fields.
3. Mark the pose absolute or additive and add optional tags/metadata.
4. Save/reopen the pose data and confirm all transforms and metadata persist.
5. Attempt to save an unnamed pose or a transform with an empty bone ID;
   confirm validation reports a recoverable failure.

Saving and applying the pose is `POS-002` scope.
