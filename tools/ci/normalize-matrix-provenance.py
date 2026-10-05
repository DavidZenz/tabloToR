#!/usr/bin/env python3
"""Retain checked JSON/job/artifact provenance for the offline base-R gate.

Only extracted CSV payloads and failed-source logs are retained, never archives,
native binaries or full check directories. SHA256 checks use the original JSON.
"""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import re

FIELDS = ["setup_r_alias", "resolved_r_version", "os", "build_mode",
          "candidate_label", "matrix_version", "source_install_result",
          "solver_test_result", "run_id"]
EXTRA = ["run_attempt", "job_id", "job_name", "job_conclusion", "source_step",
         "solver_step", "artifact_id", "artifact_name", "artifact_digest",
         "payload_file", "payload_md5", "payload_sha256", "failure_log_file",
         "failure_log_md5", "failure_log_sha256", "failure_reason"]


def digest(data, algorithm="md5"):
    return hashlib.new(algorithm, data).hexdigest()


def strict_pairs(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("Duplicate JSON key: " + key)
        result[key] = value
    return result


def normalize(manifest, artifacts_root=None):
    raw = manifest.read_bytes()
    run = json.loads(raw, object_pairs_hook=strict_pairs)
    run_id, attempt = str(run["run_id"]), str(run["run_attempt"])
    if not re.fullmatch(r"[1-9][0-9]+", run_id) or not re.fullmatch(r"[1-9][0-9]*", attempt):
        raise ValueError("Invalid run/attempt")
    if manifest.name != "hosted-run-{}-{}.json".format(run_id, attempt):
        raise ValueError("Manifest filename/run/attempt mismatch")
    output = manifest.parent
    retained = output / ("payloads-{}-{}".format(run_id, attempt))
    retained.mkdir(exist_ok=True)
    rows = []
    for artifact in run["artifacts"]:
        if not artifact["name"].startswith("matrix-candidate-"):
            continue
        local = ((artifacts_root / artifact["name"]) if artifacts_root else
                 Path(artifact["local_directory"]))

        def checked_file(name):
            data = (local / name).read_bytes()
            expected = artifact["files"][name]
            if not re.fullmatch(r"[0-9a-f]{64}", expected) or digest(data, "sha256") != expected:
                raise ValueError("Artifact SHA256 mismatch: " + name)
            return data

        payload = checked_file("matrix-candidate-evidence.csv")
        reader = csv.DictReader(payload.decode("utf-8").splitlines())
        values = list(reader)
        if reader.fieldnames != FIELDS or len(values) != 1:
            raise ValueError("Artifact must contain exactly one evidence row")
        row = values[0]
        if row["run_id"] != run_id:
            raise ValueError("Artifact row run mismatch")
        expected_name = "matrix-candidate-{}-{}-{}-{}-{}-{}".format(
            run_id, attempt, row["setup_r_alias"], row["candidate_label"], row["os"], row["build_mode"])
        if artifact["name"] != expected_name or not re.fullmatch(r"sha256:[0-9a-f]{64}", artifact["digest"]):
            raise ValueError("Artifact identity/digest mismatch")
        # Both the historical explicit-version and current shared-resolver names
        # carry the same alias/candidate/platform/build identity.
        pattern = r"^{} / R {} / Matrix (?:{} \({}\)|{}) / {}$".format(
            re.escape(row["os"]), re.escape(row["setup_r_alias"]),
            re.escape(row["matrix_version"]), re.escape(row["candidate_label"]),
            re.escape(row["candidate_label"]), re.escape(row["build_mode"]))
        jobs = [j for j in run["jobs"] if re.fullmatch(pattern, j["name"])]
        if len(jobs) != 1:
            raise ValueError("Missing or duplicate matching hosted job")
        job = jobs[0]
        if job["url"] != run["url"] + "/job/" + str(job["id"]):
            raise ValueError("Hosted job run mismatch")

        def outcome(pattern):
            steps = [s for s in job["steps"] if re.fullmatch(pattern, s["name"])]
            if len(steps) != 1:
                raise ValueError("Missing/duplicate hosted step")
            return steps[0]["conclusion"]

        source = outcome(r"Source-install exact (?:provisional )?Matrix endpoint")
        solver = outcome(r"Run installed core contracts")
        translated = lambda status: "not_run" if status == "skipped" else status
        if source != row["source_install_result"] or translated(solver) != row["solver_test_result"]:
            raise ValueError("Artifact row disagrees with hosted step outcomes")
        payload_name = str(retained.relative_to(output) / (str(job["id"]) + ".csv"))
        (output / payload_name).write_bytes(payload)
        log_name, log_md5, log_sha256, reason = "none", "none", "none", "none"
        if source == "failure":
            log = checked_file("matrix-source-install.log")
            log_name = str(retained.relative_to(output) / (str(job["id"]) + ".log"))
            (output / log_name).write_bytes(log)
            log_md5, log_sha256 = digest(log), digest(log, "sha256")
            errors = [line.strip() for line in log.decode("utf-8").splitlines()
                      if re.search(r"error:", line, re.IGNORECASE)]
            if not errors:
                raise ValueError("Failed source artifact lacks an error reason")
            reason = errors[0]
        row.update(dict(zip(EXTRA, [attempt, str(job["id"]), job["name"], job["conclusion"],
            source, solver, str(artifact["id"]), artifact["name"], artifact["digest"],
            payload_name, digest(payload), digest(payload, "sha256"), log_name,
            log_md5, log_sha256, reason])))
        rows.append(row)
    if not rows or len({r["job_id"] for r in rows}) != len(rows):
        raise ValueError("Missing or duplicate normalized rows")
    normalized = output / ("hosted-provenance-{}-{}.csv".format(run_id, attempt))
    with normalized.open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=FIELDS + EXTRA)
        writer.writeheader()
        writer.writerows(rows)
    metadata = {"RunID": run_id, "RunAttempt": attempt, "HeadSHA": run["head_sha"],
        "RunURL": run["url"], "ManifestMD5": digest(raw),
        "RowsFile": normalized.name, "RowsMD5": digest(normalized.read_bytes()),
        "Normalization": "strict-json-and-artifact-sha256-v1"}
    dcf = output / ("hosted-provenance-{}-{}.dcf".format(run_id, attempt))
    dcf.write_text("".join("{}: {}\n".format(k, v) for k, v in metadata.items()))
    print("Normalized {} checked hosted rows: {}".format(len(rows), dcf))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--artifacts-root", type=Path)
    args = parser.parse_args()
    normalize(args.manifest, args.artifacts_root)
