---
schema_version: 1
open_count: 0
waived_count: 0
fixed_count: 4
total_count: 4
last_updated: 2026-08-25T10:58:52.724Z
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
  }
]
````
