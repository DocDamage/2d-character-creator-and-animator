# Asset License Manifest
# Modular 2D Character Creator and Animation Studio

> **Status:** Active  
> **Last Updated:** 2026-08-05  
> **Audit Status:** Initial — requires full audit before release

---

## Purpose

Every visual, audio, and data asset included in the project repository or distributed with the application must have documented provenance and license. This file tracks all sample assets, test fixtures, and shipped content.

---

## Asset Categories

| Category | Description | License Requirement |
|----------|-------------|-------------------|
| Sample Characters | Art used in sample projects and documentation | Permissive (CC0, CC-BY, or project-owned) |
| Test Fixtures | Minimal art for automated tests | Permissive; may be placeholder |
| UI Icons | Application interface icons | MIT-compatible or project-owned |
| Default Theme | Shipping UI theme assets | Project-owned or MIT-compatible |
| Documentation Images | Screenshots and diagrams in docs | Covered by project license |

---

## Sample Assets

| Asset | Author | License | Source | Provenance Verified | Notes |
|-------|--------|---------|--------|-------------------|-------|
| *(none yet)* | - | - | - | - | Sample assets to be created in Milestones 23 |

---

## Test Fixture Assets

| Asset | Author | License | Source | Provenance Verified | Notes |
|-------|--------|---------|--------|-------------------|-------|
| Minimal 32x32 colored squares | Project-generated | CC0 | tools/generate_test_assets.gd (future) | No | Placeholder fixtures for GOV-008 |

---

## UI Icons

| Icon Set | Author | License | Source | Provenance Verified | Notes |
|----------|--------|---------|--------|-------------------|-------|
| *(none yet — using engine defaults)* | - | - | - | - | - |

---

## Audio Assets

| Asset | Author | License | Source | Provenance Verified | Notes |
|-------|--------|---------|--------|-------------------|-------|
| *(none yet)* | - | - | - | - | - |

---

## Asset Provenance Verification Process

For each asset added to the repository:

1. Record the author or source.
2. Record the license (exact SPDX identifier preferred).
3. Verify the license permits the intended use (distribution, modification, commercial use if applicable).
4. Link to the original source or license file.
5. Confirm no incompatible license restrictions.

---

## Prohibited Assets

The following categories of assets must never be included:

- Assets with unknown or unclear licensing
- Assets from proprietary games or applications (even if "abandoned")
- AI-generated assets without verified, permissive training-data licensing
- Assets marked "all rights reserved" or with no license
- Assets from Spriter, Spine, or similar tools' sample content (copyrighted)

---

## Maintenance

- Updated whenever an asset is added, replaced, or removed.
- Reviewed during each milestone gate.
- Final audit performed before Milestone 23 (Release).