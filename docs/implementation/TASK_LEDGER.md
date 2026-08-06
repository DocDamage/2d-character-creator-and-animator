# Task Ledger
# Modular 2D Character Creator and Animation Studio

> **Status:** Active  
> **Last Updated:** 2026-08-05

> **Master-plan reconciliation:** `docs/implementation/MASTER_PLAN_RECONCILIATION.md` is the canonical mapping between legacy `GRID-*`, `EXP-*`, and `RNT-*` work and the authoritative master-plan IDs. New work uses master-plan IDs; legacy implementation rows retain their historical IDs.

---

## Overview

Every task in the project is recorded here. Each row tracks one Codex thread. Threads must be independent — implementation and verification for the same task must be separate rows.

## Column Definitions

| Column | Description |
|--------|-------------|
| Task ID | Unique task identifier (e.g., GOV-001) |
| Title | Short descriptive title |
| Thread Type | IMPLEMENTATION / VERIFICATION / REPAIR / AUDIT / DOCUMENTATION / RELEASE |
| Dependencies | Task IDs that must be completed before this task |
| Branch | Git branch used for the task |
| Commit | Final commit hash |
| Status | PLANNED / IN_PROGRESS / COMPLETED / FAILED / BLOCKED |
| Handoff Path | Relative path to handoff file |
| Evidence Path | Relative path to evidence bundle directory |
| Requirement IDs | Referenced REQ-* identifiers |
| Recommended Next Task | Suggested follow-on task ID |
| Assigned Date | Date task was assigned |
| Completed Date | Date task was completed |

---

## Task Rows

### Milestone 0 — Governance and Evidence

| Task ID | Title | Thread Type | Dependencies | Branch | Commit | Status | Handoff Path | Evidence Path | Requirement IDs | Recommended Next | Assigned | Completed |
|---------|-------|-------------|--------------|--------|--------|--------|--------------|---------------|-----------------|-----------------|----------|-----------|
| GOV-001 | Initialize repository structure and authoritative rules | IMPLEMENTATION | - | - | - | COMPLETED | `docs/implementation/handoffs/GOV-001_HANDOFF.md` | `docs/implementation/evidence/GOV-001/` | REQ-GOV-001 | QA-GOV-001 | 2026-08-05 | 2026-08-05 |
| GOV-002 | Create requirement IDs and traceability matrix | IMPLEMENTATION | GOV-001 | - | - | COMPLETED | `docs/implementation/handoffs/GOV-001_HANDOFF.md` | `docs/implementation/evidence/GOV-002/` | REQ-GOV-002 | QA-GOV-001 | 2026-08-05 | 2026-08-05 |
| GOV-003 | Create task ledger and handoff templates | IMPLEMENTATION | GOV-002 | - | - | COMPLETED | `docs/implementation/handoffs/GOV-001_HANDOFF.md` | `docs/implementation/evidence/GOV-003/` | REQ-GOV-003, REQ-GOV-004 | QA-GOV-001 | 2026-08-05 | 2026-08-05 |
| GOV-004 | Implement LOC checker and exception registry | IMPLEMENTATION | GOV-003 | - | - | COMPLETED | `docs/implementation/handoffs/GOV-001_HANDOFF.md` | `docs/implementation/evidence/GOV-004/` | REQ-GOV-005, REQ-GOV-006 | QA-GOV-001 | 2026-08-05 | 2026-08-05 |
| GOV-005 | Implement stub scanner | IMPLEMENTATION | GOV-004 | - | - | COMPLETED | `docs/implementation/handoffs/GOV-001_HANDOFF.md` | `docs/implementation/evidence/GOV-005/` | REQ-GOV-007 | QA-GOV-001 | 2026-08-05 | 2026-08-05 |
| GOV-006 | Implement evidence bundle checker | IMPLEMENTATION | GOV-005 | - | - | COMPLETED | `docs/implementation/handoffs/GOV-001_HANDOFF.md` | `docs/implementation/evidence/GOV-006/` | REQ-GOV-008 | QA-GOV-001 | 2026-08-05 | 2026-08-05 |
| GOV-007 | Define dependency and asset license manifests | IMPLEMENTATION | GOV-006 | - | - | COMPLETED | `docs/implementation/handoffs/GOV-001_HANDOFF.md` | `docs/implementation/evidence/GOV-007/` | REQ-GOV-009, REQ-GOV-010 | QA-GOV-001 | 2026-08-05 | 2026-08-05 |
| GOV-008 | Create baseline sample and malformed fixtures | IMPLEMENTATION | GOV-007 | - | - | COMPLETED | `docs/implementation/handoffs/GOV-001_HANDOFF.md` | `docs/implementation/evidence/GOV-008/` | REQ-GOV-011, REQ-GOV-012 | QA-GOV-001 | 2026-08-05 | 2026-08-05 |
| QA-GOV-001 | Verify governance controls in a clean thread | VERIFICATION | GOV-001, GOV-002, GOV-003, GOV-004, GOV-005, GOV-006, GOV-007, GOV-008 | - | - | COMPLETED | `docs/implementation/handoffs/QA-GOV-001_HANDOFF.md` | `docs/implementation/evidence/QA-GOV-001/` | REQ-GOV-001 through REQ-GOV-012 | APP-001 | 2026-08-05 | 2026-08-05 |

### Milestone 1 — Application Shell

| Task ID | Title | Thread Type | Dependencies | Branch | Commit | Status | Handoff Path | Evidence Path | Requirement IDs | Recommended Next | Assigned | Completed |
|---------|-------|-------------|--------------|--------|--------|--------|--------------|---------------|-----------------|-----------------|----------|-----------|
| APP-001 | Bootstrap the Godot application and startup diagnostics | IMPLEMENTATION | QA-GOV-001 | - | - | COMPLETED | `docs/implementation/handoffs/APP-001_HANDOFF.md` | `docs/implementation/evidence/APP-001/` | REQ-APP-001 | APP-002 | 2026-08-05 | 2026-08-05 |
| APP-002 | Implement main window and dock layout | IMPLEMENTATION | APP-001 | - | - | COMPLETED | `docs/implementation/handoffs/APP-002_HANDOFF.md` | `docs/implementation/evidence/APP-002/` | REQ-APP-002 | APP-003 | 2026-08-05 | 2026-08-05 |
| APP-003 | Implement workspace manager | IMPLEMENTATION | APP-002 | - | - | COMPLETED | `docs/implementation/handoffs/APP-003_HANDOFF.md` | `docs/implementation/evidence/APP-003/` | REQ-APP-003 | APP-004 | 2026-08-05 | 2026-08-05 |
| APP-004 | Implement command palette and shortcut registry | IMPLEMENTATION | APP-003 | - | - | COMPLETED | `docs/implementation/handoffs/APP-004_HANDOFF.md` | `docs/implementation/evidence/APP-004/` | REQ-APP-004 | APP-005 | 2026-08-05 | 2026-08-05 |
| APP-005 | Implement dirty state and application-state service | IMPLEMENTATION | APP-004 | - | - | COMPLETED | `docs/implementation/handoffs/APP-005_HANDOFF.md` | `docs/implementation/evidence/APP-005/` | REQ-APP-005 | APP-006 | 2026-08-05 | 2026-08-05 |
| APP-006 | Implement diagnostics drawer | IMPLEMENTATION | APP-005 | - | - | COMPLETED | `docs/implementation/handoffs/APP-006_HANDOFF.md` | `docs/implementation/evidence/APP-006/` | REQ-APP-006 | APP-007 | 2026-08-05 | 2026-08-05 |
| APP-007 | Implement theme and DPI scaling | IMPLEMENTATION | APP-006 | - | - | COMPLETED | `docs/implementation/handoffs/APP-007_HANDOFF.md` | `docs/implementation/evidence/APP-007/` | REQ-APP-007 | APP-008 | 2026-08-05 | 2026-08-05 |
| APP-008 | Implement keyboard/controller focus framework | IMPLEMENTATION | APP-007 | - | - | COMPLETED | `docs/implementation/handoffs/APP-008_HANDOFF.md` | `docs/implementation/evidence/APP-008/` | REQ-APP-008 | APP-009 | 2026-08-05 | 2026-08-05 |
| APP-009 | Implement startup and recent-project screen | IMPLEMENTATION | APP-008 | - | - | COMPLETED | `docs/implementation/handoffs/APP-009_HANDOFF.md` | `docs/implementation/evidence/APP-009/` | REQ-APP-009 | QA-APP-001 | 2026-08-05 | 2026-08-05 |
| QA-APP-001 | Verify application-shell workflows | VERIFICATION | APP-001 through APP-009 | - | - | COMPLETED | `docs/implementation/handoffs/QA-APP-001_HANDOFF.md` | `docs/implementation/evidence/QA-APP-001/` | REQ-APP-001 through REQ-APP-009 | DOC-001 | 2026-08-05 | 2026-08-05 |

### Milestone 2 — Project Format and Persistence

| Task ID | Title | Thread Type | Dependencies | Branch | Commit | Status | Handoff Path | Evidence Path | Requirement IDs | Recommended Next | Assigned | Completed |
|---------|-------|-------------|--------------|--------|--------|--------|--------------|---------------|-----------------|-----------------|----------|-----------|
| DOC-001 | Define project-manifest schema | IMPLEMENTATION | QA-APP-001 | - | - | COMPLETED | `docs/implementation/handoffs/DOC-001_HANDOFF.md` | `docs/implementation/evidence/DOC-001/` | REQ-DOC-001 | DOC-002 | 2026-08-05 | 2026-08-05 |
| DOC-002 | Implement stable ID service | IMPLEMENTATION | DOC-001 | - | - | COMPLETED | `docs/implementation/handoffs/DOC-002_HANDOFF.md` | `docs/implementation/evidence/DOC-002/` | REQ-DOC-002 | DOC-003 | 2026-08-05 | 2026-08-05 |
| DOC-003 | Implement deterministic serialization | IMPLEMENTATION | DOC-002 | - | - | COMPLETED | `docs/implementation/handoffs/DOC-003_HANDOFF.md` | `docs/implementation/evidence/DOC-003/` | REQ-DOC-003 | DOC-004 | 2026-08-05 | 2026-08-05 |

| DOC-004 | Implement transactional save | IMPLEMENTATION | DOC-003 | - | - | COMPLETED | `docs/implementation/handoffs/DOC-004_HANDOFF.md` | `docs/implementation/evidence/DOC-004/` | REQ-DOC-004 | DOC-005 | 2026-08-05 | 2026-08-05 |
| DOC-005 | Implement project load and diagnostics | IMPLEMENTATION | DOC-004 | - | - | COMPLETED | `docs/implementation/handoffs/DOC-005_HANDOFF.md` | `docs/implementation/evidence/DOC-005/` | REQ-DOC-005 | DOC-006 | 2026-08-05 | 2026-08-05 |
| DOC-006 | Implement rolling backups | IMPLEMENTATION | DOC-005 | - | - | COMPLETED | `docs/implementation/handoffs/DOC-006_HANDOFF.md` | `docs/implementation/evidence/DOC-006/` | REQ-DOC-006 | DOC-007 | 2026-08-05 | 2026-08-05 |
| DOC-007 | Implement autosave and recovery journal | IMPLEMENTATION | DOC-006 | - | - | COMPLETED | `docs/implementation/handoffs/DOC-007_HANDOFF.md` | `docs/implementation/evidence/DOC-007/` | REQ-DOC-007 | DOC-008 | 2026-08-05 | 2026-08-05 |
| DOC-008 | Implement schema migrations | IMPLEMENTATION | DOC-007 | - | - | COMPLETED | `docs/implementation/handoffs/DOC-008_HANDOFF.md` | `docs/implementation/evidence/DOC-008/` | REQ-DOC-008 | DOC-009 | 2026-08-05 | 2026-08-05 |
| DOC-009 | Implement corrupt-project recovery | IMPLEMENTATION | DOC-008 | - | - | COMPLETED | `docs/implementation/handoffs/DOC-009_HANDOFF.md` | `docs/implementation/evidence/DOC-009/` | REQ-DOC-009 | DOC-010 | 2026-08-05 | 2026-08-05 |
| DOC-010 | Implement clone and save-as | IMPLEMENTATION | DOC-009 | - | - | COMPLETED | `docs/implementation/handoffs/DOC-010_HANDOFF.md` | `docs/implementation/evidence/DOC-010/` | REQ-DOC-010 | QA-DOC-001 | 2026-08-05 | 2026-08-05 |
| QA-DOC-001 | Verify save, restart, migration, and recovery | VERIFICATION | DOC-001 through DOC-010 | - | - | COMPLETED | `docs/implementation/handoffs/QA-DOC-001_HANDOFF.md` | `docs/implementation/evidence/QA-DOC-001/` | REQ-DOC-001 through REQ-DOC-010 | AST-001 | 2026-08-05 | 2026-08-05 |

