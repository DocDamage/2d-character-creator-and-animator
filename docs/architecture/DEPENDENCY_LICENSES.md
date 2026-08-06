# Dependency License Manifest
# Modular 2D Character Creator and Animation Studio

> **Status:** Active  
> **Last Updated:** 2026-08-05  
> **Audit Status:** Initial — requires full audit before release

---

## Purpose

This manifest records every software dependency used by the project, including the Godot engine itself, plugins, libraries, and tools. Each entry includes the license, attribution requirements, and audit status.

---

## Engine

| Dependency | Version | License | Homepage | Attribution Required | Audit Status |
|-----------|---------|---------|----------|---------------------|-------------|
| Godot Engine | 4.7.1 | MIT | https://godotengine.org/ | Yes — include license in distribution | Verified |

---

## Godot Plugins

| Dependency | Version | License | Homepage | Attribution Required | Audit Status |
|-----------|---------|---------|----------|---------------------|-------------|
| *(none yet)* | - | - | - | - | - |

---

## GDScript Libraries / Add-ons

| Dependency | Version | License | Homepage | Attribution Required | Audit Status |
|-----------|---------|---------|----------|---------------------|-------------|
| *(none yet)* | - | - | - | - | - |

---

## External Tools (Bundled or Referenced)

| Dependency | Version | License | Homepage | Attribution Required | Audit Status |
|-----------|---------|---------|----------|---------------------|-------------|
| *(none yet)* | - | - | - | - | - |

---

## Fonts

| Font | License | Homepage | Attribution Required | Audit Status |
|------|---------|----------|---------------------|-------------|
| Godot default font (Noto Sans derivative) | SIL Open Font License 1.1 | https://fonts.google.com/noto | Yes — include license | Verified |

---

## License Categories Used

| License | Type | Copyleft? | Distribution Requirements |
|---------|------|-----------|-------------------------|
| MIT | Permissive | No | Include license text |
| SIL OFL 1.1 | Font license | No (weak copyleft) | Include license text; modified fonts must be renamed |

---

## Verification Notes

- All dependencies must be listed before the project can be distributed.
- The license must permit distribution with a proprietary or open-source product as applicable.
- Copyleft licenses must not infect the project unless approved and compatible with the target license.
- New dependencies require a license audit entry before merge.

---

## Attribution Template

The final release must include a `THIRD_PARTY_NOTICES.md` or similar file aggregating all required attributions. Format:

```
This product includes software developed by the Godot Engine contributors
(https://godotengine.org/), licensed under the MIT License.

[Additional entries as needed]
```

---

## Maintenance

- Updated whenever a dependency is added, removed, or version-bumped.
- Reviewed during each milestone gate.
- Final audit completed before Milestone 23 (Release).