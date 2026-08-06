# Manual Verification Scenario

1. Open **Facing Grid Directions** with at least two configured directions.
2. Set **Direction blend** to Sprite crossfade and drag **Continuous Direction
   Preview** from 0° through 360°.
3. Confirm the radial line moves continuously, the angle readout follows the
   slider, and the preview label identifies the expected primary/secondary
   cells and blend percentage between direction boundaries.
4. Configure compatible neighboring mesh states as described in `FAC-009`.
   Confirm the mesh label reports the interpolated vertex count at a midpoint.
5. Choose **Use Hard Direction Switching**. Confirm the preview immediately
   reports a hard selection rather than a crossfade.
6. Save/reopen the grid and repeat the scrub. Confirm the stored direction,
   blend mode, and mesh state evaluate identically.

Missing-cell diagnostics and pixel-mode controls remain separate tasks.