### Milestone 3 — Asset Library

| Task ID | Title | Thread Type | Dependencies | Branch | Commit | Status | Handoff Path | Evidence Path | Requirement IDs | Recommended Next | Assigned | Completed |
|---------|-------|-------------|--------------|--------|--------|--------|--------------|---------------|-----------------|-----------------|----------|-----------|
| AST-001 | Asset Registry & Metadata | IMPLEMENTATION | QA-DOC-001 | - | - | COMPLETED | `docs/implementation/handoffs/AST-001_HANDOFF.md` | `docs/implementation/evidence/AST-001/` | REQ-AST-001 through REQ-AST-012 | QA-AST-001 | 2026-08-05 | 2026-08-05 |
| QA-AST-001 | Verify Asset Library Workflows | VERIFICATION | AST-001 | - | - | COMPLETED | `docs/implementation/handoffs/QA-AST-001_HANDOFF.md` | `docs/implementation/evidence/QA-AST-001/` | REQ-AST-001 through REQ-AST-012 | CAN-001 | 2026-08-05 | 2026-08-05 |

### Milestone 4 — Canvas and Command System

| Task ID | Title | Thread Type | Dependencies | Branch | Commit | Status | Handoff Path | Evidence Path | Requirement IDs | Recommended Next | Assigned | Completed |
|---------|-------|-------------|--------------|--------|--------|--------|--------------|---------------|-----------------|-----------------|----------|-----------|
| CAN-001 | Canvas Camera, Selection & Commands | IMPLEMENTATION | QA-AST-001 | - | - | COMPLETED | `docs/implementation/handoffs/CAN-001_HANDOFF.md` | `docs/implementation/evidence/CAN-001/` | REQ-CAN-001 through REQ-CAN-012 | QA-CAN-001 | 2026-08-05 | 2026-08-05 |
| QA-CAN-001 | Verify Canvas & Command Workflows | VERIFICATION | CAN-001 | - | - | COMPLETED | `docs/implementation/handoffs/QA-CAN-001_HANDOFF.md` | `docs/implementation/evidence/QA-CAN-001/` | REQ-CAN-001 through REQ-CAN-012 | RIG-001 | 2026-08-05 | 2026-08-05 |

### Milestone 5 — Rigging

| Task ID | Title | Thread Type | Dependencies | Branch | Commit | Status | Handoff Path | Evidence Path | Requirement IDs | Recommended Next | Assigned | Completed |
|---------|-------|-------------|--------------|--------|--------|--------|--------------|---------------|-----------------|-----------------|----------|-----------|
| RIG-001 | Define rig, bone, and slot schemas | IMPLEMENTATION | QA-CAN-001 | - | - | COMPLETED | `docs/implementation/handoffs/RIG-001_HANDOFF.md` | `docs/implementation/evidence/RIG-001/` | REQ-RIG-001 through REQ-RIG-012 | QA-RIG-001 | 2026-08-05 | 2026-08-05 |
| QA-RIG-001 | Verify rigging system workflows | VERIFICATION | RIG-001 | - | - | COMPLETED | `docs/implementation/handoffs/QA-RIG-001_HANDOFF.md` | `docs/implementation/evidence/QA-RIG-001/` | REQ-RIG-001 through REQ-RIG-012 | IK-001 | 2026-08-05 | 2026-08-05 |

### Milestone 6 — Constraints and IK

| Task ID | Title | Thread Type | Dependencies | Branch | Commit | Status | Handoff Path | Evidence Path | Requirement IDs | Recommended Next | Assigned | Completed |
|---------|-------|-------------|--------------|--------|--------|--------|--------------|---------------|-----------------|-----------------|----------|-----------|
| IK-001 | Define constraint interface and solvers | IMPLEMENTATION | QA-RIG-001 | - | - | COMPLETED | `docs/implementation/handoffs/IK-001_HANDOFF.md` | `docs/implementation/evidence/IK-001/` | REQ-IK-001 through REQ-IK-011 | QA-IK-001 | 2026-08-05 | 2026-08-05 |
| QA-IK-001 | Verify constraints and IK workflows | VERIFICATION | IK-001 | - | - | COMPLETED | `docs/implementation/handoffs/QA-IK-001_HANDOFF.md` | `docs/implementation/evidence/QA-IK-001/` | REQ-IK-001 through REQ-IK-011 | ANM-001 | 2026-08-05 | 2026-08-05 |

### Milestone 7 — Timeline and Animation Data

| Task ID | Title | Thread Type | Dependencies | Branch | Commit | Status | Handoff Path | Evidence Path | Requirement IDs | Recommended Next | Assigned | Completed |
|---------|-------|-------------|--------------|--------|--------|--------|--------------|---------------|-----------------|-----------------|----------|-----------|
| ANM-001 | Define clip, track, key, and property schemas | IMPLEMENTATION | QA-IK-001 | - | - | COMPLETED | `docs/implementation/handoffs/ANM-001_HANDOFF.md` | `docs/implementation/evidence/ANM-001/` | REQ-ANM-001 | ANM-002 | 2026-08-05 | 2026-08-05 |
| ANM-002 | Implement clip browser | IMPLEMENTATION | ANM-001 | - | - | COMPLETED | `docs/implementation/handoffs/ANM-002_HANDOFF.md` | `docs/implementation/evidence/ANM-002/` | REQ-ANM-002 | ANM-003 | 2026-08-05 | 2026-08-05 |
| ANM-003 | Implement dope sheet | IMPLEMENTATION | ANM-002 | - | - | COMPLETED | `docs/implementation/handoffs/ANM-003_HANDOFF.md` | `docs/implementation/evidence/ANM-003/` | REQ-ANM-003 | ANM-004 | 2026-08-05 | 2026-08-05 |
| ANM-004 | Implement per-object tracks | IMPLEMENTATION | ANM-003 | - | - | COMPLETED | `docs/implementation/handoffs/ANM-004_HANDOFF.md` | `docs/implementation/evidence/ANM-004/` | REQ-ANM-004 | ANM-005 | 2026-08-05 | 2026-08-05 |
| ANM-005 | Implement key creation and auto-key | IMPLEMENTATION | ANM-004 | - | - | COMPLETED | `docs/implementation/handoffs/ANM-005_HANDOFF.md` | `docs/implementation/evidence/ANM-005/` | REQ-ANM-005 | ANM-006 | 2026-08-05 | 2026-08-05 |
| ANM-006 | Implement multi-key editing | IMPLEMENTATION | ANM-005 | - | - | COMPLETED | `docs/implementation/handoffs/ANM-006_HANDOFF.md` | `docs/implementation/evidence/ANM-006/` | REQ-ANM-006 | ANM-007 | 2026-08-05 | 2026-08-05 |
| ANM-007 | Implement timing scale, stretch, and ripple | IMPLEMENTATION | ANM-006 | - | - | COMPLETED | `docs/implementation/handoffs/ANM-007_HANDOFF.md` | `docs/implementation/evidence/ANM-007/` | REQ-ANM-007 | ANM-008 | 2026-08-05 | 2026-08-05 |
| ANM-008 | Implement cross-clip copy/paste | IMPLEMENTATION | ANM-007 | - | - | COMPLETED | `docs/implementation/handoffs/ANM-008_HANDOFF.md` | `docs/implementation/evidence/ANM-008/` | REQ-ANM-008 | ANM-009 | 2026-08-05 | 2026-08-05 |
| ANM-009 | Implement image-swap tracks | IMPLEMENTATION | ANM-008 | - | - | COMPLETED | `docs/implementation/handoffs/ANM-009_HANDOFF.md` | `docs/implementation/evidence/ANM-009/` | REQ-ANM-009 | ANM-010 | 2026-08-05 | 2026-08-05 |
| ANM-010 | Implement visibility tracks | IMPLEMENTATION | ANM-009 | - | - | COMPLETED | `docs/implementation/handoffs/ANM-010_HANDOFF.md` | `docs/implementation/evidence/ANM-010/` | REQ-ANM-010 | ANM-011 | 2026-08-05 | 2026-08-05 |
| ANM-011 | Implement animatable z-order | IMPLEMENTATION | ANM-010 | - | - | COMPLETED | `docs/implementation/handoffs/ANM-011_HANDOFF.md` | `docs/implementation/evidence/ANM-011/` | REQ-ANM-011 | ANM-012 | 2026-08-05 | 2026-08-05 |
| ANM-012 | Implement playback and looping | IMPLEMENTATION | ANM-011 | - | - | COMPLETED | `docs/implementation/handoffs/ANM-012_HANDOFF.md` | `docs/implementation/evidence/ANM-012/` | REQ-ANM-012 | ANM-013 | 2026-08-05 | 2026-08-05 |
| ANM-013 | Implement markers and regions | IMPLEMENTATION | ANM-012 | - | - | COMPLETED | `docs/implementation/handoffs/ANM-013_HANDOFF.md` | `docs/implementation/evidence/ANM-013/` | REQ-ANM-013 | ANM-014 | 2026-08-05 | 2026-08-05 |
| ANM-014 | Implement timeline persistence | IMPLEMENTATION | ANM-013 | - | - | COMPLETED | `docs/implementation/handoffs/ANM-014_HANDOFF.md` | `docs/implementation/evidence/ANM-014/` | REQ-ANM-014 | QA-ANM-001 | 2026-08-05 | 2026-08-05 |
| QA-ANM-001 | Verify timeline behavior end-to-end | VERIFICATION | ANM-001 through ANM-014 | - | - | COMPLETED | `docs/implementation/handoffs/QA-ANM-001_HANDOFF.md` | `docs/implementation/evidence/QA-ANM-001/` | REQ-ANM-001 through REQ-ANM-014 | CRV-001 | 2026-08-05 | 2026-08-05 |

### Milestone 8 — Curves and Onion Skinning

