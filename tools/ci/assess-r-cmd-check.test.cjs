"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const { assessCheckLog } = require("./assess-r-cmd-check.cjs");
const sections = [
  "* checking CRAN incoming feasibility ... NOTE\nMaintainer: ‘David Zenz <zenz@wiiw.ac.at>’\n\nNew submission\n",
  "* checking installed package size ... NOTE\n  installed size is  9.3Mb\n  sub-directories of 1Mb or more:\n    libs   8.1Mb\n",
  "* checking for future file timestamps ... NOTE\nunable to verify current time\n"
];
const log = sections.join("") + "* DONE\nStatus: 3 NOTEs\n";
test("assesses exact bounded informational notes and retains all raw dispositions", () => {
  const result = assessCheckLog(log, 0);
  assert.equal(result.assessment_status, "passed");
  assert.equal(result.notes, 3);
  assert.equal(result.findings.length, 3);
  assert.match(result.log_sha256, /^[a-f0-9]{64}$/);
  assert.match(result.assessor_sha256, /^[a-f0-9]{64}$/);
  assert.equal(assessCheckLog("* DONE\nStatus: OK\n", 0).assessment_status, "passed");
});
test("URL failures and extra incoming messages remain unreviewed", () => {
  for (const extra of ["Status: 404\n", "Found invalid URLs\n", "Unknown package issue\n"]) {
    assert.equal(assessCheckLog(log.replace("New submission\n", "New submission\n" + extra), 0).assessment_status, "failed");
  }
});
test("unknown notes, larger binaries and additional large directories fail", () => {
  for (const changed of [log.replace("9.3Mb", "12.1Mb"), log.replace("8.1Mb", "10.1Mb"),
    log.replace("libs   8.1Mb", "libs   8.1Mb\n doc 2.0Mb"), log.replace("unable to verify current time", "future timestamps found"),
    log.replace("installed package size", "unknown check")]) {
    assert.equal(assessCheckLog(changed, 0).assessment_status, "failed");
  }
});
test("nonzero exits, errors, warnings and inconsistent or missing summaries fail", () => {
  for (const changed of [log.replace("Status: 3 NOTEs", "Status: OK"), log.replace("3 NOTEs", "2 NOTEs"),
    log.replace("3 NOTEs", "3 NOTEs, 1 WARNING"), log + "Status: OK\n", log.replace("* DONE\n", ""),
    log.replace("Status: 3 NOTEs", "Status: unknown"), log.replace("Status: 3 NOTEs", "Status: 3 NOTEs, 3 NOTEs")]) {
    assert.equal(assessCheckLog(changed, 0).assessment_status, "failed");
  }
  assert.equal(assessCheckLog(log, 1).assessment_status, "failed");
  assert.equal(assessCheckLog(log, null).assessment_status, "failed");
  assert.equal(assessCheckLog(sections.join("") + sections.join("") + "* DONE\nStatus: 6 NOTEs\n", 0).assessment_status, "failed");
  assert.equal(assessCheckLog("* checking tests ... ERROR\n* DONE\nStatus: 1 ERROR\n", 1).assessment_status, "failed");
  assert.equal(assessCheckLog("* checking tests ... WARNING\n* DONE\nStatus: 1 WARNING\n", 0).assessment_status, "failed");
});
