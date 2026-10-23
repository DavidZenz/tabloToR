"use strict";

const assert = require("node:assert/strict");
const crypto = require("node:crypto");
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

function rewriteManifest(output, transform) {
  const file = path.join(output, "private/manifest.json");
  const manifest = JSON.parse(fs.readFileSync(file));
  transform(manifest);
  delete manifest.content_sha256;
  manifest.content_sha256 = crypto.createHash("sha256")
    .update(JSON.stringify(manifest, null, 2) + "\n").digest("hex");
  fs.writeFileSync(file, JSON.stringify(manifest, null, 2) + "\n");
}

test("rejects invalid required input without creating output or leaking raw values", () => {
  fixture(({ repository, output }) => {
    const cases = [
      [["prepare"], "INVALID_SOURCE_REF"],
      [["prepare", "--source-ref", "", "--output", output, "--tag", "v0.1.0"], "INVALID_SOURCE_REF"],
      [["prepare", "--source-ref", "missing-ref", "--output", output, "--tag", "v0.1.0"], "GIT_READ_FAILED"],
      [["prepare", "--source-ref", "HEAD", "--output", output, "--tag", "v0.2.0"], "TAG_VERSION_MISMATCH"],
      [["prepare", "--source-ref", "HEAD", "--output", output, "--tag", "/private/rejected-value"], "INVALID_TAG"],
      [["prepare", "--source-ref", "HEAD", "--tag", "v0.1.0"], "MISSING_OUTPUT"],
      [["prepare", "--source-ref", "HEAD", "--output", output, "--tag", "v0.1.0", "--tag", "v0.1.0"], "INVALID_ARGUMENTS"]
    ];
    for (const [args, code] of cases) {
      const result = run(repository, args);
      assert.equal(result.status, 1);
      assert.equal(result.stderr, "FAIL " + code + "\n");
      assert.equal(result.stdout, "");
      assert.equal(fs.existsSync(output), false);
    }
  });
});

test("rejects checkout overlap, symlink escape, and output collisions without replacement", () => {
  fixture(({ directory, repository, output }) => {
    for (const target of [repository, path.join(repository, "packet"), directory]) {
      const result = prepare(repository, target);
      assert.equal(result.stderr, "FAIL OUTPUT_SOURCE_OVERLAP\n");
    }
    const alias = path.join(directory, "checkout-alias");
    fs.symlinkSync(repository, alias, "junction");
    assert.equal(prepare(repository, path.join(alias, "packet")).stderr,
      "FAIL OUTPUT_SOURCE_OVERLAP\n");
    const dangling = path.join(directory, "dangling");
    fs.symlinkSync(path.join(directory, "missing"), dangling, "junction");
    assert.equal(prepare(repository, dangling).stderr, "FAIL OUTPUT_SYMLINK\n");
    fs.mkdirSync(output);
    fs.writeFileSync(path.join(output, "keep.txt"), "preserve output\n");
    assert.equal(prepare(repository, output).stderr, "FAIL OUTPUT_NOT_EMPTY\n");
    assert.equal(fs.readFileSync(path.join(output, "keep.txt"), "utf8"), "preserve output\n");
  });
});

test("rejects committed symbolic links before extracting the source", () => {
  fixture(({ repository, output }) => {
    const blob = git(repository, ["rev-parse", "HEAD:DESCRIPTION"]);
    git(repository, ["update-index", "--add", "--cacheinfo", "120000," + blob + ",unsafe-link"]);
    git(repository, ["commit", "--quiet", "-m", "unsupported source link"]);
    const result = prepare(repository, output);
    assert.equal(result.stderr, "FAIL UNSAFE_SOURCE_ENTRY\n");
    assert.equal(fs.existsSync(output), false);
  });
});

test("matching local tags are read-only and conflicting tags fail", () => {
  fixture(({ directory, repository, output }) => {
    git(repository, ["tag", "v0.1.0"]);
    const before = git(repository, ["show-ref"]);
    assert.equal(prepare(repository, output).status, 0);
    assert.equal(git(repository, ["show-ref"]), before);
    fs.writeFileSync(path.join(repository, "R/model.R"), "model = function() 2\n");
    git(repository, ["add", "R/model.R"]);
    git(repository, ["commit", "--quiet", "-m", "new source"]);
    const conflict = prepare(repository, path.join(directory, "other-packet"));
    assert.equal(conflict.stderr, "FAIL TAG_SOURCE_CONFLICT\n");
    assert.equal(fs.existsSync(path.join(directory, "other-packet")), false);
  });
});

test("verification rejects added, removed, and changed governed files", () => {
  for (const mutation of ["add", "remove", "change"]) {
    fixture(({ repository, output }) => {
      assert.equal(prepare(repository, output).status, 0);
      const artifact = path.join(output, "public/run-installed-release-smoke.R");
      if (mutation === "add") fs.writeFileSync(path.join(output, "public/extra.txt"), "extra\n");
      if (mutation === "remove") fs.unlinkSync(artifact);
      if (mutation === "change") fs.appendFileSync(artifact, "changed\n");
      const result = run(repository, ["verify", "--packet", output]);
      assert.equal(result.stderr, "FAIL PACKET_CONTENT_CHANGED\n", mutation);
    });
  }
});