| Task ID | Title | Thread Type | Dependencies | Branch | Commit | Status | Handoff Path | Evidence Path | Requirement IDs | Recommended Next | Assigned | Completed |
|---------|-------|-------------|--------------|--------|--------|--------|--------------|---------------|-----------------|-----------------|----------|-----------|
| CRV-001 | Stepped & linear interpolation | IMPLEMENTATION | QA-ANM-001 | - | - | COMPLETED | `docs/implementation/handoffs/MILESTONE_7_TO_9_HANDOFF.md` | `docs/implementation/evidence/CRV-001/` | REQ-CRV-001 | CRV-002 | 2026-08-05 | 2026-08-05 |
| CRV-002 | Smooth & cubic interpolation | IMPLEMENTATION | CRV-001 | - | - | COMPLETED | `docs/implementation/handoffs/MILESTONE_7_TO_9_HANDOFF.md` | `docs/implementation/evidence/CRV-002/` | REQ-CRV-002 | CRV-003 | 2026-08-05 | 2026-08-05 |
| CRV-003 | Bézier curves | IMPLEMENTATION | CRV-002 | - | - | COMPLETED | `docs/implementation/handoffs/MILESTONE_7_TO_9_HANDOFF.md` | `docs/implementation/evidence/CRV-003/` | REQ-CRV-003 | CRV-004 | 2026-08-05 | 2026-08-05 |
| CRV-004 | Angle interpolation controls | IMPLEMENTATION | CRV-003 | - | - | COMPLETED | `docs/implementation/handoffs/MILESTONE_7_TO_9_HANDOFF.md` | `docs/implementation/evidence/CRV-004/` | REQ-CRV-004 | CRV-005 | 2026-08-05 | 2026-08-05 |
| CRV-005 | Curve editor model | IMPLEMENTATION | CRV-004 | - | - | COMPLETED | `docs/implementation/handoffs/MILESTONE_7_TO_9_HANDOFF.md` | `docs/implementation/evidence/CRV-005/` | REQ-CRV-005 | CRV-006 | 2026-08-05 | 2026-08-05 |
| CRV-006 | Curve presets | IMPLEMENTATION | CRV-005 | - | - | COMPLETED | `docs/implementation/handoffs/MILESTONE_7_TO_9_HANDOFF.md` | `docs/implementation/evidence/CRV-006/` | REQ-CRV-006 | CRV-007 | 2026-08-05 | 2026-08-05 |
| CRV-007 | Curve bake & simplification | IMPLEMENTATION | CRV-006 | - | - | COMPLETED | `docs/implementation/handoffs/MILESTONE_7_TO_9_HANDOFF.md` | `docs/implementation/evidence/CRV-007/` | REQ-CRV-007 | ONI-001 | 2026-08-05 | 2026-08-05 |
| ONI-001 | Adjacent-frame onion skins | IMPLEMENTATION | CRV-007 | - | - | COMPLETED | `docs/implementation/handoffs/MILESTONE_7_TO_9_HANDOFF.md` | `docs/implementation/evidence/ONI-001/` | REQ-ONI-001 | ONI-002 | 2026-08-05 | 2026-08-05 |
| ONI-002 | Key & pinned onion skins | IMPLEMENTATION | ONI-001 | - | - | COMPLETED | `docs/implementation/handoffs/MILESTONE_7_TO_9_HANDOFF.md` | `docs/implementation/evidence/ONI-002/` | REQ-ONI-002 | ONI-003 | 2026-08-05 | 2026-08-05 |
| ONI-003 | Interactive onion editing | IMPLEMENTATION | ONI-002 | - | - | COMPLETED | `docs/implementation/handoffs/MILESTONE_7_TO_9_HANDOFF.md` | `docs/implementation/evidence/ONI-003/` | REQ-ONI-003 | ONI-004 | 2026-08-05 | 2026-08-05 |
| ONI-004 | Obstruction cycling / style | IMPLEMENTATION | ONI-003 | - | - | COMPLETED | `docs/implementation/handoffs/MILESTONE_7_TO_9_HANDOFF.md` | `docs/implementation/evidence/ONI-004/` | REQ-ONI-004 | QA-CRV-001 | 2026-08-05 | 2026-08-05 |
| QA-CRV-001 | Verify curves and onion skins | VERIFICATION | CRV-001 through ONI-004 | - | - | COMPLETED | `docs/implementation/handoffs/MILESTONE_7_TO_9_HANDOFF.md` | `docs/implementation/evidence/QA-CRV-001/` | REQ-CRV-001 through REQ-ONI-004 | MSH-001 | 2026-08-05 | 2026-08-05 |

### Milestone 9 — Mesh and Deformation Studio

| Task ID | Title | Thread Type | Dependencies | Branch | Commit | Status | Handoff Path | Evidence Path | Requirement IDs | Recommended Next | Assigned | Completed |
|---------|-------|-------------|--------------|--------|--------|--------|--------------|---------------|-----------------|-----------------|----------|-----------|
| MSH-001 | Mesh & weight schemas | IMPLEMENTATION | QA-CRV-001 | - | - | COMPLETED | `docs/implementation/handoffs/MILESTONE_7_TO_9_HANDOFF.md` | `docs/implementation/evidence/MSH-001/` | REQ-MSH-001 | MSH-002 | 2026-08-05 | 2026-08-05 |
| MSH-002 | Automatic mesh generation | IMPLEMENTATION | MSH-001 | - | - | COMPLETED | `docs/implementation/handoffs/MILESTONE_7_TO_9_HANDOFF.md` | `docs/implementation/evidence/MSH-002/` | REQ-MSH-002 | MSH-003 | 2026-08-05 | 2026-08-05 |
| MSH-003 | Manual mesh editing | IMPLEMENTATION | MSH-002 | - | - | COMPLETED | `docs/implementation/handoffs/MILESTONE_7_TO_9_HANDOFF.md` | `docs/implementation/evidence/MSH-003/` | REQ-MSH-003 | MSH-004 | 2026-08-05 | 2026-08-05 |
| MSH-004 | UV editing | IMPLEMENTATION | MSH-003 | - | - | COMPLETED | `docs/implementation/handoffs/MILESTONE_7_TO_9_HANDOFF.md` | `docs/implementation/evidence/MSH-004/` | REQ-MSH-004 | MSH-005 | 2026-08-05 | 2026-08-05 |
| MSH-005 | Bone binding | IMPLEMENTATION | MSH-004 | - | - | COMPLETED | `docs/implementation/handoffs/MILESTONE_7_TO_9_HANDOFF.md` | `docs/implementation/evidence/MSH-005/` | REQ-MSH-005 | MSH-006 | 2026-08-05 | 2026-08-05 |
| MSH-006 | Weight painting | IMPLEMENTATION | MSH-005 | - | - | COMPLETED | `docs/implementation/handoffs/MILESTONE_7_TO_9_HANDOFF.md` | `docs/implementation/evidence/MSH-006/` | REQ-MSH-006 | MSH-007 | 2026-08-05 | 2026-08-05 |
| MSH-007 | Normalization & mirroring | IMPLEMENTATION | MSH-006 | - | - | COMPLETED | `docs/implementation/handoffs/MILESTONE_7_TO_9_HANDOFF.md` | `docs/implementation/evidence/MSH-007/` | REQ-MSH-007 | MSH-008 | 2026-08-05 | 2026-08-05 |
| MSH-008 | Extreme-pose preview | IMPLEMENTATION | MSH-007 | - | - | COMPLETED | `docs/implementation/handoffs/MILESTONE_7_TO_9_HANDOFF.md` | `docs/implementation/evidence/MSH-008/` | REQ-MSH-008 | DEF-001 | 2026-08-05 | 2026-08-05 |
| DEF-001 | Deformation handles | IMPLEMENTATION | MSH-008 | - | - | COMPLETED | `docs/implementation/handoffs/MILESTONE_7_TO_9_HANDOFF.md` | `docs/implementation/evidence/DEF-001/` | REQ-DEF-001 | DEF-002 | 2026-08-05 | 2026-08-05 |
| DEF-002 | Attractor solver | IMPLEMENTATION | DEF-001 | - | - | COMPLETED | `docs/implementation/handoffs/MILESTONE_7_TO_9_HANDOFF.md` | `docs/implementation/evidence/DEF-002/` | REQ-DEF-002 | DEF-003 | 2026-08-05 | 2026-08-05 |
| DEF-003 | Soft drag | IMPLEMENTATION | DEF-002 | - | - | COMPLETED | `docs/implementation/handoffs/MILESTONE_7_TO_9_HANDOFF.md` | `docs/implementation/evidence/DEF-003/` | REQ-DEF-003 | DEF-004 | 2026-08-05 | 2026-08-05 |
| DEF-004 | Animatable deformation | IMPLEMENTATION | DEF-003 | - | - | COMPLETED | `docs/implementation/handoffs/MILESTONE_7_TO_9_HANDOFF.md` | `docs/implementation/evidence/DEF-004/` | REQ-DEF-004 | DEF-005 | 2026-08-05 | 2026-08-05 |
| DEF-005 | Bake deformation | IMPLEMENTATION | DEF-004 | - | - | COMPLETED | `docs/implementation/handoffs/MILESTONE_7_TO_9_HANDOFF.md` | `docs/implementation/evidence/DEF-005/` | REQ-DEF-005 | DEF-006 | 2026-08-05 | 2026-08-05 |
| DEF-006 | Deformation validator | IMPLEMENTATION | DEF-005 | - | - | COMPLETED | `docs/implementation/handoffs/MILESTONE_7_TO_9_HANDOFF.md` | `docs/implementation/evidence/DEF-006/` | REQ-DEF-006 | QA-DEF-001 | 2026-08-05 | 2026-08-05 |
| QA-DEF-001 | Verify deformation quality | VERIFICATION | MSH-001 through DEF-006 | - | - | COMPLETED | `docs/implementation/handoffs/MILESTONE_7_TO_9_HANDOFF.md` | `docs/implementation/evidence/QA-DEF-001/` | REQ-MSH-001 through REQ-DEF-006 | - | 2026-08-05 | 2026-08-05 |

---

### Milestone 10 — Weapon & Equipment Posing Studio

| Task ID | Title | Thread Type | Dependencies | Branch | Commit | Status | Handoff Path | Evidence Path | Requirement IDs | Recommended Next | Assigned | Completed |
|---------|-------|-------------|--------------|--------|--------|--------|--------------|---------------|-----------------|-----------------|----------|-----------|
| WPN-001 | Define weapon, grip, pose-profile, and hand-pose schemas | IMPLEMENTATION | QA-DEF-001 | - | - | COMPLETED | `docs/implementation/handoffs/WPN_META_001_HANDOFF.md` | `docs/implementation/evidence/WPN-META-001/` | REQ-WPN-001 | WPN-002 | 2026-08-05 | 2026-08-05 |
| WPN-002 | Implement interaction-family registry | IMPLEMENTATION | WPN-001 | - | - | COMPLETED | `docs/implementation/handoffs/WPN_META_001_HANDOFF.md` | `docs/implementation/evidence/WPN-META-001/` | REQ-WPN-002 | WPN-003 | 2026-08-05 | 2026-08-05 |
| WPN-003 | Implement weapon asset and pose-profile registry | IMPLEMENTATION | WPN-002 | - | - | COMPLETED | `docs/implementation/handoffs/WPN_META_001_HANDOFF.md` | `docs/implementation/evidence/WPN-META-001/` | REQ-WPN-003 | WPN-004 | 2026-08-05 | 2026-08-05 |
| WPN-004 | Implement grip authoring editor model | IMPLEMENTATION | WPN-003 | - | - | COMPLETED | `docs/implementation/handoffs/WPN_META_001_HANDOFF.md` | `docs/implementation/evidence/WPN-META-001/` | REQ-WPN-004 | WPN-005 | 2026-08-05 | 2026-08-05 |
| WPN-005 | Support named weapon gameplay and equipment points | IMPLEMENTATION | WPN-004 | - | - | COMPLETED | `docs/implementation/handoffs/WPN_META_001_HANDOFF.md` | `docs/implementation/evidence/WPN-META-001/` | REQ-WPN-005 | WPN-006 | 2026-08-05 | 2026-08-05 |
| WPN-006 | Implement dual-grip hand attachment binding | IMPLEMENTATION | WPN-005 | - | - | COMPLETED | `docs/implementation/handoffs/WPN_META_001_HANDOFF.md` | `docs/implementation/evidence/WPN-META-001/` | REQ-WPN-006 | WPN-007 | 2026-08-05 | 2026-08-05 |
| WPN-007 | Implement reusable hand-pose library | IMPLEMENTATION | WPN-006 | - | - | COMPLETED | `docs/implementation/handoffs/WPN_META_001_HANDOFF.md` | `docs/implementation/evidence/WPN-META-001/` | REQ-WPN-007 | WPN-008 | 2026-08-05 | 2026-08-05 |
| WPN-008 | Implement posing editor and arm/wrist alignment | IMPLEMENTATION | WPN-007 | - | - | COMPLETED | `docs/implementation/handoffs/WPN_META_001_HANDOFF.md` | `docs/implementation/evidence/WPN-META-001/` | REQ-WPN-008 | META-001 | 2026-08-05 | 2026-08-05 |

### Milestone 11 — Gameplay Metadata & Events

