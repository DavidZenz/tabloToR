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

const smokeRunner = path.join(__dirname, "../ci/run-installed-release-smoke.R");
const smokeInputs = ["GEModelR_TEST_LIBRARY", "GEModelR_EXPECTED_VERSION",
  "GEModelR_DISTRIBUTION_CHANNEL", "GEModelR_EXPECTED_SOURCE_COMMIT"];

function runSmoke(values) {
  const env = { ...process.env };
  for (const name of smokeInputs) delete env[name];
  Object.assign(env, values);
  return spawnSync("Rscript", ["--vanilla", smokeRunner], { env, encoding: "utf8" });
}

test("installed smoke requires explicit inputs and never accepts a missing library", () => {
  const missing = runSmoke({});
  assert.equal(missing.status, 1);
  assert.equal(missing.stderr, "FAIL MISSING_GEModelR_TEST_LIBRARY\n");
  fixture(({ directory }) => {
    const result = runSmoke({
      GEModelR_TEST_LIBRARY: path.join(directory, "absent-library"),
      GEModelR_EXPECTED_VERSION: "0.1.0", GEModelR_DISTRIBUTION_CHANNEL: "local",
      GEModelR_EXPECTED_SOURCE_COMMIT: "a".repeat(40)
    });
    assert.equal(result.status, 1);
    assert.equal(result.stderr, "FAIL MISSING_SELECTED_LIBRARY\n");
    assert.doesNotMatch(result.stdout, /PASS/);
  });
});

test("installed smoke rejects bad metadata and the actual declared Matrix floor before loading", () => {
  fixture(({ directory }) => {
    const library = path.join(directory, "library");
    fs.mkdirSync(path.join(library, "GEModelR"), { recursive: true });
    fs.mkdirSync(path.join(library, "Matrix"));
    const metadata = path.join(library, "GEModelR/DESCRIPTION");
    const values = {
      GEModelR_TEST_LIBRARY: library, GEModelR_EXPECTED_VERSION: "0.1.0",
      GEModelR_DISTRIBUTION_CHANNEL: "local", GEModelR_EXPECTED_SOURCE_COMMIT: "a".repeat(40)
    };
    fs.writeFileSync(metadata, "Package: GEModelR\nVersion: 9.9.9\nImports: Matrix (>= 1.6-5)\n");
    assert.equal(runSmoke(values).stderr, "FAIL PACKAGE_VERSION_MISMATCH\n");
    fs.writeFileSync(metadata, "Package: GEModelR\nVersion: 0.1.0\n");
    assert.equal(runSmoke(values).stderr, "FAIL INVALID_PACKAGE_METADATA\n");
    // These are DESCRIPTION-only negative fixtures, never installed packages or
    // mocked numerical passes. The floor must fail before namespace loading.
    fs.writeFileSync(metadata, "Package: GEModelR\nVersion: 0.1.0\nImports: Matrix (>= 1000.0)\n");
    fs.writeFileSync(path.join(library, "Matrix/DESCRIPTION"), "Package: Matrix\nVersion: 999.0\n");
    const unsupported = runSmoke(values);
    assert.equal(unsupported.status, 1);
    assert.equal(unsupported.stderr, "FAIL MATRIX_BELOW_FLOOR\n");
    assert.doesNotMatch(unsupported.stdout, /PASS/);
    fs.writeFileSync(metadata, "Package: GEModelR\nVersion: 0.1.0\nImports: Matrix\n");
    fs.writeFileSync(path.join(library, "Matrix/DESCRIPTION"), "Package: Matrix\nVersion: 0.0.0\n");
    assert.equal(runSmoke(values).stderr, "FAIL MATRIX_BELOW_FLOOR\n");
    fs.writeFileSync(path.join(library, "Matrix/DESCRIPTION"), "Package: Matrix\nVersion: 999.0\n");
    fs.writeFileSync(metadata, "Package: GEModelR\nVersion: 0.1.0\nImports: Matrix (>= 1.6-5)\nRemoteSha: " +
      "b".repeat(40) + "\n");
    const wrongUniverse = runSmoke({ ...values, GEModelR_DISTRIBUTION_CHANNEL: "runiverse" });
    assert.equal(wrongUniverse.status, 1);
    assert.equal(wrongUniverse.stderr, "FAIL RUNIVERSE_SOURCE_MISMATCH\n");
    assert.doesNotMatch(wrongUniverse.stdout, /PASS/);
  });
});

