# Verification Scenario

The acceptance workflow constructs a supported-body rifle with primary and
secondary grips, applies body/direction/animation offsets, and uses the public
`WeaponPosingEditor`/`WeaponPoseSolver` APIs to align both independently
modelled arm chains. It measures each solved hand against the resolved grip
target and separately checks that an unsupported body type reports failure.

It then binds gameplay timing data to the same workflow: action points,
hitbox/hurtbox snapshots, events, clamped audio pan, visemes, typed script
parameters, tags, and variables. All specialized tracks are serialized through
`TrackRegistry` and restored before their concrete APIs are checked.

Full master-plan weapon authoring, advanced drive modes, diagnostic overlays,
and gameplay runtime visualization are intentionally outside this legacy core
acceptance.