| Task ID | Title | Thread Type | Dependencies | Branch | Commit | Status | Handoff Path | Evidence Path | Requirement IDs | Recommended Next | Assigned | Completed |
|---------|-------|-------------|--------------|--------|--------|--------|--------------|---------------|-----------------|-----------------|----------|-----------|
| META-001 | Implement keyframeable action-point tracks | IMPLEMENTATION | WPN-008 | - | - | COMPLETED | `docs/implementation/handoffs/WPN_META_001_HANDOFF.md` | `docs/implementation/evidence/WPN-META-001/` | REQ-META-001 | META-002 | 2026-08-05 | 2026-08-05 |
| META-002 | Implement animation event tracks | IMPLEMENTATION | META-001 | - | - | COMPLETED | `docs/implementation/handoffs/WPN_META_001_HANDOFF.md` | `docs/implementation/evidence/WPN-META-001/` | REQ-META-002 | META-003 | 2026-08-05 | 2026-08-05 |
| META-003 | Implement tags, variables, and script parameter tracks | IMPLEMENTATION | META-002 | - | - | COMPLETED | `docs/implementation/handoffs/WPN_META_001_HANDOFF.md` | `docs/implementation/evidence/WPN-META-001/` | REQ-META-003 | META-004 | 2026-08-05 | 2026-08-05 |
| META-004 | Implement hitbox tracks | IMPLEMENTATION | META-003 | - | - | COMPLETED | `docs/implementation/handoffs/WPN_META_001_HANDOFF.md` | `docs/implementation/evidence/WPN-META-001/` | REQ-META-004 | META-005 | 2026-08-05 | 2026-08-05 |
| META-005 | Implement hurtbox tracks | IMPLEMENTATION | META-004 | - | - | COMPLETED | `docs/implementation/handoffs/WPN_META_001_HANDOFF.md` | `docs/implementation/evidence/WPN-META-001/` | REQ-META-005 | META-006 | 2026-08-05 | 2026-08-05 |
| META-006 | Implement collision shapes, audio cues, and viseme tracks | IMPLEMENTATION | META-005 | - | - | COMPLETED | `docs/implementation/handoffs/WPN_META_001_HANDOFF.md` | `docs/implementation/evidence/WPN-META-001/` | REQ-META-006 | QA-WPN-META-001 | 2026-08-05 | 2026-08-05 |

### Milestone 12 — Facing Grids & Animation State Rules

| Task ID | Title | Thread Type | Dependencies | Branch | Commit | Status | Handoff Path | Evidence Path | Requirement IDs | Recommended Next | Assigned | Completed |
|---------|-------|-------------|--------------|--------|--------|--------|--------------|---------------|-----------------|-----------------|----------|-----------|
| GRID-001 | Define directional facing-grid schema | IMPLEMENTATION | META-006 | - | - | COMPLETED | `docs/implementation/handoffs/MILESTONE_12_TO_14_HANDOFF.md` | `docs/implementation/evidence/MILESTONE_12_TO_14/` | REQ-GRID-001 | GRID-002 | 2026-08-05 | 2026-08-05 |
| GRID-002 | Implement 4-way and 8-way direction selection | IMPLEMENTATION | GRID-001 | - | - | COMPLETED | `docs/implementation/handoffs/MILESTONE_12_TO_14_HANDOFF.md` | `docs/implementation/evidence/MILESTONE_12_TO_14/` | REQ-GRID-002 | GRID-003 | 2026-08-05 | 2026-08-05 |
| GRID-003 | Implement directional mirroring and slot swaps | IMPLEMENTATION | GRID-002 | - | - | COMPLETED | `docs/implementation/handoffs/MILESTONE_12_TO_14_HANDOFF.md` | `docs/implementation/evidence/MILESTONE_12_TO_14/` | REQ-GRID-003 | GRID-004 | 2026-08-05 | 2026-08-05 |
| GRID-004 | Implement sprite crossfade and pixel-mode rules | IMPLEMENTATION | GRID-003 | - | - | COMPLETED | `docs/implementation/handoffs/MILESTONE_12_TO_14_HANDOFF.md` | `docs/implementation/evidence/MILESTONE_12_TO_14/` | REQ-GRID-004 | GRID-005 | 2026-08-05 | 2026-08-05 |
| GRID-005 | Implement neighboring mesh interpolation | IMPLEMENTATION | GRID-004 | - | - | COMPLETED | `docs/implementation/handoffs/MILESTONE_12_TO_14_HANDOFF.md` | `docs/implementation/evidence/MILESTONE_12_TO_14/` | REQ-GRID-005 | GRID-006 | 2026-08-05 | 2026-08-05 |
| GRID-006 | Implement facing validation and persistence | IMPLEMENTATION | GRID-005 | - | - | COMPLETED | `docs/implementation/handoffs/MILESTONE_12_TO_14_HANDOFF.md` | `docs/implementation/evidence/MILESTONE_12_TO_14/` | REQ-GRID-006 | EXP-001 | 2026-08-05 | 2026-08-05 |

### Milestone 13 — Export Engine

| Task ID | Title | Thread Type | Dependencies | Branch | Commit | Status | Handoff Path | Evidence Path | Requirement IDs | Recommended Next | Assigned | Completed |
|---------|-------|-------------|--------------|--------|--------|--------|--------------|---------------|-----------------|-----------------|----------|-----------|
| EXP-001 | Define and serialize runtime package format | IMPLEMENTATION | GRID-006 | - | - | COMPLETED | `docs/implementation/handoffs/MILESTONE_12_TO_14_HANDOFF.md` | `docs/implementation/evidence/MILESTONE_12_TO_14/` | REQ-EXP-001 | EXP-002 | 2026-08-05 | 2026-08-05 |
| EXP-002 | Implement packed atlas exporter | IMPLEMENTATION | EXP-001 | - | - | COMPLETED | `docs/implementation/handoffs/MILESTONE_12_TO_14_HANDOFF.md` | `docs/implementation/evidence/MILESTONE_12_TO_14/` | REQ-EXP-002 | EXP-003 | 2026-08-05 | 2026-08-05 |
| EXP-003 | Implement PNG/WebP image-sequence exporter | IMPLEMENTATION | EXP-002 | - | - | COMPLETED | `docs/implementation/handoffs/MILESTONE_12_TO_14_HANDOFF.md` | `docs/implementation/evidence/MILESTONE_12_TO_14/` | REQ-EXP-003 | EXP-004 | 2026-08-05 | 2026-08-05 |
| EXP-004 | Implement spritesheet and JSON/XML manifests | IMPLEMENTATION | EXP-003 | - | - | COMPLETED | `docs/implementation/handoffs/MILESTONE_12_TO_14_HANDOFF.md` | `docs/implementation/evidence/MILESTONE_12_TO_14/` | REQ-EXP-004 | EXP-005 | 2026-08-05 | 2026-08-05 |
| EXP-005 | Implement animated GIF encoder | IMPLEMENTATION | EXP-004 | - | - | COMPLETED | `docs/implementation/handoffs/MILESTONE_12_TO_14_HANDOFF.md` | `docs/implementation/evidence/MILESTONE_12_TO_14/` | REQ-EXP-005 | EXP-006 | 2026-08-05 | 2026-08-05 |
| EXP-006 | Implement MP4/WebM ffmpeg pipeline | IMPLEMENTATION | EXP-005 | - | - | COMPLETED | `docs/implementation/handoffs/MILESTONE_12_TO_14_HANDOFF.md` | `docs/implementation/evidence/MILESTONE_12_TO_14/` | REQ-EXP-006 | EXP-007 | 2026-08-05 | 2026-08-05 |
| EXP-007 | Implement trim, padding, and extrusion | IMPLEMENTATION | EXP-006 | - | - | COMPLETED | `docs/implementation/handoffs/MILESTONE_12_TO_14_HANDOFF.md` | `docs/implementation/evidence/MILESTONE_12_TO_14/` | REQ-EXP-007 | EXP-008 | 2026-08-05 | 2026-08-05 |
| EXP-008 | Implement native Godot resource export | IMPLEMENTATION | EXP-007 | - | - | COMPLETED | `docs/implementation/handoffs/MILESTONE_12_TO_14_HANDOFF.md` | `docs/implementation/evidence/MILESTONE_12_TO_14/` | REQ-EXP-008 | RNT-001 | 2026-08-05 | 2026-08-05 |

### Milestone 14 — Native Godot Runtime Plugin

| Task ID | Title | Thread Type | Dependencies | Branch | Commit | Status | Handoff Path | Evidence Path | Requirement IDs | Recommended Next | Assigned | Completed |
|---------|-------|-------------|--------------|--------|--------|--------|--------------|---------------|-----------------|-----------------|----------|-----------|
| RNT-001 | Implement `.chrproj` importer and editor import hook | IMPLEMENTATION | EXP-008 | - | - | COMPLETED | `docs/implementation/handoffs/MILESTONE_12_TO_14_HANDOFF.md` | `docs/implementation/evidence/MILESTONE_12_TO_14/` | REQ-RNT-001 | RNT-002 | 2026-08-05 | 2026-08-05 |
| RNT-002 | Implement native runtime data resource | IMPLEMENTATION | RNT-001 | - | - | COMPLETED | `docs/implementation/handoffs/MILESTONE_12_TO_14_HANDOFF.md` | `docs/implementation/evidence/MILESTONE_12_TO_14/` | REQ-RNT-002 | RNT-003 | 2026-08-05 | 2026-08-05 |
| RNT-003 | Implement `CharacterPlayer2D` playback API | IMPLEMENTATION | RNT-002 | - | - | COMPLETED | `docs/implementation/handoffs/MILESTONE_12_TO_14_HANDOFF.md` | `docs/implementation/evidence/MILESTONE_12_TO_14/` | REQ-RNT-003 | RNT-004 | 2026-08-05 | 2026-08-05 |
| RNT-004 | Implement Skeleton2D, GPU Polygon2D, and two-bone IK runtime | IMPLEMENTATION | RNT-003 | - | - | COMPLETED | `docs/implementation/handoffs/MILESTONE_12_TO_14_HANDOFF.md` | `docs/implementation/evidence/MILESTONE_12_TO_14/` | REQ-RNT-004 | RNT-005 | 2026-08-05 | 2026-08-05 |
| RNT-005 | Implement facing, state-machine, and rule runtime evaluation | IMPLEMENTATION | RNT-004 | - | - | COMPLETED | `docs/implementation/handoffs/MILESTONE_12_TO_14_HANDOFF.md` | `docs/implementation/evidence/MILESTONE_12_TO_14/` | REQ-RNT-005 | RNT-006 | 2026-08-05 | 2026-08-05 |
| RNT-006 | Implement equipment swaps and event delivery | IMPLEMENTATION | RNT-005 | - | - | COMPLETED | `docs/implementation/handoffs/MILESTONE_12_TO_14_HANDOFF.md` | `docs/implementation/evidence/MILESTONE_12_TO_14/` | REQ-RNT-006 | QA-RNT-001 | 2026-08-05 | 2026-08-05 |

---

### Completion Plan — Reconciliation and Phase 0 Verification