function candidateFixture(callback) {
  fixture((values) => {
    const { repository } = values;
    fs.mkdirSync(path.join(repository, "docs/release"), { recursive: true });
    fs.mkdirSync(path.join(repository, ".planning"));
    fs.writeFileSync(path.join(repository, ".planning/private.txt"), "private history canary\n");
    fs.writeFileSync(path.join(repository, "docs/release/RELEASE-NOTES.md"), "Development candidate.\n");
    fs.mkdirSync(path.join(repository, "tools"), { recursive: true });
    fs.writeFileSync(path.join(repository, "tools/check_release_gates.R"), "# guard fixture\n");
    const tracked = git(repository, ["ls-files"]).split("\n");
    const added = [".planning/private.txt", "docs/release/RELEASE-NOTES.md",
      "docs/release/public-source.json", "tools/check_release_gates.R"];
    const names = [...new Set([...tracked, ...added])].sort();
    const exclude = names.filter((name) => name.startsWith(".planning/") || name.startsWith("docs/release/"))
      .map((name) => ({ path: name, reason: "Private development evidence" }));
    const policy = { schema_version: 1,
      include: names.filter((name) => !exclude.some((item) => item.path === name)), exclude };
    fs.writeFileSync(path.join(repository, "docs/release/public-source.json"), JSON.stringify(policy));
    git(repository, ["add", "--", ...added]);
    git(repository, ["commit", "--quiet", "-m", "candidate evidence"]);
    callback(values);
  });
}

function stage(repository, output) {
  assert.equal(prepare(repository, output).status, 0);
  return run(repository, ["stage-public-source", "--packet", output]);
}

const cleanR43CheckLog = [
  "* using R version 4.3.0 (2023-04-21)",
  "* using platform: x86_64-pc-linux-gnu (64-bit)",
  "* using option '--as-cran'",
  "* checking for file 'GEModelR/DESCRIPTION' ... OK",
  "* checking extension type ... Package",
  "* this is package 'GEModelR' version '0.1.0'",
  "* checking CRAN incoming feasibility ... OK",
  "* checking package dependencies ... OK",
  "* checking whether package 'GEModelR' can be installed ... OK",
  "* checking examples ... OK",
  "* checking tests ...",
  "  Running 'testthat.R'",
  " OK",
  "* DONE",
  "Status: OK", ""
].join("\n");

test("public projection is an exact separate root commit with no private history or original mutation", () => {
  candidateFixture(({ repository, output }) => {
    const refs = git(repository, ["show-ref"]);
    const index = fs.readFileSync(path.join(repository, ".git/index"));
    const staged = stage(repository, output);
    assert.equal(staged.status, 0, staged.stderr);
    const manifest = JSON.parse(fs.readFileSync(path.join(output, "private/manifest.json")));
    assert.equal(manifest.preparation_status, "complete");
    assert.match(manifest.public_source_commit, /^[a-f0-9]{40}$/);
    assert.notEqual(manifest.public_source_commit, manifest.source_commit);
    const projected = path.join(output, "private/public-source");
    assert.equal(git(projected, ["rev-parse", "HEAD"]), manifest.public_source_commit);
    assert.equal(git(projected, ["rev-list", "--count", "HEAD"]), "1");
    assert.equal(git(projected, ["symbolic-ref", "HEAD"]), "refs/heads/main");
    assert.equal(git(projected, ["rev-list", "--parents", "-n", "1", "HEAD"]), manifest.public_source_commit);
    assert.notEqual(spawnSync("git", ["-C", projected, "cat-file", "-e", manifest.source_commit + "^{commit}"]).status, 0);
    assert.equal(git(projected, ["remote"]), "");
    assert.equal(fs.existsSync(path.join(projected, ".planning")), false);
    assert.equal(fs.existsSync(path.join(projected, "docs/release")), false);
    assert.deepEqual(fs.readFileSync(path.join(projected, "R/model.R")),
      fs.readFileSync(path.join(output, "private/source/R/model.R")));
    assert.equal(run(repository, ["verify", "--packet", output]).status, 0);
    assert.equal(git(repository, ["show-ref"]), refs);
    assert.deepEqual(fs.readFileSync(path.join(repository, ".git/index")), index);
    assert.equal(run(repository, ["verify", "--packet", output, "--for-publication"]).status, 1);
    git(projected, ["tag", "v0.1.0"]);
    assert.equal(run(repository, ["verify", "--packet", output]).status, 0);
    git(projected, ["tag", "unreviewed-ref"]);
    assert.equal(run(repository, ["verify", "--packet", output]).stderr,
      "FAIL PUBLIC_SOURCE_IDENTITY_MISMATCH\n");
  });
});

