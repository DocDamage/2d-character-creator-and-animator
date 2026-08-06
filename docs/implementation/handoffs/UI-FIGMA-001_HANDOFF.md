# UI-FIGMA-001 — Implement the Playful-Console Character Studio UI
**Status:** Authorized implementation handoff  
**Target repository:** `DocDamage/2d-character-creator-and-animator`  
**Target engine:** Godot 4.7.1  
**Design source:** `design/character-studio/`  
**Figma file:** `https://www.figma.com/design/OWBAoX5TObGOwIZv10loHG`
## 1. Authorization boundary
This handoff authorizes only the production integration of the approved Character Studio playful-console UI/UX system.
Do not start unrelated gameplay, runtime, export-format, animation-engine, rigging-engine, weapon-solver, or asset-pipeline work. Do not declare the full product complete.
The existing application behavior is authoritative. The visual redesign must wrap and expose real systems; it must not replace them with mock values, placeholder panels, fake validation, or screenshot-only scenes.
## 2. Required reading order
1. `design/character-studio/README.md`
2. `design/character-studio/character-studio.tokens.json`
3. `design/character-studio/character-studio.component-manifest.json`
4. `docs/ui/character-studio-playful-console-ui-ux-spec.md`
5. `design/character-studio/character-studio-playful-console-prototype.html`
6. `design/character-studio/character-studio-playful-console-board.svg`
7. Existing shell, workspace, theme, panel, persistence, accessibility, and test files named by the manifest.
## 3. Figma rule
The Figma file exists, but its MCP synchronization was blocked by the connected Starter plan call limit when this handoff was created. Do not invent node IDs.
When Figma MCP access is available:
1. inspect the existing file without mutating it;
2. import the SVG board as a temporary visual reference;
3. create variables from the token JSON;
4. create components and screens using the exact manifest names;
5. record node-specific URLs in the manifest;
6. use `get_design_context` for each implemented screen;
7. remove temporary reference art after editable components match it.
The repository artifacts are sufficient to begin Godot implementation before the Figma node URLs are available. Any visual conflict must be resolved in favor of the token and component manifests until a node-specific Figma reference is recorded.
## 4. Mandatory implementation sequence
### UI-FIGMA-001-A — Baseline and regression contract
- Run the complete existing automated suite before changing production files.
- Capture current workspace switching, save/reopen, export, controller navigation, high contrast, reduced motion, and DPI behavior.
- Record failing baseline tests separately; do not silently weaken or delete them.
- Produce an inventory of every signal, callable, node path, autoload interaction, and persisted field used by the shell and six workspace panels.
Exit: baseline evidence exists and the public behavior contract is documented.
### UI-FIGMA-001-B — Token foundation
Create `app/shared_ui/playful_theme_tokens.gd` as the single code mapping for the JSON tokens.
Required groups:
- semantic colors;
- workspace accents;
- spacing;
- radii;
- border widths;
- typography sizes;
- motion durations;
- minimum target sizes.
Update `theme_service.gd` and `default_theme.tres` to consume the mapping without removing dark/light, high-contrast, reduced-motion, or 100–200% DPI behavior.
Exit: no workspace-specific hardcoded accent values remain in new UI code; token tests pass.
### UI-FIGMA-001-C — Shared controls
Create these reusable scenes and focused scripts:
- `app/shared_ui/components/joy_button.tscn`
- `app/shared_ui/components/sticker_tile.tscn`
- `app/shared_ui/components/guide_bubble.tscn`
- `app/shared_ui/components/status_badge.tscn`
- `app/shared_ui/components/controller_hint.tscn`
Each component must expose documented properties, all required states, focus behavior, accessible minimum size, and theme-token binding.
Do not copy component internals into workspace scenes.
Exit: component unit tests and a visual component gallery pass at supported DPI scales.
### UI-FIGMA-001-D — Persistent shell
Update:
- `app/shared_ui/main_window.tscn`
- `app/shared_ui/main_window.gd`
- `app/shared_ui/workspace_navigation.gd`
- `app/shared_ui/dock_layout_manager.gd`
Implement the 74px top bar, six workspace tabs, project/workspace context, search entry, 42px status/controller bar, autosave state, compatibility summary, and context-sensitive hints.
Preserve command palette, hidden legacy menus still required by shortcuts, docking behavior, focus cycling, diagnostics, workspace state, and close/unsaved handling.
Exit: all six workspaces switch correctly with mouse, keyboard, and controller, and preserved state survives switching.
### UI-FIGMA-001-E — Project Play Hub
Implement the Project layout and real bindings for recent projects, quick start, metrics, readiness, recovery, and open/create/sample/continue flows.
Hero action: `Open selected project`.
Exit: each startup flow reaches the correct real workspace and no fake metric or readiness value remains.
### UI-FIGMA-001-F — Character Creator
Update the existing character creator panel to the four-zone layout from the manifest.
Preserve real part registry, compatibility filters, body types, layers, seeded randomization, undo/redo, direction preview, current character data, and validation.
Hero action: `Apply and validate character`.
Exit: a production-shaped character can be assembled, randomized deterministically, undone, saved, reopened, and validated with identical data.
### UI-FIGMA-001-G — Rig Studio
Integrate hierarchy, rig map, poses, IK, constraints, deformation/weights, facing coverage, retarget preview, and correction state into the approved layout.
Hero action: `Validate rig`.
Exit: authoring actions mutate the real rig and survive save/reopen.
### UI-FIGMA-001-H — Animation Studio
Integrate Story Track and Advanced Timeline without deleting advanced features.
Preserve clip selection, layered blending, state transitions, rule graph, keys, events, curves, onion skin, IK, mesh tools, playback, and playhead state.
Hero action: `Play animation / add key`.
Exit: a clip can be edited, previewed, saved, reopened, and exported with the same key/event data.
### UI-FIGMA-001-I — Equipment Studio
Integrate the weapon library, grip sockets, hand pose, solver, body-type coverage, eight-direction coverage, and diagnostics.
Hero action: `Solve hands / save grip profile`.
The interface must continue to support arbitrary user-defined weapons and tools. Do not hardcode a fixed weapon catalog.
Exit: a new weapon definition can be authored, both hands aligned, coverage validated, profile saved, reopened, and used at runtime.
### UI-FIGMA-001-J — Export and quality
Integrate package cards, queue, output path, readiness checklist, validation summary, clean-consumer state, cancel/retry, and actionable failures.
Hero action: `Export character package`.
Exit: a real package exports and imports into a clean Godot consumer project; cancellation and failures leave recoverable state.
### UI-FIGMA-001-K — Accessibility and release evidence
Verify:
- mouse, keyboard, and controller parity;
- visible focus and logical focus order;
- 44×44 minimum targets;
- WCAG AA contrast;
- high-contrast mode without color-only meaning;
- reduced motion;
- 100%, 125%, 150%, 175%, and 200% DPI;
- no hover-only critical action;
- no clipped or unreachable controls.
Exit: automated checks and runtime screenshots prove each requirement.
## 5. File-size and structure rule
Keep authored production code files at or below 300 physical lines whenever practical. Split by responsibility. Do not evade the limit by compressing multiple statements onto one line. A necessary exception must be documented in the evidence bundle with the reason and attempted alternatives.
## 6. Forbidden shortcuts
- No placeholder, TODO, stub, fake success, hardcoded demo result, or decorative-only panel.
- No replacing real validation with label text.
- No deleting advanced features to make the redesigned layout easier.
- No weakening tests, scanners, coverage, evidence gates, accessibility checks, or clean-consumer verification.
- No claiming completion from scene parsing, static screenshots, or headless startup alone.
- No guessed Figma node IDs.
- No Nintendo characters, icons, layout copies, trade dress, or proprietary visual motifs.
## 7. Required automated verification
At minimum run and record:
- the complete existing Godot test runner;
- LOC checker;
- stub scanner;
- evidence checker;
- focused component/theme tests;
- workspace navigation tests;
- save/reopen state tests;
- seeded randomization determinism tests;
- validation tests with passing and failing data;
- export and clean-consumer import tests;
- controller/focus tests;
- DPI, high-contrast, and reduced-motion tests.
A skipped tool or unavailable environment is a blocker, not a pass.
## 8. Required manual/runtime evidence
Capture the running application, not editor-only scenes:
1. Project Play Hub.
2. Character Creator with real layered character and direction change.
3. Rig Studio with real hierarchy/pose/retarget state.
4. Animation Studio in Story Track and Advanced Timeline.
5. Equipment Studio with a non-default weapon and solved grips.
6. Export with readiness pass and a clean-consumer import result.
7. Keyboard focus path.
8. Controller navigation.
9. High contrast.
10. Reduced motion.
11. 100%, 150%, and 200% DPI screenshots; automated checks cover all supported values.
## 9. Evidence bundle
Create `docs/implementation/evidence/UI-FIGMA-001/` containing:
- `README.md` with exact scope and result;
- `test-results.txt` with commands and unedited output;
- `manual-verification.md` with steps and observed results;
- `figma-node-map.md` when node-specific URLs exist;
- runtime screenshots;
- clean-consumer export/import evidence;
- documented file-size exceptions, if any;
- known failures with explicit blocking status.
## 10. Completion gate
UI-FIGMA-001 is complete only when all sequence exits pass, the evidence bundle is complete, all six real workflows remain functional, accessibility is verified, and the visual system is implemented through reusable components and tokens.
After completion, create a new handoff for any follow-on task. Do not begin it in the same Codex thread.
