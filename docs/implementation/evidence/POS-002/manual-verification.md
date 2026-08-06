# Manual Verification Scenario

1. Open **Saved Poses** from the application dock and bind the selected rig
   through the application host's `bind_pose_rig` API.
2. Enter a stable pose ID and display name, then choose **Capture Current Rig**.
3. Move local position, rotation, and scale for one or more rig bones, select
   the saved pose, and choose **Apply Selected Pose**.
4. Confirm every captured transform is restored and project dirty state is set.
5. Attempt application after binding a different rig, or a rig missing all
   captured bones; confirm the status message gives a recoverable diagnostic.

The integrated Godot suite executes these capture/apply actions through both
the panel and the application-shell binding route.
