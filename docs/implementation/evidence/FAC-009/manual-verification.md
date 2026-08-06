# Manual Verification Scenario

1. Open **Facing Grid Directions**, choose a direction, and enter a shared
   **Mesh ID**, a matching **Topology ID**, and vertices such as
   `0,0; 2,0`; select **Store Mesh**.
2. Select its next direction and enter the same Mesh/Topology IDs with a
   matching number of directional vertices, such as `2,2; 4,0`; select
   **Store Mesh**.
3. Return to the first direction. Confirm the panel reports that mesh blending
   with the next direction is ready and shows the vertex count.
4. Keep **Allow deformable mesh blending** enabled, choose Sprite crossfade,
   save/reopen, and evaluate a midpoint. Confirm the `mesh_blend` result
   includes interpolated vertices.
5. Change one neighboring Mesh ID, Topology ID, or vertex count. Confirm the
   status explains that blending is unavailable and runtime retains a safe
   non-mesh crossfade result.
6. Enter malformed vertices, such as `not-a-vertex`. Confirm the panel rejects
   the edit without changing the stored mesh data.

Continuous visual scrubbing remains `FAC-010` scope.