test("verification rejects malformed manifest fields even after recomputing its digest", () => {
  fixture(({ repository, output }) => {
    assert.equal(prepare(repository, output).status, 0);
    rewriteManifest(output, (manifest) => { manifest.source_commit = "/private/secret-path"; });
    const result = run(repository, ["verify", "--packet", output]);
    assert.equal(result.stderr, "FAIL INVALID_MANIFEST\n");
    assert.equal(result.stdout, "");
  });
});

test("source identity rejects altered source bytes even if inventory hashes are recomputed", () => {
  fixture(({ repository, output }) => {
    assert.equal(prepare(repository, output).status, 0);
    const target = path.join(output, "private/source/R/model.R");
    fs.writeFileSync(target, "model = function() 999\n");
    rewriteManifest(output, (manifest) => {
      const entry = manifest.files.find((item) => item.path === "private/source/R/model.R");
      entry.size = fs.statSync(target).size;
      entry.sha256 = crypto.createHash("sha256").update(fs.readFileSync(target)).digest("hex");
    });
    assert.equal(run(repository, ["verify", "--packet", output]).stderr,
      "FAIL SOURCE_IDENTITY_MISMATCH\n");
  });
});

test("verification rejects an escaped manifest before reading outside content", () => {
  fixture(({ directory, repository, output }) => {
    assert.equal(prepare(repository, output).status, 0);
    const manifestPath = path.join(output, "private/manifest.json");
    const outside = path.join(directory, "outside.json");
    fs.renameSync(manifestPath, outside);
    // A directory junction also exercises the same boundary on Windows without
    // requiring permission to create file symlinks.
    const outsideDirectory = path.join(directory, "outside-private");
    fs.mkdirSync(outsideDirectory);
    fs.copyFileSync(outside, path.join(outsideDirectory, "manifest.json"));
    fs.renameSync(path.join(output, "private"), path.join(output, "private-original"));
    fs.symlinkSync(outsideDirectory, path.join(output, "private"), "junction");
    const { verifyReleasePacket } = require(cli);
    const original = fs.readFileSync;
    let outsideRead = false;
    fs.readFileSync = function(file, ...args) {
      if (typeof file === "string" && fs.realpathSync(file).startsWith(outsideDirectory + path.sep)) {
        outsideRead = true;
      }
      return original.call(this, file, ...args);
    };
    try {
      assert.throws(() => verifyReleasePacket({ packet: output }), { code: "PACKET_SYMLINK" });
      assert.equal(outsideRead, false);
    } finally {
      fs.readFileSync = original;
    }
  });
});

test("stable inventory identity is independent of output location and creation order", () => {
  fixture(({ directory, repository, output }) => {
    for (const name of ["z.txt", "a-lower.txt", "A-upper.txt"]) fs.writeFileSync(path.join(repository, name), name);
    git(repository, ["add", "z.txt", "a-lower.txt", "A-upper.txt"]);
    git(repository, ["commit", "--quiet", "-m", "ordering"]);
    assert.equal(prepare(repository, output).status, 0);
    const another = path.join(directory, "another");
    assert.equal(prepare(repository, another).status, 0);
    const manifest = JSON.parse(fs.readFileSync(path.join(output, "private/manifest.json")));
    const second = JSON.parse(fs.readFileSync(path.join(another, "private/manifest.json")));
    assert.equal(manifest.content_sha256, second.content_sha256);
    const names = manifest.files.map((entry) => entry.path);
    assert.deepEqual(names, [...names].sort((a, b) => Buffer.compare(Buffer.from(a), Buffer.from(b))));
  });
});

test("scanner integration rejects unsafe public notes without changing output", () => {
  fixture(({ repository, output }) => {
    fs.mkdirSync(path.join(repository, "docs/release"), { recursive: true });
    fs.writeFileSync(path.join(repository, "docs/release/RELEASE-NOTES.md"), "ghp_" + "X".repeat(40));
    git(repository, ["add", "docs/release/RELEASE-NOTES.md"]);
    git(repository, ["commit", "--quiet", "-m", "unsafe notes fixture"]);
    assert.equal(prepare(repository, output).stderr, "FAIL PUBLIC_CONTENT_REJECTED\n");
    assert.equal(fs.existsSync(output), false);
  });
});

test("preparation invokes only read-only Git operations and preserves index bytes", () => {
  fixture(({ directory, repository, output }) => {
    const index = path.join(repository, ".git/index");
    const before = fs.readFileSync(index);
    const trace = path.join(directory, "git-trace.log");
    const result = run(repository, ["prepare", "--source-ref", "HEAD", "--output", output,
      "--tag", "v0.1.0"], { env: { ...process.env, GIT_TRACE: trace } });
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(fs.readFileSync(index), before);
    const commands = fs.readFileSync(trace, "utf8");
    assert.doesNotMatch(commands, /built-in: git (?:push|fetch|checkout|reset|commit|update-index|remote)\b/);
    assert.match(commands, /built-in: git cat-file blob/);
  });
});