test("projection requires complete dispositions and rejects unknown paths before public staging", () => {
  candidateFixture(({ repository, output }) => {
    fs.writeFileSync(path.join(repository, "unknown.txt"), "not disposed\n");
    git(repository, ["add", "unknown.txt"]);
    git(repository, ["commit", "--quiet", "-m", "undisposed"]);
    const result = stage(repository, output);
    assert.equal(result.stderr, "FAIL SOURCE_POLICY_INCOMPLETE\n");
    assert.equal(fs.existsSync(path.join(output, "private/public-source")), false);
    assert.equal(run(repository, ["verify", "--packet", output]).status, 0);
  });
});

test("staged public source mutation is rejected", () => {
  candidateFixture(({ repository, output }) => {
    assert.equal(stage(repository, output).status, 0);
    fs.appendFileSync(path.join(output, "private/public-source/R/model.R"), "changed\n");
    assert.equal(run(repository, ["verify", "--packet", output]).stderr,
      "FAIL PACKET_CONTENT_CHANGED\n");
  });
});

test("a complete disposition cannot include private development evidence", () => {
  candidateFixture(({ repository, output }) => {
    const policyPath = path.join(repository, "docs/release/public-source.json");
    const policy = JSON.parse(fs.readFileSync(policyPath));
    policy.exclude = policy.exclude.filter((entry) => entry.path !== ".planning/private.txt");
    policy.include.push(".planning/private.txt");
    fs.writeFileSync(policyPath, JSON.stringify(policy));
    git(repository, ["add", "docs/release/public-source.json"]);
    git(repository, ["commit", "--quiet", "-m", "unsafe complete policy"]);
    assert.equal(stage(repository, output).stderr, "FAIL PRIVATE_SOURCE_INCLUDED\n");
    assert.equal(fs.existsSync(path.join(output, "private/public-source")), false);
  });
});

test("unsupported runtime completes preparation without attempting a build or inventing qualification", () => {
  candidateFixture(({ repository, output, directory }) => {
    assert.equal(stage(repository, output).status, 0);
    const calls = [];
    const runner = (command, args, options) => {
      calls.push({ command, args, cwd: options.cwd });
      if (args.includes("--offline")) return { status: 1,
        stdout: "repository_state=blocked\nrelease_ready=false\nreason_codes=DEPENDENCY_COMPATIBILITY_AUDIT_PENDING\n", stderr: "" };
      return { status: 0, stdout: JSON.stringify({ supported: false, reason: "MATRIX_BELOW_FLOOR",
        matrix_version: "1.6.3", matrix_minimum: "1.6-5" }), stderr: "" };
    };
    const library = path.join(directory, "library");
    fs.mkdirSync(library);
    const { qualifyReleasePacket } = require(cli);
    const result = qualifyReleasePacket({ packet: output, library, runner });
    assert.equal(result.qualification_status, "unavailable");
    const manifest = JSON.parse(fs.readFileSync(path.join(output, "private/manifest.json")));
    assert.equal(manifest.preparation_status, "complete");
    assert.equal(manifest.archive_source_commit, "not_built");
    assert.equal(manifest.archive_sha256, "not_built");
    assert.equal(manifest.checks.archive_build, "not_run");
    assert.equal(manifest.publication_readiness, "blocked");
    assert.equal(calls.some((item) => item.command === "R"), false);
    assert.equal(run(repository, ["verify", "--packet", output]).status, 0);
    assert.equal(run(repository, ["verify", "--packet", output, "--for-publication"]).status, 1);
  });
});