| Task ID | Title | Thread Type | Dependencies | Branch | Commit | Status | Handoff Path | Evidence Path | Requirement IDs | Recommended Next | Assigned | Completed |
|---------|-------|-------------|--------------|--------|--------|--------|--------------|---------------|-----------------|-----------------|----------|-----------|
| REC-PLAN-001 | Reconcile master-plan tasks and establish clean-consumer fixture | IMPLEMENTATION | RNT-006 | - | - | COMPLETED | `docs/implementation/handoffs/REC-PLAN-001_HANDOFF.md` | `docs/implementation/evidence/REC-PLAN-001/` | REQ-GOV-002, REQ-GOV-003, REQ-CAN-006, REQ-RIG-009, REQ-EXP-008, REQ-RNT-002, REQ-RNT-003 | QA-GRID-001 | 2026-08-05 | 2026-08-05 |
| QA-WPN-META-001 | Independently verify legacy weapon and gameplay-metadata work | VERIFICATION | WPN-001 through META-006 | - | - | COMPLETED | `docs/implementation/handoffs/QA-WPN-META-001_HANDOFF.md` | `docs/implementation/evidence/QA-WPN-META-001/` | REQ-WPN-001 through REQ-META-006 | QA-FAC-001 | 2026-08-05 | 2026-08-05 |
| QA-GRID-001 | Independently verify legacy facing-grid core | VERIFICATION | GRID-001 through GRID-006 | - | - | COMPLETED | `docs/implementation/handoffs/QA-GRID-001_HANDOFF.md` | `docs/implementation/evidence/QA-GRID-001/` | REQ-GRID-001 through REQ-GRID-006 | QA-WPN-META-001 | 2026-08-05 | 2026-08-05 |
| QA-EXP-001 | Independently verify legacy export artifacts | VERIFICATION | EXP-001 through EXP-008, REC-PLAN-001 | - | - | COMPLETED | `docs/implementation/handoffs/QA-EXP-001_HANDOFF.md` | `docs/implementation/evidence/QA-EXP-001/` | REQ-EXP-001 through REQ-EXP-008 | QA-GRID-001 | 2026-08-05 | 2026-08-05 |
| QA-RNT-001 | Independently verify legacy runtime/import behavior | VERIFICATION | RNT-001 through RNT-006, REC-PLAN-001, RPR-RNT-001 | - | - | COMPLETED | `docs/implementation/handoffs/QA-RNT-001_HANDOFF.md` | `docs/implementation/evidence/QA-RNT-001/` | REQ-RNT-001 through REQ-RNT-006 | QA-EXP-001 | 2026-08-05 | 2026-08-05 |
| RPR-RNT-001 | Make the distributable runtime import plugin self-contained | REPAIR | RNT-006, REC-PLAN-001 | - | - | COMPLETED | `docs/implementation/handoffs/RPR-RNT-001_HANDOFF.md` | `docs/implementation/evidence/RPR-RNT-001/` | REQ-RNT-001, REQ-RNT-002 | QA-RNT-001 | 2026-08-05 | 2026-08-05 |
| QA-FAC-001 | Review authoritative facing-grid authoring parity | VERIFICATION | QA-GRID-001, FAC-002 through FAC-012 | - | - | COMPLETED | `docs/implementation/handoffs/QA-FAC-001_HANDOFF.md` | `docs/implementation/evidence/QA-FAC-001/` | REQ-FAC-002 through REQ-FAC-012 | POS-001 | 2026-08-06 | 2026-08-06 |
| QA-RUL-001 | Review blending, state-machine, and rule parity | VERIFICATION | QA-GRID-001 | - | - | COMPLETED | `docs/implementation/handoffs/QA-COMPLETION-001_HANDOFF.md` | `docs/implementation/evidence/QA-COMPLETION-001/` | BLD-001 through RUL-005 | QA-LNK-001 | 2026-08-06 | 2026-08-06 |
| QA-GDT-001 | Verify the authoritative clean-consumer Godot round trip | VERIFICATION | QA-EXP-001, QA-RNT-001 | - | - | COMPLETED | `docs/implementation/handoffs/QA-COMPLETION-001_HANDOFF.md` | `docs/implementation/evidence/QA-COMPLETION-001/` | GDT-001 through GDT-014 | QA-PRF-001 | 2026-08-06 | 2026-08-06 |

### Completion Plan — Phase 1 Facing-Grid Authoring

| Task ID | Title | Thread Type | Dependencies | Branch | Commit | Status | Handoff Path | Evidence Path | Requirement IDs | Recommended Next | Assigned | Completed |
|---------|-------|-------------|--------------|--------|--------|--------|--------------|---------------|-----------------|-----------------|----------|-----------|
| FAC-002 | Implement the direction-set editor | IMPLEMENTATION | QA-GRID-001 | - | - | COMPLETED | `docs/implementation/handoffs/FAC-002_HANDOFF.md` | `docs/implementation/evidence/FAC-002/` | REQ-FAC-002 | FAC-003 | 2026-08-05 | 2026-08-05 |
| FAC-003 | Implement selected-cell asset assignment | IMPLEMENTATION | FAC-002 | - | - | COMPLETED | `docs/implementation/handoffs/FAC-003_HANDOFF.md` | `docs/implementation/evidence/FAC-003/` | REQ-FAC-003 | FAC-004 | 2026-08-05 | 2026-08-05 |
| FAC-004 | Implement filename-based batch placement | IMPLEMENTATION | FAC-003 | - | - | COMPLETED | `docs/implementation/handoffs/FAC-004_HANDOFF.md` | `docs/implementation/evidence/FAC-004/` | REQ-FAC-004 | FAC-005 | 2026-08-05 | 2026-08-05 |
| FAC-005 | Implement left/right slot swapping | IMPLEMENTATION | FAC-004 | - | - | COMPLETED | `docs/implementation/handoffs/FAC-005_HANDOFF.md` | `docs/implementation/evidence/FAC-005/` | REQ-FAC-005 | FAC-006 | 2026-08-05 | 2026-08-05 |
| FAC-006 | Implement directional cell mirroring | IMPLEMENTATION | FAC-005 | - | - | COMPLETED | `docs/implementation/handoffs/FAC-006_HANDOFF.md` | `docs/implementation/evidence/FAC-006/` | REQ-FAC-006 | FAC-007 | 2026-08-05 | 2026-08-05 |
| FAC-007 | Implement hard direction switching controls | IMPLEMENTATION | FAC-006 | - | - | COMPLETED | `docs/implementation/handoffs/FAC-007_HANDOFF.md` | `docs/implementation/evidence/FAC-007/` | REQ-FAC-007 | FAC-008 | 2026-08-05 | 2026-08-06 |
| FAC-008 | Implement optional sprite crossfade controls | IMPLEMENTATION | FAC-007 | - | - | COMPLETED | `docs/implementation/handoffs/FAC-008_HANDOFF.md` | `docs/implementation/evidence/FAC-008/` | REQ-FAC-008 | FAC-009 | 2026-08-06 | 2026-08-06 |
| FAC-009 | Implement deformable-mesh direction blending | IMPLEMENTATION | FAC-008 | - | - | COMPLETED | `docs/implementation/handoffs/FAC-009_HANDOFF.md` | `docs/implementation/evidence/FAC-009/` | REQ-FAC-009 | FAC-010 | 2026-08-06 | 2026-08-06 |
| FAC-010 | Implement direction-scrub preview | IMPLEMENTATION | FAC-009 | - | - | COMPLETED | `docs/implementation/handoffs/FAC-010_HANDOFF.md` | `docs/implementation/evidence/FAC-010/` | REQ-FAC-010 | FAC-011 | 2026-08-06 | 2026-08-06 |
| FAC-011 | Implement missing-cell diagnostics | IMPLEMENTATION | FAC-010 | - | - | COMPLETED | `docs/implementation/handoffs/FAC-011_HANDOFF.md` | `docs/implementation/evidence/FAC-011/` | REQ-FAC-011 | FAC-012 | 2026-08-06 | 2026-08-06 |
| FAC-012 | Implement pixel no-crossfade mode | IMPLEMENTATION | FAC-011 | - | - | COMPLETED | `docs/implementation/handoffs/FAC-012_HANDOFF.md` | `docs/implementation/evidence/FAC-012/` | REQ-FAC-012 | QA-FAC-001 | 2026-08-06 | 2026-08-06 |

### Completion Plan — Phase 1 Pose and Retargeting Authoring

| Task ID | Title | Thread Type | Dependencies | Branch | Commit | Status | Handoff Path | Evidence Path | Requirement IDs | Recommended Next | Assigned | Completed |
|---------|-------|-------------|--------------|--------|--------|--------|--------------|---------------|-----------------|-----------------|----------|-----------|
| POS-001 | Define pose schema | IMPLEMENTATION | QA-FAC-001 | - | - | COMPLETED | `docs/implementation/handoffs/POS-001_HANDOFF.md` | `docs/implementation/evidence/POS-001/` | REQ-POS-001 | POS-002 | 2026-08-06 | 2026-08-06 |
| POS-002 | Implement save/apply pose | IMPLEMENTATION | POS-001 | - | - | COMPLETED | `docs/implementation/handoffs/POS-002_HANDOFF.md` | `docs/implementation/evidence/POS-002/` | REQ-POS-002 | POS-003 | 2026-08-06 | 2026-08-06 |
| POS-003 | Implement mirror pose | IMPLEMENTATION | POS-002 | - | - | COMPLETED | `docs/implementation/handoffs/POS-003_HANDOFF.md` | `docs/implementation/evidence/POS-003/` | REQ-POS-003 | POS-004 | 2026-08-06 | 2026-08-06 |
| POS-004 | Implement pose blending | IMPLEMENTATION | POS-003 | - | - | COMPLETED | `docs/implementation/handoffs/POS-004_HANDOFF.md` | `docs/implementation/evidence/POS-004/` | REQ-POS-004 | POS-005 | 2026-08-06 | 2026-08-06 |
| POS-005 | Implement additive poses | IMPLEMENTATION | POS-004 | - | - | COMPLETED | `docs/implementation/handoffs/POS-005_HANDOFF.md` | `docs/implementation/evidence/POS-005/` | REQ-POS-005 | POS-006 | 2026-08-06 | 2026-08-06 |
| POS-006 | Implement pose thumbnails | IMPLEMENTATION | POS-005 | - | - | COMPLETED | `docs/implementation/handoffs/POS-006_HANDOFF.md` | `docs/implementation/evidence/POS-006/` | REQ-POS-006 | POS-007 | 2026-08-06 | 2026-08-06 |
| POS-007 | Implement sketch-to-pose assistance | IMPLEMENTATION | POS-006 | - | - | COMPLETED | `docs/implementation/handoffs/POS-007_HANDOFF.md` | `docs/implementation/evidence/POS-007/` | REQ-POS-007 | RET-001 | 2026-08-06 | 2026-08-06 |
| RET-001 | Define skeleton profiles | IMPLEMENTATION | POS-007 | - | - | COMPLETED | `docs/implementation/handoffs/RET-001_HANDOFF.md` | `docs/implementation/evidence/RET-001/` | REQ-RET-001 | RET-002 | 2026-08-06 | 2026-08-06 |
| RET-002 | Implement bone mapping | IMPLEMENTATION | RET-001 | - | - | COMPLETED | `docs/implementation/handoffs/RET-002_HANDOFF.md` | `docs/implementation/evidence/RET-002/` | REQ-RET-002 | RET-003 | 2026-08-06 | 2026-08-06 |
| RET-003 | Implement proportion compensation | IMPLEMENTATION | RET-002 | - | - | COMPLETED | `docs/implementation/handoffs/RET-003_HANDOFF.md` | `docs/implementation/evidence/RET-003/` | REQ-RET-003 | RET-004 | 2026-08-06 | 2026-08-06 |
| RET-004 | Implement preview | IMPLEMENTATION | RET-003 | - | - | COMPLETED | `docs/implementation/handoffs/RET-004_HANDOFF.md` | `docs/implementation/evidence/RET-004/` | REQ-RET-004 | RET-005 | 2026-08-06 | 2026-08-06 |
| RET-005 | Implement batch retarget | IMPLEMENTATION | RET-004 | - | - | COMPLETED | `docs/implementation/handoffs/RET-005_HANDOFF.md` | `docs/implementation/evidence/RET-005/` | REQ-RET-005 | RET-006 | 2026-08-06 | 2026-08-06 |
| RET-006 | Implement correction layers | IMPLEMENTATION | RET-005 | - | - | COMPLETED | `docs/implementation/handoffs/RET-006_HANDOFF.md` | `docs/implementation/evidence/RET-006/` | REQ-RET-006 | QA-POS-001 | 2026-08-06 | 2026-08-06 |
| QA-POS-001 | Verify pose and retarget workflows | VERIFICATION | POS-001 through POS-007, RET-001 through RET-006 | - | - | COMPLETED | `docs/implementation/handoffs/QA-POS-001_HANDOFF.md` | `docs/implementation/evidence/QA-POS-001/` | REQ-POS-001 through REQ-POS-007, REQ-RET-001 through REQ-RET-006 | Phase 2 | 2026-08-06 | 2026-08-06 |

