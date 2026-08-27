---
schema_version: 1
open_count: 3
waived_count: 0
fixed_count: 16
total_count: 19
last_updated: 2026-08-27T12:11:28.869Z
---

# Broken Windows Ledger

> Cross-phase defect register. With `workflow.windows_enforce` enabled, `/gsd-ship` blocks while `open_count > 0`.
> Waive with `gsd-tools windows waive <id> "<reason>"` (reason required).
> Mark fixed with `gsd-tools windows fixed <id>`.

| id | phase | kind | file | line | description | status | reason | recorded_at | resolved_at |
|----|-------|------|------|------|-------------|--------|--------|-------------|-------------|
| 1 | 01 | deviation | .planning/STATE.md |  | state.update-progress skipped the in-progress phase; derived progress and velocity were repaired to match 1/6 summaries | fixed |  | 2026-08-25T07:13:30.040Z | 2026-08-25T07:13:40.171Z |
| 2 | 01 | deviation | tools/provenance_inventory.R |  | Selected working system Git because R-resolved Linuxbrew Git requires unavailable GLIBC symbols. | fixed |  | 2026-08-25T10:58:19.859Z | 2026-08-25T10:58:52.351Z |
| 3 | 01 | deviation | tools/provenance_inventory.R |  | Forced character CSV parsing so all-empty evidence columns remain exact empty strings. | fixed |  | 2026-08-25T10:58:20.038Z | 2026-08-25T10:58:52.554Z |
| 4 | 01 | deviation | .planning/STATE.md |  | Repaired stale derived progress after state.update-progress skipped the unscoped in-progress phase. | fixed |  | 2026-08-25T10:58:20.235Z | 2026-08-25T10:58:52.724Z |
| 5 | 01 | stub | DESCRIPTION | 16 | License field remains the pre-existing placeholder pending dependency compatibility audit and Plan 01-06. | fixed |  | 2026-08-25T12:10:54.212Z | 2026-08-25T12:46:42.333Z |
| 6 | 01 | stub | DESCRIPTION | 12 | Maintainer field remains the pre-existing placeholder until Plan 01-06 applies the approved contact. | fixed |  | 2026-08-25T12:10:54.238Z | 2026-08-25T12:46:46.935Z |
| 7 | 01 | deviation | .planning/STATE.md |  | Repaired stale derived progress after state.update-progress skipped the unscoped in-progress phase following Plan 01-05. | fixed |  | 2026-08-25T12:15:13.616Z | 2026-08-25T12:15:17.329Z |
| 8 | 01 | stub | DESCRIPTION | 18 | License field intentionally remains unresolved pending the LinkingTo, vendored, and native dependency compatibility audit. | open |  | 2026-08-25T12:46:47.055Z |  |
| 9 | 01 | deviation | docs/provenance/RIGHTS.md |  | Replaced stale Plan 01-03/01-04 temporary markers with complete integrated evidence and the two reviewed blockers. | fixed |  | 2026-08-25T12:46:53.746Z | 2026-08-25T12:46:59.289Z |
| 10 | 01 | deviation | tests/testthat/test-release-gates.R |  | Repository-only evidence tests skip when their tooling and evidence are intentionally excluded from a built source package. | fixed |  | 2026-08-25T12:46:53.861Z | 2026-08-25T12:46:59.414Z |
| 11 | 01 | deviation | .planning/STATE.md |  | Repaired stale derived progress and blocker narrative after state.update-progress skipped the unscoped verifying phase. | fixed |  | 2026-08-25T12:49:50.252Z | 2026-08-25T12:49:59.919Z |
| 12 | 01 | deviation | tests/testthat/test-name-availability.R | 803 | Checked-in report regression required unsigned markers after explicit Task 3 approval; updated to exact signed reviewer/date and strict verification. | fixed |  | 2026-08-27T07:27:05.647Z | 2026-08-27T07:27:29.666Z |
| 13 | 01 | deviation | .planning/STATE.md |  | Reconciled stale Plan 2 and 55% narrative after unscoped state.update-progress skipped seven-summary phase state. | fixed |  | 2026-08-27T07:29:01.669Z | 2026-08-27T07:29:05.522Z |
| 14 | 01 | stub | docs/provenance/LICENSE-DECISION.md | 7 | Pending package-license value is intentional until DEPENDENCY_COMPATIBILITY_AUDIT_PENDING is resolved by a reviewed hash-bound audit. | open |  | 2026-08-27T10:19:30.085Z |  |
| 15 | 01 | deviation | .planning/STATE.md |  | Reconciled stale 73% progress and seven-plan velocity after state.update-progress skipped the unscoped in-progress phase following Plan 01-07. | fixed |  | 2026-08-27T10:21:37.195Z | 2026-08-27T10:22:33.916Z |
| 16 | 01 | deviation | tests/testthat/test-release-gates.R | 999 | Corrected malformed-result fixture rehashing to bind the rewritten DCF artifact directly. | fixed |  | 2026-08-27T10:59:25.170Z | 2026-08-27T10:59:49.267Z |
| 17 | 01 | deviation | .planning/STATE.md |  | Reconciled human-readable progress after the SDK skipped derived fields for an unscoped phase. | fixed |  | 2026-08-27T10:59:25.379Z | 2026-08-27T10:59:49.477Z |
| 18 | 01 | unmet-truth | .planning/phases/01-provenance-and-release-boundary/01-11-PLAN.md |  | Final rtk R CMD check . fails because Linuxbrew binutils require GLIBC symbols unavailable on the Debian 10 host; Plan 01-11 remains halted. | open |  | 2026-08-27T12:09:32.553Z |  |
| 19 | 01 | deviation | .planning/STATE.md |  | Reconciled halted Plan 01-11 metadata after roadmap.update-plan-progress marked it executed and raised completed plans to 11. | fixed |  | 2026-08-27T12:11:08.874Z | 2026-08-27T12:11:28.869Z |

