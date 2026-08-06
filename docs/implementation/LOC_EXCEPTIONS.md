# Line-of-Code Exception Registry
# Modular 2D Character Creator and Animation Studio

> **Schema Version:** 1.0.0  
> **Rule Reference:** Section 3.4 of the Master Plan  
> **Limit:** 300 physical lines per handwritten production file

---

## Exception Criteria

A file may exceed 300 lines only when ALL of the following conditions are met:

1. A split analysis explains the responsibilities in the file.
2. The analysis explains why splitting would harm correctness, clarity, performance, generated-code integrity, or engine compatibility.
3. The exact line count is recorded.
4. A verification task approves the exception.
5. The exception is listed in this file.

Generated files, lockfiles, imported third-party sources, binary assets, and authoritative long-form design documents are exempt.

---

## Active Exceptions

| Exception ID | File Path | Line Count | Approved By | Approval Date | Split Analysis Reference | Rationale |
|-------------|-----------|------------|-------------|---------------|--------------------------|-----------|
| *(none yet)* | - | - | - | - | - | - |

---

## Denied Exceptions

| Denial ID | File Path | Requested Line Count | Denied By | Denial Date | Reason | Remediation |
|-----------|-----------|---------------------|-----------|-------------|--------|-------------|
| *(none yet)* | - | - | - | - | - | - |

---

## Resolved Exceptions

| Exception ID | File Path | Original Line Count | Resolved By | Resolution Date | How Resolved |
|-------------|-----------|--------------------|-------------|-----------------|--------------|
| *(none yet)* | - | - | - | - | - |

---

## Split Analysis Template

When requesting an exception, provide a split analysis with this structure:

```markdown
### Split Analysis for <file_path>

**Current line count:** <N>

**Responsibilities in this file:**
1. <responsibility_1>
2. <responsibility_2>
3. ...

**Attempted splits:**
| Proposed Split | Outcome | Why It Failed |
|---------------|---------|---------------|
| <split_description> | <FAILED/WORSE> | <reason> |

**Why splitting harms the project:**
<detailed explanation>

**Recommended action:**
- Approve exception with periodic review at <interval>
- OR Deny and require specific remediation
```

---

## Periodic Review Schedule

All active exceptions shall be reviewed:
- At each milestone gate
- When the file is modified
- When a refactoring opportunity arises

If an exception can be resolved, it moves to the Resolved table.

---

## Maintenance

- Implementation and verification threads check this file during stub/LOC scans.
- New exceptions require a split analysis and approval in a verification task.
- Denied exceptions must be resolved before the corresponding task can be marked COMPLETED.