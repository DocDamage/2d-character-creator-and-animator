# Manual Verification Scenario

1. Bind a primary grip to a rig hand and resolve the weapon while moving that
   hand; verify the grip remains at the hand and a missing bone is diagnosed.
2. Feed controller and world anchors with rotated transforms; verify configured
   local position and rotation offsets follow their anchors.
3. Configure a body socket and a multi-segment path, save/reopen each profile,
   then verify socket and path-tangent transforms resolve deterministically.
4. Register a callable `WeaponDrivePlugin` under a serialized plugin ID and
   verify a valid transform succeeds while a missing plugin reports a message.

Expected: each mode supplies `success`, `drive_mode`, `position`, and
`rotation`, or a concrete recoverable diagnostic. Actual: automated coverage
confirmed each required path; independent visual acceptance remains QA-WPN-001.