````json
[
  {
    "id": 1,
    "kind": "deviation",
    "phase": "01",
    "file": ".planning/STATE.md",
    "line": null,
    "description": "state.update-progress skipped the in-progress phase; derived progress and velocity were repaired to match 1/6 summaries",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-08-25T07:13:30.040Z",
    "resolved_at": "2026-08-25T07:13:40.171Z"
  },
  {
    "id": 2,
    "kind": "deviation",
    "phase": "01",
    "file": "tools/provenance_inventory.R",
    "line": null,
    "description": "Selected working system Git because R-resolved Linuxbrew Git requires unavailable GLIBC symbols.",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-08-25T10:58:19.859Z",
    "resolved_at": "2026-08-25T10:58:52.351Z"
  },
  {
    "id": 3,
    "kind": "deviation",
    "phase": "01",
    "file": "tools/provenance_inventory.R",
    "line": null,
    "description": "Forced character CSV parsing so all-empty evidence columns remain exact empty strings.",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-08-25T10:58:20.038Z",
    "resolved_at": "2026-08-25T10:58:52.554Z"
  },
  {
    "id": 4,
    "kind": "deviation",
    "phase": "01",
    "file": ".planning/STATE.md",
    "line": null,
    "description": "Repaired stale derived progress after state.update-progress skipped the unscoped in-progress phase.",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-08-25T10:58:20.235Z",
    "resolved_at": "2026-08-25T10:58:52.724Z"
  },
  {
    "id": 5,
    "kind": "stub",
    "phase": "01",
    "file": "DESCRIPTION",
    "line": 16,
    "description": "License field remains the pre-existing placeholder pending dependency compatibility audit and Plan 01-06.",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-08-25T12:10:54.212Z",
    "resolved_at": "2026-08-25T12:46:42.333Z"
  },
  {
    "id": 6,
    "kind": "stub",
    "phase": "01",
    "file": "DESCRIPTION",
    "line": 12,
    "description": "Maintainer field remains the pre-existing placeholder until Plan 01-06 applies the approved contact.",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-08-25T12:10:54.238Z",
    "resolved_at": "2026-08-25T12:46:46.935Z"
  },
  {
    "id": 7,
    "kind": "deviation",
    "phase": "01",
    "file": ".planning/STATE.md",
    "line": null,
    "description": "Repaired stale derived progress after state.update-progress skipped the unscoped in-progress phase following Plan 01-05.",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-08-25T12:15:13.616Z",
    "resolved_at": "2026-08-25T12:15:17.329Z"
  },
  {
    "id": 8,
    "kind": "stub",
    "phase": "01",
    "file": "DESCRIPTION",
    "line": 18,
    "description": "License field intentionally remains unresolved pending the LinkingTo, vendored, and native dependency compatibility audit.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-25T12:46:47.055Z",
    "resolved_at": null
  },
  {
    "id": 9,
    "kind": "deviation",
    "phase": "01",
    "file": "docs/provenance/RIGHTS.md",
    "line": null,
    "description": "Replaced stale Plan 01-03/01-04 temporary markers with complete integrated evidence and the two reviewed blockers.",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-08-25T12:46:53.746Z",
    "resolved_at": "2026-08-25T12:46:59.289Z"
  },
  {
    "id": 10,
    "kind": "deviation",
    "phase": "01",
    "file": "tests/testthat/test-release-gates.R",
    "line": null,
    "description": "Repository-only evidence tests skip when their tooling and evidence are intentionally excluded from a built source package.",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-08-25T12:46:53.861Z",
    "resolved_at": "2026-08-25T12:46:59.414Z"
  },
  {
    "id": 11,
    "kind": "deviation",
    "phase": "01",
    "file": ".planning/STATE.md",
    "line": null,
    "description": "Repaired stale derived progress and blocker narrative after state.update-progress skipped the unscoped verifying phase.",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-08-25T12:49:50.252Z",
    "resolved_at": "2026-08-25T12:49:59.919Z"
  },
  {
    "id": 12,
    "kind": "deviation",
    "phase": "01",
    "file": "tests/testthat/test-name-availability.R",
    "line": 803,
    "description": "Checked-in report regression required unsigned markers after explicit Task 3 approval; updated to exact signed reviewer/date and strict verification.",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-08-27T07:27:05.647Z",
    "resolved_at": "2026-08-27T07:27:29.666Z"
  },
  {
    "id": 13,
    "kind": "deviation",
    "phase": "01",
    "file": ".planning/STATE.md",
    "line": null,
    "description": "Reconciled stale Plan 2 and 55% narrative after unscoped state.update-progress skipped seven-summary phase state.",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-08-27T07:29:01.669Z",
    "resolved_at": "2026-08-27T07:29:05.522Z"
  },
  {
    "id": 14,
    "kind": "stub",
    "phase": "01",
    "file": "docs/provenance/LICENSE-DECISION.md",
    "line": 7,
    "description": "Pending package-license value is intentional until DEPENDENCY_COMPATIBILITY_AUDIT_PENDING is resolved by a reviewed hash-bound audit.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-27T10:19:30.085Z",
    "resolved_at": null
  },
  {
    "id": 15,
    "kind": "deviation",
    "phase": "01",
    "file": ".planning/STATE.md",
    "line": null,
    "description": "Reconciled stale 73% progress and seven-plan velocity after state.update-progress skipped the unscoped in-progress phase following Plan 01-07.",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-08-27T10:21:37.195Z",
    "resolved_at": "2026-08-27T10:22:33.916Z"
  },
  {
    "id": 16,
    "kind": "deviation",
    "phase": "01",
    "file": "tests/testthat/test-release-gates.R",
    "line": 999,
    "description": "Corrected malformed-result fixture rehashing to bind the rewritten DCF artifact directly.",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-08-27T10:59:25.170Z",
    "resolved_at": "2026-08-27T10:59:49.267Z"
  },
  {
    "id": 17,
    "kind": "deviation",
    "phase": "01",
    "file": ".planning/STATE.md",
    "line": null,
    "description": "Reconciled human-readable progress after the SDK skipped derived fields for an unscoped phase.",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-08-27T10:59:25.379Z",
    "resolved_at": "2026-08-27T10:59:49.477Z"
  },
  {
    "id": 18,
    "kind": "unmet-truth",
    "phase": "01",
    "file": ".planning/phases/01-provenance-and-release-boundary/01-11-PLAN.md",
    "line": null,
    "description": "Final rtk R CMD check . fails because Linuxbrew binutils require GLIBC symbols unavailable on the Debian 10 host; Plan 01-11 remains halted.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-27T12:09:32.553Z",
    "resolved_at": null
  },
  {
    "id": 19,
    "kind": "deviation",
    "phase": "01",
    "file": ".planning/STATE.md",
    "line": null,
    "description": "Reconciled halted Plan 01-11 metadata after roadmap.update-plan-progress marked it executed and raised completed plans to 11.",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-08-27T12:11:08.874Z",
    "resolved_at": "2026-08-27T12:11:28.869Z"
  }
]
````