### Completion Plan — Phase 2 Weapons, Arm Solving, and Equipment Authoring

The historic `WPN-008` row remains the legacy posing-editor task. The
`*-DRIVE` rows below are the authoritative master-plan drive-mode work; the
mapping is documented in `MASTER_PLAN_RECONCILIATION.md`.

| Task ID | Title | Thread Type | Dependencies | Branch | Commit | Status | Handoff Path | Evidence Path | Requirement IDs | Recommended Next | Assigned | Completed |
|---------|-------|-------------|--------------|--------|--------|--------|--------------|---------------|-----------------|-----------------|----------|-----------|
| WPN-008-DRIVE | Implement master primary-hand weapon drive | IMPLEMENTATION | QA-POS-001 | - | - | COMPLETED | `docs/implementation/handoffs/WPN-DRIVE-001_HANDOFF.md` | `docs/implementation/evidence/WPN-DRIVE-001/` | REQ-WPN-DRIVE-008 | WPN-009-DRIVE | 2026-08-06 | 2026-08-06 |
| WPN-009-DRIVE | Implement master controller weapon drive | IMPLEMENTATION | WPN-008-DRIVE | - | - | COMPLETED | `docs/implementation/handoffs/WPN-DRIVE-001_HANDOFF.md` | `docs/implementation/evidence/WPN-DRIVE-001/` | REQ-WPN-DRIVE-009 | WPN-010-DRIVE | 2026-08-06 | 2026-08-06 |
| WPN-010-DRIVE | Implement master body-socket weapon drive | IMPLEMENTATION | WPN-009-DRIVE | - | - | COMPLETED | `docs/implementation/handoffs/WPN-DRIVE-001_HANDOFF.md` | `docs/implementation/evidence/WPN-DRIVE-001/` | REQ-WPN-DRIVE-010 | WPN-011-DRIVE | 2026-08-06 | 2026-08-06 |
| WPN-011-DRIVE | Implement master flexible path weapon drive | IMPLEMENTATION | WPN-010-DRIVE | - | - | COMPLETED | `docs/implementation/handoffs/WPN-DRIVE-001_HANDOFF.md` | `docs/implementation/evidence/WPN-DRIVE-001/` | REQ-WPN-DRIVE-011 | WPN-012-DRIVE | 2026-08-06 | 2026-08-06 |
| WPN-012-DRIVE | Implement master floating/world weapon drive | IMPLEMENTATION | WPN-011-DRIVE | - | - | COMPLETED | `docs/implementation/handoffs/WPN-DRIVE-001_HANDOFF.md` | `docs/implementation/evidence/WPN-DRIVE-001/` | REQ-WPN-DRIVE-012 | WPN-013-DRIVE | 2026-08-06 | 2026-08-06 |
| WPN-013-DRIVE | Implement master custom-plugin weapon drive | IMPLEMENTATION | WPN-012-DRIVE | - | - | COMPLETED | `docs/implementation/handoffs/WPN-DRIVE-001_HANDOFF.md` | `docs/implementation/evidence/WPN-DRIVE-001/` | REQ-WPN-DRIVE-013 | SOL-001 | 2026-08-06 | 2026-08-06 |
| SOL-001 | Add shoulder allowance and target reach model | IMPLEMENTATION | WPN-013-DRIVE | - | - | COMPLETED | `docs/implementation/handoffs/SOL-001_HANDOFF.md` | `docs/implementation/evidence/SOL-001/` | REQ-SOL-001 | SOL-002 | 2026-08-06 | 2026-08-06 |
| SOL-002 | Implement primary arm-chain targeting | IMPLEMENTATION | SOL-001 | - | - | COMPLETED | `docs/implementation/handoffs/SOL-001_HANDOFF.md` | `docs/implementation/evidence/SOL-001/` | REQ-SOL-002 | SOL-003 | 2026-08-06 | 2026-08-06 |
| SOL-003 | Implement pole-vector elbow control | IMPLEMENTATION | SOL-002 | - | - | COMPLETED | `docs/implementation/handoffs/SOL-001_HANDOFF.md` | `docs/implementation/evidence/SOL-001/` | REQ-SOL-003 | SOL-004 | 2026-08-06 | 2026-08-06 |
| SOL-004 | Implement wrist orientation matching | IMPLEMENTATION | SOL-003 | - | - | COMPLETED | `docs/implementation/handoffs/SOL-001_HANDOFF.md` | `docs/implementation/evidence/SOL-001/` | REQ-SOL-004 | SOL-005 | 2026-08-06 | 2026-08-06 |
| SOL-005 | Coordinate two-hand grip solving | IMPLEMENTATION | SOL-004 | - | - | COMPLETED | `docs/implementation/handoffs/SOL-001_HANDOFF.md` | `docs/implementation/evidence/SOL-001/` | REQ-SOL-005 | SOL-006 | 2026-08-06 | 2026-08-06 |
| SOL-006 | Enforce authored arm joint limits | IMPLEMENTATION | SOL-005 | - | - | COMPLETED | `docs/implementation/handoffs/SOL-001_HANDOFF.md` | `docs/implementation/evidence/SOL-001/` | REQ-SOL-006 | SOL-007 | 2026-08-06 | 2026-08-06 |
| SOL-007 | Report joint-limit and shoulder diagnostics | IMPLEMENTATION | SOL-006 | - | - | COMPLETED | `docs/implementation/handoffs/SOL-001_HANDOFF.md` | `docs/implementation/evidence/SOL-001/` | REQ-SOL-007 | SOL-008 | 2026-08-06 | 2026-08-06 |
| SOL-008 | Report unreachable grip diagnostics | IMPLEMENTATION | SOL-007 | - | - | COMPLETED | `docs/implementation/handoffs/SOL-001_HANDOFF.md` | `docs/implementation/evidence/SOL-001/` | REQ-SOL-008 | SOL-009 | 2026-08-06 | 2026-08-06 |
| SOL-009 | Add pixel-safe solver controls | IMPLEMENTATION | SOL-008 | - | - | COMPLETED | `docs/implementation/handoffs/SOL-001_HANDOFF.md` | `docs/implementation/evidence/SOL-001/` | REQ-SOL-009 | SOL-010 | 2026-08-06 | 2026-08-06 |
| SOL-010 | Add arm-solver visual overlays | IMPLEMENTATION | SOL-009 | - | - | COMPLETED | `docs/implementation/handoffs/SOL-001_HANDOFF.md` | `docs/implementation/evidence/SOL-001/` | REQ-SOL-010 | SOL-011 | 2026-08-06 | 2026-08-06 |
| SOL-011 | Add solver instrumentation | IMPLEMENTATION | SOL-010 | - | - | COMPLETED | `docs/implementation/handoffs/SOL-001_HANDOFF.md` | `docs/implementation/evidence/SOL-001/` | REQ-SOL-011 | SOL-012 | 2026-08-06 | 2026-08-06 |
| SOL-012 | Add recoverable solver failure states | IMPLEMENTATION | SOL-011 | - | - | COMPLETED | `docs/implementation/handoffs/SOL-001_HANDOFF.md` | `docs/implementation/evidence/SOL-001/` | REQ-SOL-012 | SOL-013 | 2026-08-06 | 2026-08-06 |
| SOL-013 | Apply body and facing transform compensation | IMPLEMENTATION | SOL-012 | - | - | COMPLETED | `docs/implementation/handoffs/SOL-001_HANDOFF.md` | `docs/implementation/evidence/SOL-001/` | REQ-SOL-013 | SOL-014 | 2026-08-06 | 2026-08-06 |
| SOL-014 | Implement deterministic grip refinement | IMPLEMENTATION | SOL-013 | - | - | COMPLETED | `docs/implementation/handoffs/SOL-001_HANDOFF.md` | `docs/implementation/evidence/SOL-001/` | REQ-SOL-014 | SOL-015 | 2026-08-06 | 2026-08-06 |
| SOL-015 | Build arm-solver regression scenarios | IMPLEMENTATION | SOL-014 | - | - | COMPLETED | `docs/implementation/handoffs/SOL-001_HANDOFF.md` | `docs/implementation/evidence/SOL-001/` | REQ-SOL-015 | WPA-001 | 2026-08-06 | 2026-08-06 |
| WPA-001 | Create weapon authoring wizard workflow | IMPLEMENTATION | SOL-015 | - | - | COMPLETED | `docs/implementation/handoffs/WPA-001_HANDOFF.md` | `docs/implementation/evidence/WPA-001/` | REQ-WPA-001 | WPA-002 | 2026-08-06 | 2026-08-06 |
| WPA-002 | Preview weapon coverage across body types | IMPLEMENTATION | WPA-001 | - | - | COMPLETED | `docs/implementation/handoffs/WPA-001_HANDOFF.md` | `docs/implementation/evidence/WPA-001/` | REQ-WPA-002 | WPA-003 | 2026-08-06 | 2026-08-06 |
| WPA-003 | Preview weapon coverage across directions | IMPLEMENTATION | WPA-002 | - | - | COMPLETED | `docs/implementation/handoffs/WPA-001_HANDOFF.md` | `docs/implementation/evidence/WPA-001/` | REQ-WPA-003 | WPA-004 | 2026-08-06 | 2026-08-06 |
| WPA-004 | Report grip reachability in the wizard | IMPLEMENTATION | WPA-003 | - | - | COMPLETED | `docs/implementation/handoffs/WPA-001_HANDOFF.md` | `docs/implementation/evidence/WPA-001/` | REQ-WPA-004 | WPA-005 | 2026-08-06 | 2026-08-06 |
| WPA-005 | Add dual-wield authoring workflow | IMPLEMENTATION | WPA-004 | - | - | COMPLETED | `docs/implementation/handoffs/WPA-001_HANDOFF.md` | `docs/implementation/evidence/WPA-001/` | REQ-WPA-005 | WPA-006 | 2026-08-06 | 2026-08-06 |
| WPA-006 | Add shield authoring workflow | IMPLEMENTATION | WPA-005 | - | - | COMPLETED | `docs/implementation/handoffs/WPA-001_HANDOFF.md` | `docs/implementation/evidence/WPA-001/` | REQ-WPA-006 | WPA-007 | 2026-08-06 | 2026-08-06 |
| WPA-007 | Add bow authoring workflow | IMPLEMENTATION | WPA-006 | - | - | COMPLETED | `docs/implementation/handoffs/WPA-001_HANDOFF.md` | `docs/implementation/evidence/WPA-001/` | REQ-WPA-007 | WPA-008 | 2026-08-06 | 2026-08-06 |
| WPA-008 | Add flexible-weapon authoring workflow | IMPLEMENTATION | WPA-007 | - | - | COMPLETED | `docs/implementation/handoffs/WPA-001_HANDOFF.md` | `docs/implementation/evidence/WPA-001/` | REQ-WPA-008 | WPA-009 | 2026-08-06 | 2026-08-06 |
| WPA-009 | Add holster and socket authoring | IMPLEMENTATION | WPA-008 | - | - | COMPLETED | `docs/implementation/handoffs/WPA-001_HANDOFF.md` | `docs/implementation/evidence/WPA-001/` | REQ-WPA-009 | WPA-010 | 2026-08-06 | 2026-08-06 |
| WPA-010 | Add draw and sheath authoring | IMPLEMENTATION | WPA-009 | - | - | COMPLETED | `docs/implementation/handoffs/WPA-001_HANDOFF.md` | `docs/implementation/evidence/WPA-001/` | REQ-WPA-010 | WPA-011 | 2026-08-06 | 2026-08-06 |
| WPA-011 | Build all-body coverage report | IMPLEMENTATION | WPA-010 | - | - | COMPLETED | `docs/implementation/handoffs/WPA-001_HANDOFF.md` | `docs/implementation/evidence/WPA-001/` | REQ-WPA-011 | WPA-012 | 2026-08-06 | 2026-08-06 |
| WPA-012 | Build all-direction coverage report | IMPLEMENTATION | WPA-011 | - | - | COMPLETED | `docs/implementation/handoffs/WPA-001_HANDOFF.md` | `docs/implementation/evidence/WPA-001/` | REQ-WPA-012 | WPA-013 | 2026-08-06 | 2026-08-06 |
| WPA-013 | Add wizard validation and actionable repair links | IMPLEMENTATION | WPA-012 | - | - | COMPLETED | `docs/implementation/handoffs/WPA-001_HANDOFF.md` | `docs/implementation/evidence/WPA-001/` | REQ-WPA-013 | WPA-014 | 2026-08-06 | 2026-08-06 |
| WPA-014 | Persist and restore weapon authoring sessions | IMPLEMENTATION | WPA-013 | - | - | COMPLETED | `docs/implementation/handoffs/WPA-001_HANDOFF.md` | `docs/implementation/evidence/WPA-001/` | REQ-WPA-014 | WPA-015 | 2026-08-06 | 2026-08-06 |
| WPA-015 | Make the wizard keyboard and controller reachable | IMPLEMENTATION | WPA-014 | - | - | COMPLETED | `docs/implementation/handoffs/WPA-001_HANDOFF.md` | `docs/implementation/evidence/WPA-001/` | REQ-WPA-015 | QA-WPN-001 | 2026-08-06 | 2026-08-06 |
| QA-WPN-001 | Verify all master weapon drive modes | VERIFICATION | WPN-008-DRIVE through WPN-013-DRIVE | - | - | COMPLETED | `docs/implementation/handoffs/QA-COMPLETION-001_HANDOFF.md` | `docs/implementation/evidence/QA-COMPLETION-001/` | REQ-WPN-DRIVE-008 through REQ-WPN-DRIVE-013 | QA-SOL-001 | 2026-08-06 | 2026-08-06 |
| QA-SOL-001 | Verify arm and hand solver behavior | VERIFICATION | SOL-001 through SOL-015 | - | - | COMPLETED | `docs/implementation/handoffs/QA-COMPLETION-001_HANDOFF.md` | `docs/implementation/evidence/QA-COMPLETION-001/` | REQ-SOL-001 through REQ-SOL-015 | QA-WPA-001 | 2026-08-06 | 2026-08-06 |
| QA-WPA-001 | Verify equipment authoring acceptance matrix | VERIFICATION | WPA-001 through WPA-015, QA-WPN-001, QA-SOL-001 | - | - | COMPLETED | `docs/implementation/handoffs/QA-COMPLETION-001_HANDOFF.md` | `docs/implementation/evidence/QA-COMPLETION-001/` | REQ-WPA-001 through REQ-WPA-015 | QA-CHR-001 | 2026-08-06 | 2026-08-06 |

