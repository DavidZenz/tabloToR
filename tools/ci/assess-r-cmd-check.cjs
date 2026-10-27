#!/usr/bin/env node
"use strict";
const fs = require("node:fs");
const crypto = require("node:crypto");

// Maintainer-approved GitHub-source policy (2026-10-27), distinct from CRAN
// acceptance. Callers must
// separately require actual URL verification and all other release checks.
function assessCheckLog(log, exitStatus) {
  if (typeof log !== "string" || (exitStatus !== null && !Number.isInteger(exitStatus))) throw new Error("INVALID_CHECK_INPUT");
  const lines = log.replace(/\r\n/g, "\n").split("\n");
  const statuses = lines.filter(line => /^Status:/.test(line));
  const status = statuses.length === 1 ? statuses[0].trim() : "Status: INVALID";
  const counts = { errors: 0, warnings: 0, notes: 0 };
  let valid = status === "Status: OK";
  if (!valid && /^Status: (?:[0-9]+ (?:ERROR[Ss]?|WARNING[Ss]?|NOTE[Ss]?))(?:, [0-9]+ (?:ERROR[Ss]?|WARNING[Ss]?|NOTE[Ss]?))*$/.test(status)) {
    valid = true;
    const seen = new Set();
    for (const match of status.matchAll(/([0-9]+) (ERROR[Ss]?|WARNING[Ss]?|NOTE[Ss]?)/g)) {
      const key = match[2].startsWith("ERROR") ? "errors" : match[2].startsWith("WARNING") ? "warnings" : "notes";
      if (seen.has(key) || +match[1] < 1) valid = false;
      seen.add(key);
      counts[key] = +match[1];
    }
  }
  const findings = [];
  for (let i = 0; i < lines.length; i++) {
    const header = /^\* checking (.+) \.\.\. (ERROR|WARNING|NOTE)$/.exec(lines[i]);
    if (!header) continue;
    const body = [];
    for (let j = i + 1; j < lines.length && !/^\* /.test(lines[j]) && !/^Status:/.test(lines[j]); j++) {
      if (lines[j].trim()) body.push(lines[j].trim());
    }
    let reason = "UNREVIEWED_FINDING";
    if (header[2] === "NOTE") {
      if (header[1] === "CRAN incoming feasibility" && body.length === 2 &&
          /^Maintainer: [‘']David Zenz <zenz@wiiw\.ac\.at>[’']$/.test(body[0]) && body[1] === "New submission") {
        reason = "CRAN_NEW_SUBMISSION";
      } else if (header[1] === "for future file timestamps" && body.length === 1 &&
                 body[0] === "unable to verify current time") {
        reason = "EXTERNAL_CLOCK_UNAVAILABLE";
      } else if (header[1] === "installed package size" && body.length === 3 &&
                 /^installed size is +[0-9]+(?:\.[0-9]+)?Mb$/.test(body[0]) &&
                 body[1] === "sub-directories of 1Mb or more:" && /^libs +[0-9]+(?:\.[0-9]+)?Mb$/.test(body[2]) &&
                 +body[0].match(/[0-9]+(?:\.[0-9]+)?/)[0] <= 12 &&
                 +body[2].match(/[0-9]+(?:\.[0-9]+)?/)[0] <= 10) {
        reason = "NATIVE_LIBRARY_SIZE_WITHIN_REVIEWED_BOUND";
      }
    }
    findings.push({ check: header[1], severity: header[2], reason, body });
  }
  for (const [key, severity] of [["errors", "ERROR"], ["warnings", "WARNING"], ["notes", "NOTE"]]) {
    if (findings.filter(finding => finding.severity === severity).length !== counts[key]) valid = false;
  }
  if (new Set(findings.map(finding => finding.check)).size !== findings.length) valid = false;
  const unexplained = findings.filter(finding => finding.reason === "UNREVIEWED_FINDING").length;
  const passed = valid && exitStatus === 0 && !counts.errors && !counts.warnings && !unexplained &&
    lines.some(line => line.trim() === "* DONE");
  return { policy: "github-source-check-v1", assessment_status: passed ? "passed" : "failed",
    exit_status: exitStatus, status_line: status, ...counts, unexplained_findings: unexplained,
    log_sha256: crypto.createHash("sha256").update(log).digest("hex"),
    assessor_sha256: crypto.createHash("sha256").update(fs.readFileSync(__filename)).digest("hex"), findings };
}

if (require.main === module) {
  try {
    if (process.argv.length !== 4 || !/^[0-9]+$/.test(process.argv[3])) throw new Error("INVALID_ARGUMENTS");
    const result = assessCheckLog(fs.readFileSync(process.argv[2], "utf8"), Number(process.argv[3]));
    process.stdout.write(JSON.stringify(result, null, 2) + "\n");
    if (result.assessment_status !== "passed") process.exitCode = 1;
  } catch { process.stderr.write("FAIL CHECK_LOG_ASSESSMENT\n"); process.exitCode = 1; }
}
module.exports = { assessCheckLog };
