# Architecture Overview
# Modular 2D Character Creator and Animation Studio

> **Version:** 0.1.0-dev  
> **Last Updated:** 2026-08-05

---

## 1. High-Level Architecture

The application is built on Godot 4.7.1 and follows a service-oriented, workspace-based architecture.

```text
┌─────────────────────────────────────────────────────────────────┐
│                    Application Shell (app/)                      │
│  ┌──────────┐ ┌────────────┐ ┌───────────┐ ┌───────────────┐  │
│  │ Bootstrap│ │ Workspaces │ │ Commands  │ │ Shared UI     │  │
│  └──────────┘ └────────────┘ └───────────┘ └───────────────┘  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              Application State (AppState)                 │  │
│  └──────────────────────────────────────────────────────────┘  │
├─────────────────────────────────────────────────────────────────┤
│                     Core Services (core/)                        │
│  ┌──────┐ ┌────────┐ ┌────────────┐ ┌──────────┐ ┌─────────┐ │
│  │ Docs │ │ Assets │ │ Serialize   │ │ Migrate  │ │ Validate │ │
│  └──────┘ └────────┘ └────────────┘ └──────────┘ └─────────┘ │
├─────────────────────────────────────────────────────────────────┤
│                   Domain Modules                                │
│  ┌──────────┐ ┌────────┐ ┌───────────┐ ┌──────────────────┐  │
│  │Character │ │Rigging │ │Animation  │ │Weapons & Equip   │  │
│  └──────────┘ └────────┘ └───────────┘ └──────────────────┘  │
│  ┌──────────┐ ┌────────┐ ┌───────────┐ ┌──────────────────┐  │
│  │Deform    │ │Media   │ │Gameplay   │ │Export & Runtime  │  │
│  └──────────┘ └────────┘ └───────────┘ └──────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## 2. Key Design Principles

### 2.1 Autoload Services
Five global singletons provide cross-cutting services:
- **AppState** — Project open/close, dirty state, workspace selection, theme
- **CommandService** — Undo/redo system; all data changes pass through here
- **IDService** — Stable, collision-resistant ID generation
- **SerializationService** — Deterministic JSON serialization, transactional save, migration
- **DiagnosticsService** — Centralized logging, filtering, and error tracking

### 2.2 Workspace Architecture
Six workspaces, each self-contained with its own UI panels and logic:
1. Project and Asset Workspace
2. Character Creator Workspace
3. Rigging and Deformation Workspace
4. Animation Studio Workspace
5. Weapon and Equipment Pose Studio
6. Preview, Rules, Runtime, and Export Workspace

Workspace switching preserves project data, selection, animation position, and undo history.

### 2.3 Data Flow
```
User Action → CommandService.execute(do, undo)
  → Domain model mutation
  → Signal emission
  → UI update
  → AppState.mark_dirty()

Save: SerializationService.save_project(data, path)
  → temp file → validate → backup rotate → atomic rename
```

### 2.4 Dual Pipeline Support
- **Modular Skeletal Pipeline** — Bones, IK, constraints, meshes, weights, smooth interpolation
- **Frame/Pixel-Safe Pipeline** — Layered frames, integer snapping, discrete angles, nearest-neighbor

Characters may use either pipeline or a hybrid.

## 3. Project Format

Projects are stored as versioned JSON files (`.chrproj`):
```json
{
  "schema_version": "1.0.0",
  "project_id": "<uuid>",
  "project_name": "...",
  "created_at": 1234567890,
  "modified_at": 1234567890,
  "objects": {
    "characters": {},
    "rigs": {},
    "animations": {},
    "weapons": {},
    "assets": {}
  },
  "settings": {},
  "metadata": {}
}
```

- Stable immutable IDs for all objects
- Relative asset paths
- Deterministic serialization
- Versioned schemas with migration support
- Transactional save with rolling backups

## 4. Runtime Plugin

A separate Godot addon (`runtime_plugin/`) provides:
- Runtime package importer
- Modular animation player
- Skeleton2D reconstruction
- Mesh/deformation runtime
- Facing-grid evaluation
- Event and action-point delivery
- Equipment/weapon swapping with grip solving

The runtime does not depend on editor-only code.

## 5. Tooling

Built-in development tools:
- `tools/loc_checker/` — Line-of-code compliance (300-line limit)
- `tools/stub_scanner/` — Placeholder and TODO detection
- `tools/evidence_checker/` — Evidence bundle validation
- `tools/schema_validator/` — Project schema validation (future)
- `tools/visual_diff/` — Visual regression comparison (future)

## 6. Testing Strategy

```text
tests/
├── unit/         # Pure logic tests
├── integration/  # Multi-service tests with real resources
├── roundtrip/    # Save/reopen and export/import cycles
├── visual/       # Golden image comparisons
├── stress/       # Performance and scale tests
├── fixtures/     # Baseline and malformed test data
└── golden/       # Expected output artifacts
```

## 7. Key Constraints

- Production source files ≤ 300 lines (with documented exceptions)
- No placeholders in production paths
- Implementation and verification in separate threads
- One task per Codex thread
- Mandatory handoff file per task
- Evidence bundles for every completed task
- Independent verification required for all features