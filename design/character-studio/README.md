# Character Studio Playful-Console UI Handoff

This directory is the code-readable design source for the approved Character Studio UI direction.

## Design source

- Figma file: `https://www.figma.com/design/OWBAoX5TObGOwIZv10loHG`
- Product: Modular 2D Character Creator and Animator
- Engine target: Godot 4.7.1
- Repository: `DocDamage/2d-character-creator-and-animator`
- Visual direction: playful console, tactile cards, rounded controls, color-coded workspaces, large central preview, and one hero action per workspace

The Figma file was created in the earlier project thread. Its MCP synchronization is currently incomplete because the connected Figma Starter plan rejected additional MCP calls. The files here preserve the approved direction without requiring Codex to infer colors, layouts, component states, or Godot mappings from screenshots.

## Files

| File | Purpose |
| --- | --- |
| `character-studio.tokens.json` | Canonical colors, spacing, radii, typography, motion, and accessibility values. |
| `character-studio.component-manifest.json` | Figma naming, reusable components, workspace layouts, state rules, and Godot path mapping. |
| `character-studio-playful-console-prototype.html` | Self-contained interactive six-workspace prototype. |
| `character-studio-playful-console-board.svg` | Editable vector overview that can be imported into Figma. |
| `../../docs/ui/character-studio-playful-console-ui-ux-spec.md` | Human-readable implementation specification. |
| `../../docs/implementation/handoffs/UI-FIGMA-001_HANDOFF.md` | Strict Codex execution handoff. |

## Source-of-truth order

1. Production behavior and data contracts already in the Godot repository.
2. `character-studio.tokens.json` for visual values.
3. `character-studio.component-manifest.json` for names, states, layouts, and path mapping.
4. The HTML prototype and SVG board for visual composition.
5. Figma for editable design once the file is synchronized and node-specific links are recorded here.

Visual redesign work must not replace, fake, or weaken validation, save/reopen behavior, export fidelity, runtime packages, accessibility, or controller support.

## Codex usage

Codex should read the strict handoff first. It must implement shared foundations before individual workspaces, preserve existing signals and data binding, and provide runtime screenshots and automated evidence rather than claiming completion from static scene inspection.

When Figma MCP access is available again:

1. Import `character-studio-playful-console-board.svg` into the existing Figma file.
2. Create variables from `character-studio.tokens.json`.
3. Build the components and screens named in the component manifest.
4. Replace the `pending` Figma node references in the manifest with node-specific URLs.
5. Use those node URLs with Figma `get_design_context` during implementation and review.
