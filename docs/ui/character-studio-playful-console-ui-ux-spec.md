# Character Studio Playful-Console UI/UX Specification
**Status:** Approved implementation source  
**Target:** Godot 4.7.1 desktop authoring application  
**Repository:** `DocDamage/2d-character-creator-and-animator`  
**Figma:** `https://www.figma.com/design/OWBAoX5TObGOwIZv10loHG`  
**Design artifacts:** `design/character-studio/`
## 1. Product intent
Character Studio must feel welcoming, tactile, colorful, and easy to explore without becoming toy-like or hiding professional controls. The character, pose, animation, equipment, or export preview is always the visual center of gravity. Each workspace presents one obvious hero action while advanced controls remain available in a predictable inspector or secondary mode.
This is an original playful-console interface language. Do not copy Nintendo layouts, characters, icons, trade dress, sound design, or proprietary visual motifs.
## 2. Non-negotiable behavior
The redesign must preserve all authoritative project data and production behavior:
- six integrated workspaces;
- real save, reopen, recovery, validation, and export behavior;
- layered character assembly and eight-direction preview;
- rigging, poses, retargeting, deformation, and constraints;
- animation composition, state, rule, event, and timeline data;
- arbitrary weapon definitions, grip sockets, hand poses, and arm alignment;
- runtime package and clean-consumer import fidelity;
- keyboard, controller, high-contrast, reduced-motion, and DPI support.
A screenshot, static mockup, successful scene load, or passing test that never exercises real data is not proof of completion.
## 3. Visual language
### 3.1 Foundations
- Paper background: `#F4F7FC`
- Card/surface: `#FFFFFF`
- Primary ink: `#16233B`
- Muted copy: `#66738A`
- Divider/border: `#DBE4F1`
- Navy focus/structure: `#1E3155`
- Project coral: `#FF5F62`
- Create sky: `#4AB8FF`
- Rig yellow: `#FFD34D`
- Animate violet: `#8D72FF`
- Equip orange: `#FF9B4B`
- Export mint: `#58D5A1`
- Optional decorative pink: `#FF8EC7`
The JSON token file is authoritative for exact values.
### 3.2 Shape and elevation
- Cards: 20–26px corner radius.
- Controls: 12–16px corner radius.
- Selected tiles: 3px outline plus visible elevation.
- Focus: 3px navy ring with sufficient separation from the component edge.
- Pressed controls: 2px visual downward offset, disabled when reduced motion is enabled.
- Use borders and labels with color; never communicate selection or validity by color alone.
### 3.3 Typography
Use Trebuchet MS when available, with Segoe UI and the platform sans-serif as fallbacks.
- Display/title: 28–34px, bold, tight line height.
- Panel title: 15–18px, bold.
- Body: 13–15px.
- Caption: 10–12px.
- Eyebrow: 10–11px, uppercase, bold, tracked.
Godot font resources may use a metrically suitable packaged fallback, but text hierarchy and target measurements must remain equivalent.
### 3.4 Motion
- Control response: 120–180ms.
- Panel transition: 180–240ms.
- Toast lifetime: 1.8 seconds.
- Default easing: ease-out.
- Reduced motion: remove translation and scaling; preserve immediate state changes and focus movement.
## 4. Persistent shell
### 4.1 Top bar
Height: 74px.
Required items:
1. Character Studio brand mark and active project/workspace context.
2. Rounded workspace tabs: PROJECT, CREATE, RIG, ANIMATE, EQUIP, EXPORT.
3. Active tab uses its workspace accent and a text label.
4. Search/command palette entry.
5. Overflow/menu access without hiding critical actions.
The shell maps to:
- `app/shared_ui/main_window.tscn`
- `app/shared_ui/main_window.gd`
- `app/shared_ui/workspace_navigation.gd`
- `app/shared_ui/dock_layout_manager.gd`
### 4.2 Bottom status bar
Height: 42px.
Required items:
- autosave state;
- current validation/compatibility summary;
- context-sensitive keyboard/controller hints;
- persistent access to diagnostics when warnings or failures exist.
Reference labels from the approved prototype:
- `● AUTOSAVED`
- `Character valid · 0 compatibility conflicts`
- `A Select`, `B Back`, `X Randomize`, `Y Validate`
## 5. Reusable components
### 5.1 Joy Button
Scene target: `app/shared_ui/components/joy_button.tscn`
- Supports text, optional icon, workspace accent, disabled state, and focus state.
- Minimum interactive target: 44×44px.
- States: default, hover, pressed, focus, disabled.
- Primary actions use the active workspace accent.
### 5.2 Sticker Tile
Scene target: `app/shared_ui/components/sticker_tile.tscn`
Use for projects, assets, categories, poses, clips, weapons, and export packages.
- Title, optional subtitle, thumbnail, badge, and selected state.
- States: default, hover, selected, invalid, disabled.
- Selection remains visible in high contrast and grayscale.
### 5.3 Guide Bubble
Scene target: `app/shared_ui/components/guide_bubble.tscn`
- Non-blocking contextual instruction or validation explanation.
- Tones: info, success, warning, danger.
- Must not replace diagnostics or hide actionable errors.
### 5.4 Status Badge
Scene target: `app/shared_ui/components/status_badge.tscn`
- Compact state for saved, ready, warning, invalid, missing coverage, or export result.
- Includes icon plus text.
### 5.5 Controller Hint
Scene target: `app/shared_ui/components/controller_hint.tscn`
- Platform-aware glyph or text binding.
- Keyboard and controller actions must remain equivalent.
### 5.6 Hero Canvas
Owner: `app/shared_ui/studio_surface.gd`
- Central preview surface with checkerboard transparency.
- Modes: viewport, rig, animation, equipment, export.
- Preserves zoom, pan, current direction, selection, and active tool where applicable.
- Uses production project data; no decorative fake character state in the application.
## 6. Workspace specifications
### 6.1 Project Play Hub
Accent: coral. Layout: 1028px main content plus 360px readiness rail.
Required sections:
- welcome/project hero;
- recent projects;
- new/open/sample/continue quick start;
- production metrics;
- readiness checklist;
- recovery/autosave state.
Hero action: **Open selected project**.
### 6.2 Character Creator
Accent: sky. Desktop columns: 72px mode rail, 220px journey panel, 760px hero canvas, 316px context drawer.
Mode rail labels:
- Body
- Head
- Hair
- Face
- Upper
- Lower
- Hands
- Feet
- Accessories
- Props
Required behavior:
- compatible asset filtering and searchable layers;
- real layered character preview;
- eight-direction controls;
- body type, skin swatches, height, and build controls;
- flip, seeded randomize, undo, and redo;
- explicit validation and conflict explanation.
Hero action: **Apply and validate character**.
### 6.3 Rig Studio
Accent: yellow. Desktop columns: 250px library, 794px hero canvas, 336px inspector.
Required sections:
- rig map and hierarchy;
- pose library;
- IK and constraints;
- deformation and weights;
- facing coverage;
- retarget preview and correction layer.
Hero action: **Validate rig**.
### 6.4 Animation Studio
Accent: violet. Desktop columns: 250px clip/state rail, 794px stage/graph, 336px key inspector.
Required modes:
- Story Track for approachable clip assembly;
- Advanced Timeline for detailed keys and tracks.
Required sections:
- playback and frame state;
- layered blend stack;
- state transitions and rule graph;
- onion skin, curves, IK, and mesh tools;
- events, gameplay metadata, and key inspector.
Hero action: **Play animation / add key**.
### 6.5 Equipment Studio
Accent: orange. Desktop columns: 250px weapon library, 794px grip stage, 336px solver/coverage inspector.
Required sections:
- arbitrary weapon/tool cards;
- grip sockets and hand pose;
- arm, elbow, wrist, and hand solver;
- body-type coverage;
- eight-direction coverage;
- compatibility diagnostics and saved grip profiles.
Hero action: **Solve hands / save grip profile**.
### 6.6 Export
Accent: mint. Desktop columns: 968px package/readiness content plus 420px summary rail.
Required sections:
- export package cards and queue;
- output path and format;
- readiness checklist;
- validation summary;
- clean-consumer import status;
- cancel, retry, and failure diagnostics.
Hero action: **Export character package**.
## 7. Interaction requirements
- Workspace tabs update active content, context label, accent, and focus destination.
- Seeded randomization is deterministic and reversible through undo.
- Validation runs real compatibility and project rules.
- Selection, invalid, disabled, focus, loading, empty, and error states are designed for every reusable component.
- Critical actions are never hover-only.
- Confirmation is required only for destructive or irreversible operations.
- Long operations expose progress, cancel where safe, and a useful failure result.
- Save/reopen preserves active workspace, layout, selected assets, direction, playhead, zoom/pan, and relevant inspector state.
## 8. Accessibility requirements
- WCAG AA contrast for text and meaningful controls.
- 44×44px minimum targets.
- Visible keyboard focus at all times.
- Keyboard and controller parity for all primary workflows.
- High-contrast mode remains understandable without workspace colors.
- DPI scale supports 100%, 125%, 150%, 175%, and 200%.
- No clipped labels, inaccessible tabs, or unreachable controls at supported scales.
- Reduced motion removes non-essential movement.
- Toasts and transient messages also update a persistent status/diagnostic surface.
## 9. Godot implementation map
Create:
- `app/shared_ui/playful_theme_tokens.gd`
- `app/shared_ui/components/joy_button.tscn`
- `app/shared_ui/components/sticker_tile.tscn`
- `app/shared_ui/components/guide_bubble.tscn`
- `app/shared_ui/components/status_badge.tscn`
- `app/shared_ui/components/controller_hint.tscn`
Update without breaking public behavior:
- `app/shared_ui/main_window.tscn/.gd`
- `app/shared_ui/workspace_navigation.gd`
- `app/shared_ui/dock_layout_manager.gd`
- `app/shared_ui/theme_service.gd`
- `app/shared_ui/default_theme.tres`
- `app/shared_ui/studio_surface.gd`
- each existing workspace panel named in the component manifest.
Keep authored production code files below 300 physical lines whenever practical. Split by responsibility rather than compressing unrelated logic onto single lines.
## 10. Acceptance criteria
Completion requires evidence that:
1. all six workspaces match the approved hierarchy and workspace color identity;
2. shared controls are real reusable scenes, not copied per screen;
3. existing authoritative project data is preserved;
4. seeded randomization, validation, save/reopen, and export are real;
5. the application remains usable by mouse, keyboard, and controller;
6. high contrast, reduced motion, and 100–200% DPI are verified;
7. a clean Godot consumer project imports and plays an exported package;
8. automated tests, headless application checks, and visual runtime screenshots are attached;
9. no placeholder content, TODO, fake success state, or screenshot-only implementation remains;
10. the design remains original and does not copy Nintendo visual identity.