test("the actual R prerequisite probe parses the declared floor without loading or installing packages", () => {
  candidateFixture(({ repository, output, directory }) => {
    fs.appendFileSync(path.join(repository, "DESCRIPTION"), "Imports: Matrix (>= 999.0)\n");
    git(repository, ["add", "DESCRIPTION"]);
    git(repository, ["commit", "--quiet", "-m", "unavailable runtime floor"]);
    assert.equal(stage(repository, output).status, 0);
    const runner = (command, args, options) => {
      if (args.includes("-e")) return spawnSync(command, args, options);
      if (args.includes("--offline")) return { status: 1,
        stdout: "repository_state=blocked\nrelease_ready=false\nreason_codes=FIXTURE_BLOCKED\n", stderr: "" };
      assert.fail("Unsupported prerequisites must prevent package commands");
    };
    const library = path.join(directory, "library");
    fs.mkdirSync(library);
    require(cli).qualifyReleasePacket({ packet: output, library, runner });
    const manifest = JSON.parse(fs.readFileSync(path.join(output, "private/manifest.json")));
    assert.equal(manifest.qualification.runtime.reason, "MATRIX_BELOW_FLOOR");
    assert.equal(manifest.qualification.runtime.matrix_minimum, "999.0");
    assert.equal(manifest.checks.archive_build, "not_run");
  });
});

test("qualification builds projected bytes and shares one retained archive across scan, check, and install", () => {
  candidateFixture(({ repository, output, directory }) => {
    assert.equal(stage(repository, output).status, 0);
    const calls = [];
    const archiveBytes = Buffer.from("synthetic archive evidence is never real qualification");
    const runner = (command, args, options) => {
      calls.push({ command, args, cwd: options.cwd, timeout: options.timeout });
      if (args.includes("--offline")) return { status: 0,
        stdout: "repository_state=eligible\nrelease_ready=true\nreason_codes=NONE\n", stderr: "" };
      if (args.some((arg) => arg.includes("check-release-urls.R"))) return { status: 0,
        stdout: JSON.stringify({ status: "passed", reason: "URLS_VALIDATED" }), stderr: "" };
      if (command === "Rscript" && args.includes("-e")) return { status: 0,
        stdout: JSON.stringify({ supported: true, reason: "SUPPORTED", matrix_version: "1.6.5",
          matrix_minimum: "1.6-5" }), stderr: "" };
      if (command === "R" && args[1] === "build") {
        assert.equal(git(options.cwd, ["rev-parse", "HEAD"]),
          JSON.parse(fs.readFileSync(path.join(output, "private/manifest.json"))).public_source_commit);
        fs.writeFileSync(path.join(options.cwd, "GEModelR_0.1.0.tar.gz"), archiveBytes);
      }
      if (command === "R" && args[1] === "check") {
        const dir = args.find((arg) => arg.startsWith("--output=")).slice(9);
        fs.mkdirSync(path.join(dir, "GEModelR.Rcheck"), { recursive: true });
        fs.writeFileSync(path.join(dir, "GEModelR.Rcheck/00check.log"), cleanR43CheckLog);
      }
      if (command === "Rscript") return { status: 0, stdout: "PASS installed-release-smoke\n", stderr: "" };
      return { status: 0, stdout: "", stderr: "" };
    };
    const library = path.join(directory, "library");
    fs.mkdirSync(library);
    const { qualifyReleasePacket, validatePublicationReadiness } = require(cli);
    qualifyReleasePacket({ packet: output, library, runner });
    const manifest = JSON.parse(fs.readFileSync(path.join(output, "private/manifest.json")));
    assert.equal(manifest.archive_source_commit, manifest.public_source_commit);
    assert.equal(manifest.archive_sha256, crypto.createHash("sha256").update(archiveBytes).digest("hex"));
    const check = calls.find((item) => item.command === "R" && item.args[1] === "check");
    assert.equal(check.timeout, 1800000);
    const install = calls.find((item) => item.command === "R" && item.args[1] === "INSTALL");
    assert.ok(install, "A clean supported R4.3 log must advance to installation");
    assert.equal(manifest.qualification.guard.status, "passed");
    assert.equal(manifest.checks.archive_check, "passed");
    assert.equal(manifest.qualification.url_check_status, "passed");
    const scan = calls.find((item) => item.command === process.execPath && item.args.includes("--archive"));
    assert.equal(check.args.at(-1), install.args.at(-1));
    assert.equal(scan.args.at(-1), install.args.at(-1));
    assert.throws(() => validatePublicationReadiness(manifest), { code: "PUBLICATION_NOT_READY" });
    const actualShape = structuredClone(manifest);
    actualShape.qualification.evidence_kind = "actual";
    assert.doesNotThrow(() => validatePublicationReadiness(actualShape));
    // Model the pre-save state: the real archive exists, but its inventory row
    // was not in the manifest loaded before build/check. This is shape-only
    // fixture data; no actual evidence or ready packet is serialized here.
    actualShape.files = [];
    assert.throws(() => validatePublicationReadiness(actualShape), { code: "PUBLICATION_NOT_READY" });
    const { updatePublicationReadiness } = require(cli);
    assert.equal(updatePublicationReadiness(output, actualShape), "ready");
    assert.equal(updatePublicationReadiness(output, manifest), "blocked");
    assert.equal(manifest.qualification.evidence_kind, "fixture");
    for (const change of [
      (m) => { m.archive_source_commit = "a".repeat(40); },
      (m) => { m.archive_sha256 = "not_built"; },
      (m) => { m.archive_sha256 = "a".repeat(64); },
      (m) => { m.qualification.guard.status = "blocked"; },
      (m) => { m.checks.archive_check = "failed"; },
      (m) => { m.checks.installed_smoke = "not_run"; }
    ]) {
      const invalid = structuredClone(actualShape);
      change(invalid);
      assert.throws(() => validatePublicationReadiness(invalid), { code: "PUBLICATION_NOT_READY" });
    }
  });
});

