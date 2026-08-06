# Manual Verification Scenario

1. Open Weapon Authoring Wizard, bind a weapon/profile/rig, enter body types
   and directions, then run coverage and inspect the summary.
2. Force an unreachable grip or strict joint limit and use the repair action to
   identify whether reach, target, pole, or limits need adjustment.
3. Select dual-wield, shield, bow, and flexible workflows; author their socket,
   draw/sheath, and path data, then validate each workflow.
4. Save the session, restore it to the same context, and navigate controls with
   keyboard focus.

Expected: coverage is safe, explicit, and repairable. Actual: direct automated
coverage passes; independent twenty-weapon visual acceptance remains QA-WPA-001.
