---
schema_version: 1
open_count: 2
waived_count: 0
fixed_count: 5
total_count: 7
last_updated: 2026-08-25T12:15:17.329Z
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
| 5 | 01 | stub | DESCRIPTION | 16 | License field remains the pre-existing placeholder pending dependency compatibility audit and Plan 01-06. | open |  | 2026-08-25T12:10:54.212Z |  |
| 6 | 01 | stub | DESCRIPTION | 12 | Maintainer field remains the pre-existing placeholder until Plan 01-06 applies the approved contact. | open |  | 2026-08-25T12:10:54.238Z |  |
| 7 | 01 | deviation | .planning/STATE.md |  | Repaired stale derived progress after state.update-progress skipped the unscoped in-progress phase following Plan 01-05. | fixed |  | 2026-08-25T12:15:13.616Z | 2026-08-25T12:15:17.329Z |

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
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-25T12:10:54.212Z",
    "resolved_at": null
  },
  {
    "id": 6,
    "kind": "stub",
    "phase": "01",
    "file": "DESCRIPTION",
    "line": 12,
    "description": "Maintainer field remains the pre-existing placeholder until Plan 01-06 applies the approved contact.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-25T12:10:54.238Z",
    "resolved_at": null
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
  }
]
````
