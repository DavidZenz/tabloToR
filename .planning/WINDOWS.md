---
schema_version: 1
open_count: 0
waived_count: 0
fixed_count: 1
total_count: 1
last_updated: 2026-08-25T07:13:40.171Z
---

# Broken Windows Ledger

> Cross-phase defect register. With `workflow.windows_enforce` enabled, `/gsd-ship` blocks while `open_count > 0`.
> Waive with `gsd-tools windows waive <id> "<reason>"` (reason required).
> Mark fixed with `gsd-tools windows fixed <id>`.

| id | phase | kind | file | line | description | status | reason | recorded_at | resolved_at |
|----|-------|------|------|------|-------------|--------|--------|-------------|-------------|
| 1 | 01 | deviation | .planning/STATE.md |  | state.update-progress skipped the in-progress phase; derived progress and velocity were repaired to match 1/6 summaries | fixed |  | 2026-08-25T07:13:30.040Z | 2026-08-25T07:13:40.171Z |

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
  }
]
````