### Completion Plan — Phase 3 Character Creator

| Task ID | Title | Thread Type | Dependencies | Branch | Commit | Status | Handoff Path | Evidence Path | Requirement IDs | Recommended Next | Assigned | Completed |
|---------|-------|-------------|--------------|--------|--------|--------|--------------|---------------|-----------------|-----------------|----------|-----------|
| CHR-001 | Define body-type, slot, and character-part schemas | IMPLEMENTATION | QA-WPA-001 | - | - | COMPLETED | `docs/implementation/handoffs/CHR-001_HANDOFF.md` | `docs/implementation/evidence/CHR-001/` | REQ-CHR-001 | CHR-002 | 2026-08-06 | 2026-08-06 |
| CHR-002 | Implement slot and part registries | IMPLEMENTATION | CHR-001 | - | - | COMPLETED | `docs/implementation/handoffs/CHR-001_HANDOFF.md` | `docs/implementation/evidence/CHR-001/` | REQ-CHR-002 | CHR-003 | 2026-08-06 | 2026-08-06 |
| CHR-003 | Assemble characters from registered parts | IMPLEMENTATION | CHR-002 | - | - | COMPLETED | `docs/implementation/handoffs/CHR-001_HANDOFF.md` | `docs/implementation/evidence/CHR-001/` | REQ-CHR-003 | CHR-004 | 2026-08-06 | 2026-08-06 |
| CHR-004 | Explain compatibility and conflict repairs | IMPLEMENTATION | CHR-003 | - | - | COMPLETED | `docs/implementation/handoffs/CHR-001_HANDOFF.md` | `docs/implementation/evidence/CHR-001/` | REQ-CHR-004 | CHR-005 | 2026-08-06 | 2026-08-06 |
| CHR-005 | Build filterable part browsing | IMPLEMENTATION | CHR-004 | - | - | COMPLETED | `docs/implementation/handoffs/CHR-001_HANDOFF.md` | `docs/implementation/evidence/CHR-001/` | REQ-CHR-005 | CHR-006 | 2026-08-06 | 2026-08-06 |
| CHR-006 | Apply character palettes | IMPLEMENTATION | CHR-005 | - | - | COMPLETED | `docs/implementation/handoffs/CHR-001_HANDOFF.md` | `docs/implementation/evidence/CHR-001/` | REQ-CHR-006 | CHR-007 | 2026-08-06 | 2026-08-06 |
| CHR-007 | Author part attachment maps | IMPLEMENTATION | CHR-006 | - | - | COMPLETED | `docs/implementation/handoffs/CHR-001_HANDOFF.md` | `docs/implementation/evidence/CHR-001/` | REQ-CHR-007 | CHR-008 | 2026-08-06 | 2026-08-06 |
| CHR-008 | Save and apply outfits | IMPLEMENTATION | CHR-007 | - | - | COMPLETED | `docs/implementation/handoffs/CHR-001_HANDOFF.md` | `docs/implementation/evidence/CHR-001/` | REQ-CHR-008 | CHR-009 | 2026-08-06 | 2026-08-06 |
| CHR-009 | Generate deterministic random characters | IMPLEMENTATION | CHR-008 | - | - | COMPLETED | `docs/implementation/handoffs/CHR-001_HANDOFF.md` | `docs/implementation/evidence/CHR-001/` | REQ-CHR-009 | CHR-010 | 2026-08-06 | 2026-08-06 |
| CHR-010 | Lock parts and palette channels | IMPLEMENTATION | CHR-009 | - | - | COMPLETED | `docs/implementation/handoffs/CHR-001_HANDOFF.md` | `docs/implementation/evidence/CHR-001/` | REQ-CHR-010 | CHR-011 | 2026-08-06 | 2026-08-06 |
| CHR-011 | Save and restore character presets | IMPLEMENTATION | CHR-010 | - | - | COMPLETED | `docs/implementation/handoffs/CHR-001_HANDOFF.md` | `docs/implementation/evidence/CHR-001/` | REQ-CHR-011 | CHR-012 | 2026-08-06 | 2026-08-06 |
| CHR-012 | Generate unique NPC batches | IMPLEMENTATION | CHR-011 | - | - | COMPLETED | `docs/implementation/handoffs/CHR-001_HANDOFF.md` | `docs/implementation/evidence/CHR-001/` | REQ-CHR-012 | CHR-013 | 2026-08-06 | 2026-08-06 |
| CHR-013 | Integrate compatible weapons | IMPLEMENTATION | CHR-012 | - | - | COMPLETED | `docs/implementation/handoffs/CHR-001_HANDOFF.md` | `docs/implementation/evidence/CHR-001/` | REQ-CHR-013 | CHR-014 | 2026-08-06 | 2026-08-06 |
| CHR-014 | Support character edit undo and redo | IMPLEMENTATION | CHR-013 | - | - | COMPLETED | `docs/implementation/handoffs/CHR-001_HANDOFF.md` | `docs/implementation/evidence/CHR-001/` | REQ-CHR-014 | CHR-015 | 2026-08-06 | 2026-08-06 |
| CHR-015 | Deliver keyboard-reachable creator workspace | IMPLEMENTATION | CHR-014 | - | - | COMPLETED | `docs/implementation/handoffs/CHR-001_HANDOFF.md` | `docs/implementation/evidence/CHR-001/` | REQ-CHR-015 | CHR-016 | 2026-08-06 | 2026-08-06 |
| CHR-016 | Add serialized creator session and export handoff | IMPLEMENTATION | CHR-015 | - | - | COMPLETED | `docs/implementation/handoffs/CHR-001_HANDOFF.md` | `docs/implementation/evidence/CHR-001/` | REQ-CHR-016 | QA-CHR-001 | 2026-08-06 | 2026-08-06 |
| QA-CHR-001 | Verify 100 seeded characters and creator workflows | VERIFICATION | CHR-001 through CHR-016 | - | - | COMPLETED | `docs/implementation/handoffs/QA-COMPLETION-001_HANDOFF.md` | `docs/implementation/evidence/QA-COMPLETION-001/` | REQ-CHR-001 through REQ-CHR-016 | QA-GMD-001 | 2026-08-06 | 2026-08-06 |

### Completion Plan — Phase 4 Gameplay Metadata, Audio, and Reference Media

