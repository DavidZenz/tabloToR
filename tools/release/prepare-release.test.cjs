"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const test = require("node:test");

const cli = path.join(__dirname, "prepare-release.cjs");

function git(cwd, args) {
  const result = spawnSync("git", args, { cwd, encoding: "utf8" });
  assert.equal(result.status, 0, result.stderr);
  return result.stdout.trim();
}

function fixture(callback) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "gemodelr-release-test-"));
  const repository = path.join(directory, "repository");
  fs.mkdirSync(repository);
  git(repository, ["init", "--quiet"]);
  git(repository, ["config", "user.name", "Release fixture"]);
  git(repository, ["config", "user.email", "fixture@example.invalid"]);
  fs.mkdirSync(path.join(repository, "R"));
  fs.mkdirSync(path.join(repository, "tools", "ci"), { recursive: true });
  fs.writeFileSync(path.join(repository, "DESCRIPTION"), "Package: GEModelR\nVersion: 0.1.0\n");
  fs.writeFileSync(path.join(repository, "R", "model.R"), "model = function() 1\n");
  fs.writeFileSync(path.join(repository, "tools", "ci", "run-installed-release-smoke.R"),
    "# Selected revision's smoke artifact\n");
  git(repository, ["add", "--", "DESCRIPTION", "R/model.R", "tools/ci/run-installed-release-smoke.R"]);
  git(repository, ["commit", "--quiet", "-m", "fixture"]);
  try {
    callback({ directory, repository, output: path.join(directory, "packet") });
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
}

function run(repository, args, options = {}) {
  return spawnSync(process.execPath, [cli, ...args], {
    cwd: repository, encoding: "utf8", ...options
  });
}

function prepare(repository, output, extra = []) {
  return run(repository, ["prepare", "--source-ref", "HEAD", "--output", output,
    "--tag", "v0.1.0", ...extra]);
}

test("prepares and verifies a committed-source packet without consuming dirty files", () => {
  fixture(({ repository, output }) => {
    const sourceCommit = git(repository, ["rev-parse", "HEAD"]);
    const sourceTree = git(repository, ["rev-parse", "HEAD^{tree}"]);
    const smoke = fs.readFileSync(path.join(repository, "tools/ci/run-installed-release-smoke.R"));
    fs.writeFileSync(path.join(repository, "R/model.R"), "dirty private canary\n");
    fs.writeFileSync(path.join(repository, "untracked-canary.txt"), "do not collect\n");
    const before = git(repository, ["status", "--porcelain=v1"]);
    const refsBefore = git(repository, ["show-ref"]);
    const result = prepare(repository, output);
    assert.equal(result.status, 0, result.stderr);
    const manifest = JSON.parse(fs.readFileSync(path.join(output, "private/manifest.json")));
    assert.equal(manifest.schema_version, 1);
    assert.equal(manifest.source_commit, sourceCommit);
    assert.equal(manifest.source_tree, sourceTree);
    assert.equal(manifest.package, "GEModelR");
    assert.equal(manifest.version, "0.1.0");
    assert.equal(manifest.intended_tag, "v0.1.0");
    assert.equal(manifest.tag_type, "annotated_unsigned");
    assert.equal(manifest.publication_authorized, false);
    assert.equal(manifest.publication_readiness, "unqualified");
    assert.equal(manifest.public_source_commit, "not_created");
    assert.ok(Object.values(manifest.checks).every((value) => value === "not_run"));
    assert.equal(fs.readFileSync(path.join(output, "private/source/R/model.R"), "utf8"),
      "model = function() 1\n");
    assert.equal(fs.existsSync(path.join(output, "private/source/untracked-canary.txt")), false);
    assert.deepEqual(fs.readFileSync(path.join(output, "public/run-installed-release-smoke.R")), smoke);
    assert.deepEqual(JSON.parse(fs.readFileSync(path.join(output, "public/registry/packages.json"))),
      [{ package: "GEModelR", url: "https://github.com/DavidZenz/GEModelR", branch: "v0.1.0" }]);
    const publicManifest = JSON.parse(fs.readFileSync(path.join(output, "public/manifest.json")));
    assert.equal(publicManifest.source_commit, sourceCommit);
    assert.equal(publicManifest.release_notes_status, "unavailable");
    assert.equal("files" in publicManifest, false);
    const verified = run(repository, ["verify", "--packet", output]);
    assert.equal(verified.status, 0, verified.stderr);
    assert.equal(JSON.parse(verified.stdout).status, "verified");
    assert.equal(git(repository, ["status", "--porcelain=v1"]), before);
    assert.equal(git(repository, ["show-ref"]), refsBefore);
  });
});
