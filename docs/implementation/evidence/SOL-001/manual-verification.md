# Manual Verification Scenario

1. Author a primary and secondary hand binding, then solve a reachable dual
   grip and inspect the two arm segments, targets, and instrumentation metrics.
2. Set an elbow pole, choose wrist preservation, and confirm the selected elbow
   side and preserved hand orientation update predictably.
3. Add an upper-joint range that prevents the target; verify the limit and
   remaining grip-gap diagnostics instead of accepting a bad pose.
4. Exceed the reach allowance and confirm the solver returns an unreachable
   code without changing the prior rig pose; enable pixel mode to inspect
   quantized rotations.

Expected: no silent unreachable or constrained pose. Actual: all modeled paths
are covered by focused automated checks; visual acceptance remains QA-SOL-001.