| Task ID | Title | Thread Type | Dependencies | Branch | Commit | Status | Handoff Path | Evidence Path | Requirement IDs | Recommended Next | Assigned | Completed |
|---------|-------|-------------|--------------|--------|--------|--------|--------------|---------------|-----------------|-----------------|----------|-----------|
| GMD-001 | Complete runtime metadata event delivery contract | IMPLEMENTATION | QA-CHR-001 | - | - | COMPLETED | `docs/implementation/handoffs/GMD-MED-001_HANDOFF.md` | `docs/implementation/evidence/GMD-MED-001/` | REQ-GMD-001 | GMD-002 | 2026-08-06 | 2026-08-06 |
| GMD-002 | Add metadata authoring diagnostics and repair actions | IMPLEMENTATION | GMD-001 | - | - | COMPLETED | `docs/implementation/handoffs/GMD-MED-001_HANDOFF.md` | `docs/implementation/evidence/GMD-MED-001/` | REQ-GMD-002 | GMD-003 | 2026-08-06 | 2026-08-06 |
| GMD-003 | Add action-point and collision debug visualization model | IMPLEMENTATION | GMD-002 | - | - | COMPLETED | `docs/implementation/handoffs/GMD-MED-001_HANDOFF.md` | `docs/implementation/evidence/GMD-MED-001/` | REQ-GMD-003 | GMD-004 | 2026-08-06 | 2026-08-06 |
| GMD-004 | Validate deterministic metadata timing | IMPLEMENTATION | GMD-003 | - | - | COMPLETED | `docs/implementation/handoffs/GMD-MED-001_HANDOFF.md` | `docs/implementation/evidence/GMD-MED-001/` | REQ-GMD-004 | GMD-005 | 2026-08-06 | 2026-08-06 |
| GMD-005 | Complete typed action, event, and variable metadata | IMPLEMENTATION | GMD-004 | - | - | COMPLETED | `docs/implementation/handoffs/GMD-MED-001_HANDOFF.md` | `docs/implementation/evidence/GMD-MED-001/` | REQ-GMD-005 | GMD-006 | 2026-08-06 | 2026-08-06 |
| GMD-006 | Complete hitbox and hurtbox delivery data | IMPLEMENTATION | GMD-005 | - | - | COMPLETED | `docs/implementation/handoffs/GMD-MED-001_HANDOFF.md` | `docs/implementation/evidence/GMD-MED-001/` | REQ-GMD-006 | GMD-007 | 2026-08-06 | 2026-08-06 |
| GMD-007 | Integrate metadata playback with the authoring timeline | IMPLEMENTATION | GMD-006 | - | - | COMPLETED | `docs/implementation/handoffs/GMD-MED-001_HANDOFF.md` | `docs/implementation/evidence/GMD-MED-001/` | REQ-GMD-007 | GMD-008 | 2026-08-06 | 2026-08-06 |
| GMD-008 | Add metadata round-trip and failure coverage | IMPLEMENTATION | GMD-007 | - | - | COMPLETED | `docs/implementation/handoffs/GMD-MED-001_HANDOFF.md` | `docs/implementation/evidence/GMD-MED-001/` | REQ-GMD-008 | MED-001 | 2026-08-06 | 2026-08-06 |
| MED-001 | Define imported audio metadata and safe source validation | IMPLEMENTATION | GMD-008 | - | - | COMPLETED | `docs/implementation/handoffs/GMD-MED-001_HANDOFF.md` | `docs/implementation/evidence/GMD-MED-001/` | REQ-MED-001 | MED-002 | 2026-08-06 | 2026-08-06 |
| MED-002 | Generate deterministic waveform cache data | IMPLEMENTATION | MED-001 | - | - | COMPLETED | `docs/implementation/handoffs/GMD-MED-001_HANDOFF.md` | `docs/implementation/evidence/GMD-MED-001/` | REQ-MED-002 | MED-003 | 2026-08-06 | 2026-08-06 |
| MED-003 | Author and scrub sound cues | IMPLEMENTATION | MED-002 | - | - | COMPLETED | `docs/implementation/handoffs/GMD-MED-001_HANDOFF.md` | `docs/implementation/evidence/GMD-MED-001/` | REQ-MED-003 | MED-004 | 2026-08-06 | 2026-08-06 |
| MED-004 | Define viseme maps and manual lip-sync authoring | IMPLEMENTATION | MED-003 | - | - | COMPLETED | `docs/implementation/handoffs/GMD-MED-001_HANDOFF.md` | `docs/implementation/evidence/GMD-MED-001/` | REQ-MED-004 | MED-005 | 2026-08-06 | 2026-08-06 |
| MED-005 | Import timecoded lip-sync data | IMPLEMENTATION | MED-004 | - | - | COMPLETED | `docs/implementation/handoffs/GMD-MED-001_HANDOFF.md` | `docs/implementation/evidence/GMD-MED-001/` | REQ-MED-005 | MED-006 | 2026-08-06 | 2026-08-06 |
| MED-006 | Add audio and lip-sync validation coverage | IMPLEMENTATION | MED-005 | - | - | COMPLETED | `docs/implementation/handoffs/GMD-MED-001_HANDOFF.md` | `docs/implementation/evidence/GMD-MED-001/` | REQ-MED-006 | MED-007 | 2026-08-06 | 2026-08-06 |
| MED-007 | Define video/GIF/image-sequence reference media | IMPLEMENTATION | MED-006 | - | - | COMPLETED | `docs/implementation/handoffs/GMD-MED-001_HANDOFF.md` | `docs/implementation/evidence/GMD-MED-001/` | REQ-MED-007 | MED-008 | 2026-08-06 | 2026-08-06 |
| MED-008 | Synchronize reference media to the playhead | IMPLEMENTATION | MED-007 | - | - | COMPLETED | `docs/implementation/handoffs/GMD-MED-001_HANDOFF.md` | `docs/implementation/evidence/GMD-MED-001/` | REQ-MED-008 | MED-009 | 2026-08-06 | 2026-08-06 |
| MED-009 | Exclude reference media from exports | IMPLEMENTATION | MED-008 | - | - | COMPLETED | `docs/implementation/handoffs/GMD-MED-001_HANDOFF.md` | `docs/implementation/evidence/GMD-MED-001/` | REQ-MED-009 | MED-010 | 2026-08-06 | 2026-08-06 |
| MED-010 | Repair missing reference-media sources | IMPLEMENTATION | MED-009 | - | - | COMPLETED | `docs/implementation/handoffs/GMD-MED-001_HANDOFF.md` | `docs/implementation/evidence/GMD-MED-001/` | REQ-MED-010 | QA-MED-001 | 2026-08-06 | 2026-08-06 |
| QA-GMD-001 | Verify frame-accurate gameplay metadata delivery | VERIFICATION | GMD-001 through GMD-008 | - | - | COMPLETED | `docs/implementation/handoffs/QA-COMPLETION-001_HANDOFF.md` | `docs/implementation/evidence/QA-COMPLETION-001/` | REQ-GMD-001 through REQ-GMD-008 | QA-MED-001 | 2026-08-06 | 2026-08-06 |
| QA-MED-001 | Verify audio and reference-media synchronization | VERIFICATION | MED-001 through MED-010 | - | - | COMPLETED | `docs/implementation/handoffs/QA-COMPLETION-001_HANDOFF.md` | `docs/implementation/evidence/QA-COMPLETION-001/` | REQ-MED-001 through REQ-MED-010 | QA-RUL-001 | 2026-08-06 | 2026-08-06 |

### Completion Plan — Phase 5 Advanced Composition

| Task ID | Title | Thread Type | Dependencies | Branch | Commit | Status | Handoff Path | Evidence Path | Requirement IDs | Recommended Next | Assigned | Completed |
|---------|-------|-------------|--------------|--------|--------|--------|--------------|---------------|-----------------|-----------------|----------|-----------|
| BLD-001 | Add layered additive, masked, synchronized, and weapon-overlay blending | IMPLEMENTATION | QA-MED-001 | - | - | COMPLETED | `docs/implementation/handoffs/COMPOSITION-001_HANDOFF.md` | `docs/implementation/evidence/COMPOSITION-001/` | REQ-BLD-001 through REQ-BLD-005 | STM-001 | 2026-08-06 | 2026-08-06 |
| STM-001 | Add visual state-machine authoring, nested machines, preview, and export | IMPLEMENTATION | BLD-001 | - | - | COMPLETED | `docs/implementation/handoffs/COMPOSITION-001_HANDOFF.md` | `docs/implementation/evidence/COMPOSITION-001/` | REQ-STM-001 through REQ-STM-004 | RUL-001 | 2026-08-06 | 2026-08-06 |
| RUL-001 | Add visual rule graphs, time/event actions, diagnostics, and cycle protection | IMPLEMENTATION | STM-001 | - | - | COMPLETED | `docs/implementation/handoffs/COMPOSITION-001_HANDOFF.md` | `docs/implementation/evidence/COMPOSITION-001/` | REQ-RUL-001 through REQ-RUL-005 | LNK-001 | 2026-08-06 | 2026-08-06 |
| LNK-001 | Add shared linked projects, refresh conflicts, overrides, packaging, and preview | IMPLEMENTATION | RUL-001 | - | - | COMPLETED | `docs/implementation/handoffs/COMPOSITION-001_HANDOFF.md` | `docs/implementation/evidence/COMPOSITION-001/` | REQ-LNK-001 through REQ-LNK-008 | QA-RUL-001 | 2026-08-06 | 2026-08-06 |
| QA-LNK-001 | Verify linked-project recovery, conflict resolution, and package parity | VERIFICATION | LNK-001 | - | - | COMPLETED | `docs/implementation/handoffs/QA-COMPLETION-001_HANDOFF.md` | `docs/implementation/evidence/QA-COMPLETION-001/` | REQ-LNK-001 through REQ-LNK-008 | QA-EXP-BATCH-001 | 2026-08-06 | 2026-08-06 |

### Completion Plan — Phase 6 Export and Godot Consumer Runtime

| Task ID | Title | Thread Type | Dependencies | Branch | Commit | Status | Handoff Path | Evidence Path | Requirement IDs | Recommended Next | Assigned | Completed |
|---------|-------|-------------|--------------|--------|--------|--------|--------------|---------------|-----------------|-----------------|----------|-----------|
| EXP-009 | Add batch variants, cancellation/progress, artifact validation, and output-opening workflow | IMPLEMENTATION | QA-LNK-001 | - | - | COMPLETED | `docs/implementation/handoffs/RUNTIME-EXPORT-001_HANDOFF.md` | `docs/implementation/evidence/RUNTIME-EXPORT-001/` | REQ-EXP-009 through REQ-EXP-012 | GDT-001 | 2026-08-06 | 2026-08-06 |
| GDT-001 | Add native Godot mappings, portable runtime parity, import reports, and API documentation | IMPLEMENTATION | EXP-009 | - | - | COMPLETED | `docs/implementation/handoffs/RUNTIME-EXPORT-001_HANDOFF.md` | `docs/implementation/evidence/RUNTIME-EXPORT-001/` | REQ-GDT-001 through REQ-GDT-014 | QA-GDT-001 | 2026-08-06 | 2026-08-06 |
| QA-EXP-BATCH-001 | Verify batch cancellation, progress, artifact opening, and output integrity | VERIFICATION | EXP-009 | - | - | COMPLETED | `docs/implementation/handoffs/QA-COMPLETION-001_HANDOFF.md` | `docs/implementation/evidence/QA-COMPLETION-001/` | REQ-EXP-009 through REQ-EXP-012 | QA-GDT-001 | 2026-08-06 | 2026-08-06 |

### Completion Plan — Phase 7 Reliability, Accessibility, and Packaging

| Task ID | Title | Thread Type | Dependencies | Branch | Commit | Status | Handoff Path | Evidence Path | Requirement IDs | Recommended Next | Assigned | Completed |
|---------|-------|-------------|--------------|--------|--------|--------|--------------|---------------|-----------------|-----------------|----------|-----------|
| REC-001 | Add recovery browser, interrupted-save handling, quality diagnostics, and safety audits | IMPLEMENTATION | QA-GDT-001 | - | - | COMPLETED | `docs/implementation/handoffs/QUALITY-001_HANDOFF.md` | `docs/implementation/evidence/QUALITY-001/` | REQ-REC-001, REQ-REC-002, REQ-PRF-001 through REQ-PRF-006, REQ-ACC-001 through REQ-ACC-004 | SMP-001 | 2026-08-06 | 2026-08-06 |
| QA-PRF-001 | Verify recovery, scale/performance, accessibility, and release-safety behavior | VERIFICATION | REC-001 | - | - | COMPLETED | `docs/implementation/handoffs/QA-COMPLETION-001_HANDOFF.md` | `docs/implementation/evidence/QA-COMPLETION-001/` | REQ-REC-001, REQ-REC-002, REQ-PRF-001 through REQ-PRF-006, REQ-ACC-001 through REQ-ACC-004 | QA-REL-001 | 2026-08-06 | 2026-08-06 |

### Completion Plan — Phase 8 Samples, Documentation, and Release

| Task ID | Title | Thread Type | Dependencies | Branch | Commit | Status | Handoff Path | Evidence Path | Requirement IDs | Recommended Next | Assigned | Completed |
|---------|-------|-------------|--------------|--------|--------|--------|--------------|---------------|-----------------|-----------------|----------|-----------|
| SMP-001 | Add validated representative samples, manuals, release manifest, and readiness checks | IMPLEMENTATION | QA-PRF-001 | - | - | COMPLETED | `docs/implementation/handoffs/RELEASE-001_HANDOFF.md` | `docs/implementation/evidence/RELEASE-001/` | REQ-SMP-001 through REQ-SMP-006, REQ-DOCS-001 through REQ-DOCS-004 | REL-001 | 2026-08-06 | 2026-08-06 |
| REL-001 | Add release notes, known issues, Windows preset, build preflight, and smoke instructions | IMPLEMENTATION | SMP-001 | - | - | COMPLETED | `docs/implementation/handoffs/RELEASE-001_HANDOFF.md` | `docs/implementation/evidence/RELEASE-001/` | REQ-REL-001 through REQ-REL-004 | QA-REL-001 | 2026-08-06 | 2026-08-06 |
| QA-REL-001 | Verify Windows package and clean-machine smoke release | VERIFICATION | REL-001 | - | - | IN_PROGRESS | - | `docs/implementation/evidence/QA-REL-001/` | REQ-SMP-001 through REQ-SMP-006, REQ-DOCS-001 through REQ-DOCS-004, REQ-REL-001 through REQ-REL-004 | Completion | 2026-08-06 | - |

## Summary

- **Tracked Task Rows:** 237 with standard status fields
- **PLANNED:** 0
- **IN_PROGRESS:** 1
- **COMPLETED:** 236
- **FAILED:** 0
- **BLOCKED:** 0

## Maintenance

- Each thread begins with a new row (if not already present) or an update to an existing PLANNED row.
- A thread sets status to `IN_PROGRESS` when it starts.
- When completed, status is set to `COMPLETED` and the commit, handoff path, and completed date are filled.
- Verification threads never update implementation rows — they add their own row.
- The dependency column must be verified before starting a task.