test("guard and build consume frozen blob bytes despite an external Git smudge/EOL configuration", () => {
  candidateFixture(({ repository, output, directory }) => {
    fs.writeFileSync(path.join(repository, ".gitattributes"), "R/model.R eol=crlf\n");
    const policyPath = path.join(repository, "docs/release/public-source.json");
    const policy = JSON.parse(fs.readFileSync(policyPath));
    policy.include.push(".gitattributes");
    policy.include.sort();
    fs.writeFileSync(policyPath, JSON.stringify(policy));
    if (process.platform !== "win32") fs.chmodSync(path.join(repository, "R/model.R"), 0o755);
    git(repository, ["add", ".gitattributes", "docs/release/public-source.json", "R/model.R"]);
    git(repository, ["commit", "--quiet", "-m", "tracked EOL and mode fixture"]);
    const originalModel = fs.readFileSync(path.join(repository, "R/model.R"));
    const originalGuard = fs.readFileSync(path.join(repository, "tools/check_release_gates.R"));
    const config = path.join(directory, "external.gitconfig");
    const attributes = path.join(directory, "external.attributes");
    const smudge = path.join(directory, "smudge.cjs");
    const clean = path.join(directory, "clean.cjs");
    fs.writeFileSync(attributes, "R/model.R filter=review eol=crlf\ntools/check_release_gates.R filter=review\n");
    fs.writeFileSync(smudge, 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>process.stdout.write(s.replace("function() 1", "function() 999").replace("guard fixture", "changed guard")));');
    fs.writeFileSync(clean, "process.stdin.pipe(process.stdout);\n");
    const quote = (value) => '"' + value.replace(/\\/g, "/").replace(/["$`]/g, "\\$&") + '"';
    git(repository, ["config", "--file", config, "core.attributesFile", attributes]);
    git(repository, ["config", "--file", config, "filter.review.smudge", quote(process.execPath) + " " + quote(smudge)]);
    git(repository, ["config", "--file", config, "filter.review.clean", quote(process.execPath) + " " + quote(clean)]);
    git(repository, ["config", "--file", config, "filter.review.required", "true"]);
    const previous = process.env.GIT_CONFIG_GLOBAL;
    process.env.GIT_CONFIG_GLOBAL = config;
    try {
      const control = path.join(directory, "ordinary-checkout");
      git(repository, ["clone", "--quiet", "--no-hardlinks", repository, control]);
      assert.notDeepEqual(fs.readFileSync(path.join(control, "R/model.R")), originalModel,
        "The independent ordinary checkout must demonstrate the configured transformation");
      assert.equal(stage(repository, output).status, 0);
      const calls = [];
      const runner = (command, args, options) => {
        calls.push({ command, args });
        if (args.includes("--offline")) {
          assert.deepEqual(fs.readFileSync(path.join(options.cwd, "R/model.R")), originalModel);
          if (process.platform !== "win32") assert.ok(fs.statSync(path.join(options.cwd, "R/model.R")).mode & 0o111);
          assert.deepEqual(fs.readFileSync(args[1]), originalGuard);
          return { status: 0, stdout: "repository_state=ready\nrelease_ready=true\nreason_codes=NONE\n", stderr: "" };
        }
        if (args.some((arg) => arg.includes("check-release-urls.R"))) return { status: 0,
          stdout: JSON.stringify({ status: "passed", reason: "URLS_VALIDATED" }), stderr: "" };
        if (command === "Rscript" && args.includes("-e")) return { status: 0,
          stdout: JSON.stringify({ supported: true, reason: "SUPPORTED", matrix_version: "1.6.5", matrix_minimum: "1.6-5" }), stderr: "" };
        if (command === "R" && args[1] === "build") {
          assert.deepEqual(fs.readFileSync(path.join(options.cwd, "R/model.R")), originalModel);
          if (process.platform !== "win32") assert.ok(fs.statSync(path.join(options.cwd, "R/model.R")).mode & 0o111);
          fs.writeFileSync(path.join(options.cwd, "GEModelR_0.1.0.tar.gz"), "fixture archive");
        }
        if (command === "R" && args[1] === "check") {
          const check = args.find((arg) => arg.startsWith("--output=")).slice(9);
          fs.mkdirSync(path.join(check, "GEModelR.Rcheck"), { recursive: true });
          fs.writeFileSync(path.join(check, "GEModelR.Rcheck/00check.log"), cleanR43CheckLog);
        }
        return { status: 0, stdout: command === "Rscript" ? "PASS installed-release-smoke\n" : "", stderr: "" };
      };
      const library = path.join(directory, "library");
      fs.mkdirSync(library);
      require(cli).qualifyReleasePacket({ packet: output, library, runner });
      assert.ok(calls.some((call) => call.command === "R" && call.args[1] === "build"));
    } finally {
      if (previous === undefined) delete process.env.GIT_CONFIG_GLOBAL;
      else process.env.GIT_CONFIG_GLOBAL = previous;
    }
  });
});

function qualificationRunner(calls, options = {}) {
  return (command, args, settings) => {
    calls.push({ command, args });
    if (args.includes("--offline")) return { status: 0,
      stdout: "repository_state=ready\nrelease_ready=true\nreason_codes=NONE\n", stderr: "" };
    if (args.some((arg) => arg.includes("check-release-urls.R"))) {
      if (options.actualDisabledURL) return spawnSync(command, args, { ...settings,
        env: { ...settings.env, _R_CHECK_CRAN_INCOMING_REMOTE_: "false" } });
      return { status: 0, stdout: JSON.stringify(options.url || { status: "passed", reason: "URLS_VALIDATED" }), stderr: "" };
    }
    if (command === "Rscript" && args.includes("-e")) return { status: 0,
      stdout: JSON.stringify({ supported: true, reason: "SUPPORTED", matrix_version: "1.6.5", matrix_minimum: "1.6-5" }), stderr: "" };
    if (command === "R" && args[1] === "build") fs.writeFileSync(path.join(settings.cwd, "GEModelR_0.1.0.tar.gz"), "fixture archive");
    if (command === "R" && args[1] === "check") {
      const directory = args.find((arg) => arg.startsWith("--output=")).slice(9);
      fs.mkdirSync(path.join(directory, "GEModelR.Rcheck"), { recursive: true });
      fs.writeFileSync(path.join(directory, "GEModelR.Rcheck/00check.log"), options.checkLog || cleanR43CheckLog);
    }
    return { status: 0, stdout: command === "Rscript" ? "PASS installed-release-smoke\n" : "", stderr: "" };
  };
}

test("URL failures and unavailable/disabled checks remain separate from a clean R4.3 archive check", () => {
  for (const variant of [
    { url: { status: "failed", reason: "URLS_INVALID" }, expected: "failed" },
    { url: { status: "unavailable", reason: "URL_CHECK_UNAVAILABLE" }, expected: "unavailable" },
    { actualDisabledURL: true, expected: "unavailable" }
  ]) {
    candidateFixture(({ repository, output, directory }) => {
      assert.equal(stage(repository, output).status, 0);
      const calls = [];
      const library = path.join(directory, "library");
      fs.mkdirSync(library);
      require(cli).qualifyReleasePacket({ packet: output, library,
        runner: qualificationRunner(calls, variant) });
      const manifest = JSON.parse(fs.readFileSync(path.join(output, "private/manifest.json")));
      assert.equal(manifest.checks.archive_check, "passed");
      assert.equal(manifest.qualification.url_check_status, variant.expected);
      if (variant.actualDisabledURL) assert.equal(manifest.qualification.url_check_reason, "URL_CHECK_DISABLED");
      assert.equal(manifest.qualification.install_status, "passed");
      assert.equal(manifest.checks.installed_smoke, "passed");
      assert.equal(manifest.qualification_status, variant.expected);
      assert.equal(manifest.publication_readiness, "blocked");
      manifest.qualification.evidence_kind = "actual";
      assert.throws(() => require(cli).validatePublicationReadiness(manifest), { code: "PUBLICATION_NOT_READY" });
      assert.ok(calls.some((item) => item.command === "R" && item.args[1] === "INSTALL"));
    });
  }
});

test("realistic R check warnings cannot advance to installation or acquire URL success", () => {
  candidateFixture(({ repository, output, directory }) => {
    assert.equal(stage(repository, output).status, 0);
    const calls = [];
    const library = path.join(directory, "library");
    fs.mkdirSync(library);
    require(cli).qualifyReleasePacket({ packet: output, library,
      runner: qualificationRunner(calls, { checkLog: cleanR43CheckLog.replace("Status: OK", "Status: 1 WARNING") }) });
    const manifest = JSON.parse(fs.readFileSync(path.join(output, "private/manifest.json")));
    assert.equal(manifest.checks.archive_check, "failed");
    assert.equal(manifest.qualification.url_check_status, "not_run");
    assert.equal(manifest.qualification.install_status, "not_run");
    assert.equal(calls.some((item) => item.command === "R" && item.args[1] === "INSTALL"), false);
    assert.equal(manifest.publication_readiness, "blocked");
  });
});


test("approved informational notes advance with raw counts while unexpected notes block", () => {
  const noteLog = cleanR43CheckLog.replace("* checking CRAN incoming feasibility ... OK",
    "* checking CRAN incoming feasibility ... NOTE\nMaintainer: ‘David Zenz <zenz@wiiw.ac.at>’\n\nNew submission")
    .replace("* DONE", "* checking installed package size ... NOTE\n  installed size is  9.3Mb\n  sub-directories of 1Mb or more:\n    libs   8.1Mb\n* checking for future file timestamps ... NOTE\nunable to verify current time\n* DONE")
    .replace("Status: OK", "Status: 3 NOTEs");
  for (const changed of [false, true]) {
    candidateFixture(({ repository, output, directory }) => {
      assert.equal(stage(repository, output).status, 0);
      const library = path.join(directory, "library");
      fs.mkdirSync(library);
      const calls = [];
      const checkLog = changed ? noteLog.replace("New submission", "New submission\nFound invalid URLs: 404") : noteLog;
      const { qualifyReleasePacket } = require(cli);
      qualifyReleasePacket({ packet: output, library, runner: qualificationRunner(calls, { checkLog }) });
      const manifest = JSON.parse(fs.readFileSync(path.join(output, "private/manifest.json")));
      const assessment = JSON.parse(fs.readFileSync(path.join(output, "private/evidence/archive-check-assessment.json")));
      assert.equal(assessment.notes, 3);
      assert.equal(assessment.status_line, "Status: 3 NOTEs");
      assert.equal(assessment.log_sha256, crypto.createHash("sha256").update(checkLog).digest("hex"));
      assert.equal(assessment.assessor_sha256, crypto.createHash("sha256").update(fs.readFileSync(path.join(output, "private/support/assess-r-cmd-check.cjs"))).digest("hex"));
      assert.equal(manifest.checks.archive_check, changed ? "failed" : "passed");
      assert.equal(manifest.qualification.install_status, changed ? "not_run" : "passed");
      assert.equal(manifest.publication_authorized, false);
    });
  }
});

test("a timed out archive check is retained as a failure without installation", () => {
  candidateFixture(({ repository, output, directory }) => {
    assert.equal(stage(repository, output).status, 0);
    const library = path.join(directory, "library");
    fs.mkdirSync(library);
    const calls = [];
    const base = qualificationRunner(calls);
    const runner = (command, args, options) => {
      const result = base(command, args, options);
      return command === "R" && args[1] === "check" ? { ...result, status: null } : result;
    };
    require(cli).qualifyReleasePacket({ packet: output, library, runner });
    const manifest = JSON.parse(fs.readFileSync(path.join(output, "private/manifest.json")));
    assert.equal(manifest.checks.archive_check, "failed");
    assert.equal(manifest.qualification.install_status, "not_run");
    const assessment = JSON.parse(fs.readFileSync(path.join(output, "private/evidence/archive-check-assessment.json")));
    assert.equal(assessment.exit_status, null);
  });
});
