#!/usr/bin/env node
"use strict";

const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const scannerPath = path.join(__dirname, "../ci/check-public-content.cjs");
const { inspect } = require(scannerPath);
const assessorPath = path.join(__dirname, "../ci/assess-r-cmd-check.cjs");
const urlCheckerPath = path.join(__dirname, "../ci/check-release-urls.R");

const INVENTORY_PATH = "private/manifest.json";
const SMOKE_PATH = "tools/ci/run-installed-release-smoke.R";
const NOTES_PATH = "docs/release/RELEASE-NOTES.md";
const CHECK_NAMES = ["archive_build", "archive_scan", "archive_check", "installed_smoke",
  "github_install", "runiverse_install", "publication"];
const PUBLIC_KEYS = ["schema_version", "source_commit", "source_tree", "package", "version",
  "intended_tag", "tag_type", "preparation_status", "publication_authorized", "public_source_commit",
  "public_source_tree", "source_policy_sha256", "archive_source_commit", "archive_sha256",
  "qualification_status", "publication_readiness", "release_notes_status", "checks"];
const POLICY_PATH = "docs/release/public-source.json";
const LOCAL_REPOSITORIES = ["private/public-source", "private/original-source", "private/work/build-source"];
const OID = /^(?:[0-9a-f]{40}|[0-9a-f]{64})$/;
const SHA256 = /^[0-9a-f]{64}$/;

class ReleaseError extends Error {
  constructor(code) {
    super(code);
    this.code = code;
  }
}

function fail(code) {
  throw new ReleaseError(code);
}

function sha256(bytes) {
  return crypto.createHash("sha256").update(bytes).digest("hex");
}

function bytewise(a, b) {
  return Buffer.compare(Buffer.from(a), Buffer.from(b));
}

function json(value) {
  return JSON.stringify(value, null, 2) + "\n";
}

function within(root, target) {
  const relative = path.relative(root, target);
  return relative === "" || (!relative.startsWith(".." + path.sep) &&
    relative !== ".." && !path.isAbsolute(relative));
}

function git(repository, args, encoding = "utf8", extraEnv = {}) {
  const env = { ...process.env, GIT_TERMINAL_PROMPT: "0" };
  for (const name of Object.keys(env)) {
    if (/^GIT_(?:DIR|WORK_TREE|INDEX_FILE|OBJECT_DIRECTORY|ALTERNATE_OBJECT_DIRECTORIES|CONFIG_COUNT|CONFIG_KEY_\d+|CONFIG_VALUE_\d+)$/.test(name)) {
      delete env[name];
    }
  }
  Object.assign(env, extraEnv);
  const result = spawnSync("git", ["-C", repository, ...args], {
    env, encoding, maxBuffer: 128 * 1024 * 1024, timeout: 30000, windowsHide: true
  });
  if (result.error || result.status !== 0) fail("GIT_READ_FAILED");
  return result.stdout;
}

function safeRelative(name) {
  return typeof name === "string" && name.length > 0 &&
    !/[\\\x00-\x1f\x7f]/.test(name) && !path.posix.isAbsolute(name) &&
    !/^[A-Za-z]:/.test(name) && name.split("/").every((part) =>
      part !== "" && part !== "." && part !== ".." && part.toLowerCase() !== ".git" &&
      !/[<>:"|?*]/.test(part) && !/[. ]$/.test(part) &&
      !/^(?:con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)/i.test(part));
}

function selectedTree(repository, commit) {
  const bytes = git(repository, ["ls-tree", "-r", "-z", "--full-tree", commit], null);
  if (!Buffer.from(bytes.toString("utf8")).equals(bytes)) fail("UNSAFE_SOURCE_ENTRY");
  return bytes.toString("utf8")
    .split("\0").filter(Boolean).map((line) => {
      const match = /^(100644|100755) blob ([0-9a-f]{40,64})\t(.+)$/.exec(line);
      if (!match || !safeRelative(match[3])) fail("UNSAFE_SOURCE_ENTRY");
      return { path: match[3], mode: match[1], oid: match[2] };
    }).sort((a, b) => bytewise(a.path, b.path));
}

function parseDescription(bytes) {
  const text = bytes.toString("utf8");
  const packageFields = [...text.matchAll(/^Package:[ \t]*([^\r\n]+)\r?$/gm)];
  const versionFields = [...text.matchAll(/^Version:[ \t]*([^\r\n]+)\r?$/gm)];
  if (packageFields.length !== 1 || packageFields[0][1].trim() !== "GEModelR" ||
      versionFields.length !== 1) fail("INVALID_PACKAGE_DESCRIPTION");
  const version = versionFields[0][1].trim();
  if (!/^[0-9]+(?:[.-][0-9]+)+$/.test(version)) fail("INVALID_PACKAGE_VERSION");
  return { package: "GEModelR", version };
}

function canonicalOutput(repository, value) {
  if (typeof value !== "string" || !value.trim()) fail("MISSING_OUTPUT");
  const requested = path.resolve(value);
  let parent = requested;
  const suffix = [];
  while (!fs.lstatSync(parent, { throwIfNoEntry: false })) {
    suffix.unshift(path.basename(parent));
    const next = path.dirname(parent);
    if (next === parent) fail("INVALID_OUTPUT");
    parent = next;
  }
  if (fs.lstatSync(parent).isSymbolicLink() &&
      (parent === requested || !fs.existsSync(parent))) fail("OUTPUT_SYMLINK");
  const target = path.join(fs.realpathSync(parent), ...suffix);
  if (within(repository, target) || within(target, repository)) fail("OUTPUT_SOURCE_OVERLAP");
  if (fs.existsSync(target) && (!fs.lstatSync(target).isDirectory() ||
      fs.readdirSync(target).length !== 0)) fail("OUTPUT_NOT_EMPTY");
  return target;
}

function writeFile(root, name, bytes, mode = 0o644) {
  if (!safeRelative(name)) fail("UNSAFE_PACKET_ENTRY");
  const destination = path.join(root, ...name.split("/"));
  fs.mkdirSync(path.dirname(destination), { recursive: true });
  fs.writeFileSync(destination, bytes, { flag: "wx", mode });
}

function inventory(root) {
  const entries = [];
  function visit(directory, relative = "") {
    for (const name of fs.readdirSync(directory).sort(bytewise)) {
      const item = relative ? relative + "/" + name : name;
      if (LOCAL_REPOSITORIES.some((repository) => item === repository + "/.git")) {
        if (!fs.lstatSync(path.join(directory, name)).isDirectory() ||
            fs.lstatSync(path.join(directory, name)).isSymbolicLink()) fail("UNSAFE_PACKET_ENTRY");
        continue;
      }
      if (!safeRelative(item)) fail("UNSAFE_PACKET_ENTRY");
      const absolute = path.join(directory, name);
      const stat = fs.lstatSync(absolute);
      if (stat.isSymbolicLink()) fail("PACKET_SYMLINK");
      if (stat.isDirectory()) visit(absolute, item);
      else if (stat.isFile()) {
        if (item !== INVENTORY_PATH) {
          entries.push({ path: item, size: stat.size, sha256: sha256(fs.readFileSync(absolute)) });
        }
      } else fail("UNSAFE_PACKET_ENTRY");
    }
  }
  visit(root);
  return entries.sort((a, b) => bytewise(a.path, b.path));
}

function readPacketFile(root, relative) {
  if (!safeRelative(relative)) fail("UNSAFE_PACKET_ENTRY");
  let absolute = root;
  const parts = relative.split("/");
  for (let i = 0; i < parts.length; i += 1) {
    absolute = path.join(absolute, parts[i]);
    const stat = fs.lstatSync(absolute);
    if (stat.isSymbolicLink()) fail("PACKET_SYMLINK");
    if (i < parts.length - 1 ? !stat.isDirectory() : !stat.isFile()) fail("UNSAFE_PACKET_ENTRY");
  }
  if (!within(root, fs.realpathSync(absolute))) fail("UNSAFE_PACKET_ENTRY");
  const descriptor = fs.openSync(absolute, fs.constants.O_RDONLY | (fs.constants.O_NOFOLLOW || 0));
  try {
    const stat = fs.fstatSync(descriptor);
    if (!stat.isFile() || stat.size > 128 * 1024 * 1024) fail("UNSAFE_PACKET_ENTRY");
    return fs.readFileSync(descriptor);
  } finally {
    fs.closeSync(descriptor);
  }
}

function exactKeys(value, keys) {
  return value !== null && typeof value === "object" && !Array.isArray(value) &&
    JSON.stringify(Object.keys(value).sort(bytewise)) === JSON.stringify([...keys].sort(bytewise));
}

function sortedUnique(entries) {
  return entries.every((entry, i) => i === 0 || bytewise(entries[i - 1].path, entry.path) < 0);
}

function validateManifest(manifest) {
  if (!exactKeys(manifest, [...PUBLIC_KEYS, "source_entries", "files", "qualification", "content_sha256"]) ||
      manifest.schema_version !== 1 || !OID.test(manifest.source_commit) ||
      !OID.test(manifest.source_tree) || manifest.source_commit.length !== manifest.source_tree.length ||
      manifest.package !== "GEModelR" || !/^[0-9]+(?:[.-][0-9]+)+$/.test(manifest.version) ||
      manifest.intended_tag !== "v" + manifest.version || manifest.tag_type !== "annotated_unsigned" ||
      !["prepared", "complete"].includes(manifest.preparation_status) || manifest.publication_authorized !== false ||
      !(manifest.public_source_commit === "not_created" || OID.test(manifest.public_source_commit)) ||
      !(manifest.public_source_tree === "not_created" || OID.test(manifest.public_source_tree)) ||
      !(manifest.source_policy_sha256 === "not_frozen" || SHA256.test(manifest.source_policy_sha256)) ||
      !(manifest.archive_source_commit === "not_built" || OID.test(manifest.archive_source_commit)) ||
      !(manifest.archive_sha256 === "not_built" || SHA256.test(manifest.archive_sha256)) ||
      !["unqualified", "blocked", "ready"].includes(manifest.publication_readiness) ||
      !["not_run", "unavailable", "failed", "passed"].includes(manifest.qualification_status) ||
      !["ready", "unavailable"].includes(manifest.release_notes_status) ||
      !exactKeys(manifest.checks, CHECK_NAMES) ||
      CHECK_NAMES.some((name) => !["not_run", "passed", "failed"].includes(manifest.checks[name])) ||
      !SHA256.test(manifest.content_sha256) || !Array.isArray(manifest.source_entries) ||
      !manifest.source_entries.length || !Array.isArray(manifest.files) || !manifest.files.length) {
    fail("INVALID_MANIFEST");
  }
  const staged = manifest.public_source_commit !== "not_created";
  if (staged !== (manifest.public_source_tree !== "not_created") ||
      staged !== (manifest.source_policy_sha256 !== "not_frozen") ||
      (staged ? manifest.preparation_status !== "complete" : manifest.preparation_status !== "prepared") ||
      (manifest.qualification === null ? manifest.qualification_status !== "not_run" :
        !validQualification(manifest.qualification)) ||
      (!staged && (manifest.qualification !== null || manifest.publication_readiness !== "unqualified"))) {
    fail("INVALID_MANIFEST");
  }
  if (manifest.source_entries.some((entry) => !exactKeys(entry, ["path", "mode", "oid"]) ||
      !safeRelative(entry.path) || !["100644", "100755"].includes(entry.mode) ||
      !OID.test(entry.oid) || entry.oid.length !== manifest.source_commit.length) ||
      !sortedUnique(manifest.source_entries) ||
      manifest.files.some((entry) => !exactKeys(entry, ["path", "size", "sha256"]) ||
        !safeRelative(entry.path) || entry.path === INVENTORY_PATH ||
        !Number.isSafeInteger(entry.size) || entry.size < 0 || !SHA256.test(entry.sha256)) ||
      !sortedUnique(manifest.files)) fail("INVALID_MANIFEST");
}

function gitObjectHash(type, bytes, algorithm) {
  return crypto.createHash(algorithm).update(type + " " + bytes.length + "\0").update(bytes).digest("hex");
}

function verifySourceIdentity(root, manifest) {
  const algorithm = manifest.source_commit.length === 40 ? "sha1" : "sha256";
  const commit = readPacketFile(root, "private/support/source-commit.txt");
  if (gitObjectHash("commit", commit, algorithm) !== manifest.source_commit ||
      !commit.toString("utf8").startsWith("tree " + manifest.source_tree + "\n")) {
    fail("SOURCE_IDENTITY_MISMATCH");
  }
  const tree = new Map();
  for (const entry of manifest.source_entries) {
    const bytes = readPacketFile(root, "private/source/" + entry.path);
    if (gitObjectHash("blob", bytes, algorithm) !== entry.oid) fail("SOURCE_IDENTITY_MISMATCH");
    const parts = entry.path.split("/");
    const name = parts.pop();
    let current = tree;
    for (const part of parts) {
      if (!current.has(part)) current.set(part, new Map());
      current = current.get(part);
      if (!(current instanceof Map)) fail("INVALID_MANIFEST");
    }
    if (current.has(name)) fail("INVALID_MANIFEST");
    current.set(name, entry);
  }
  function treeHash(items) {
    const sorted = [...items.entries()].sort(([a, av], [b, bv]) =>
      bytewise(a + (av instanceof Map ? "/" : ""), b + (bv instanceof Map ? "/" : "")));
    const body = Buffer.concat(sorted.map(([name, value]) => {
      const directory = value instanceof Map;
      const oid = directory ? treeHash(value) : value.oid;
      return Buffer.concat([Buffer.from((directory ? "40000" : value.mode) + " " + name + "\0"),
        Buffer.from(oid, "hex")]);
    }));
    return gitObjectHash("tree", body, algorithm);
  }
  if (treeHash(tree) !== manifest.source_tree) fail("SOURCE_IDENTITY_MISMATCH");
  const metadata = parseDescription(readPacketFile(root, "private/source/DESCRIPTION"));
  if (metadata.version !== manifest.version) fail("SOURCE_IDENTITY_MISMATCH");
  const actualSource = manifest.files.filter((entry) => entry.path.startsWith("private/source/"))
    .map((entry) => entry.path.slice("private/source/".length));
  if (JSON.stringify(actualSource) !== JSON.stringify(manifest.source_entries.map((entry) => entry.path))) {
    fail("SOURCE_IDENTITY_MISMATCH");
  }
}

function scanPublic(directory) {
  try {
    if (inspect("--artifact-dir", directory).violations.length) fail("PUBLIC_CONTENT_REJECTED");
  } catch (error) {
    if (error instanceof ReleaseError) throw error;
    fail("PUBLIC_CONTENT_REJECTED");
  }
}

function prepareReleasePacket(options) {
  if (typeof options.sourceRef !== "string" || !options.sourceRef.trim() ||
      options.sourceRef.startsWith("-") || /[\x00-\x1f\x7f]/.test(options.sourceRef)) {
    fail("INVALID_SOURCE_REF");
  }
  if (typeof options.tag !== "string" || !/^v[0-9]+(?:[.-][0-9]+)+$/.test(options.tag)) {
    fail("INVALID_TAG");
  }
  const repository = fs.realpathSync(git(options.repository || process.cwd(),
    ["rev-parse", "--show-toplevel"]).trim());
  const commit = git(repository, ["rev-parse", "--verify", "--end-of-options",
    options.sourceRef + "^{commit}"]).trim();
  const tree = git(repository, ["rev-parse", commit + "^{tree}"]).trim();
  const files = selectedTree(repository, commit);
  const description = files.find((entry) => entry.path === "DESCRIPTION");
  const smoke = files.find((entry) => entry.path === SMOKE_PATH);
  if (!description) fail("MISSING_PACKAGE_DESCRIPTION");
  if (!smoke) fail("MISSING_SELECTED_SMOKE");
  const metadata = parseDescription(git(repository, ["cat-file", "blob", description.oid], null));
  if (options.tag !== "v" + metadata.version) fail("TAG_VERSION_MISMATCH");
  const tags = git(repository, ["tag", "--list", options.tag]).trim();
  if (tags && git(repository, ["rev-parse", "refs/tags/" + options.tag + "^{commit}"]).trim() !== commit) {
    fail("TAG_SOURCE_CONFLICT");
  }
  const output = canonicalOutput(repository, options.output);
  fs.mkdirSync(path.dirname(output), { recursive: true });
  const staging = fs.mkdtempSync(path.join(path.dirname(output), ".gemodelr-release-"));
  try {
    for (const entry of files) {
      writeFile(staging, "private/source/" + entry.path,
        git(repository, ["cat-file", "blob", entry.oid], null),
        entry.mode === "100755" ? 0o755 : 0o644);
    }
    writeFile(staging, "private/support/prepare-release.cjs", fs.readFileSync(__filename));
    writeFile(staging, "private/support/check-public-content.cjs", fs.readFileSync(scannerPath));
    writeFile(staging, "private/support/assess-r-cmd-check.cjs", fs.readFileSync(assessorPath));
    writeFile(staging, "private/support/check-release-urls.R", fs.readFileSync(urlCheckerPath));
    writeFile(staging, "private/support/source-commit.txt", git(repository, ["cat-file", "commit", commit], null));
    writeFile(staging, "private/support/source-origin.txt", repository);
    writeFile(staging, "public/run-installed-release-smoke.R",
      fs.readFileSync(path.join(staging, "private/source", SMOKE_PATH)));
    writeFile(staging, "public/registry/packages.json", json([{
      package: "GEModelR", url: "https://github.com/DavidZenz/GEModelR", branch: options.tag
    }]));
    const notes = files.find((entry) => entry.path === NOTES_PATH);
    if (notes) writeFile(staging, "public/RELEASE-NOTES.md",
      fs.readFileSync(path.join(staging, "private/source", NOTES_PATH)));
    const publicManifest = {
      schema_version: 1, source_commit: commit, source_tree: tree, ...metadata,
      intended_tag: options.tag, tag_type: "annotated_unsigned", preparation_status: "prepared",
      publication_authorized: false, public_source_commit: "not_created",
      public_source_tree: "not_created", source_policy_sha256: "not_frozen",
      archive_source_commit: "not_built", archive_sha256: "not_built", qualification_status: "not_run",
      publication_readiness: "unqualified", release_notes_status: notes ? "ready" : "unavailable",
      checks: Object.fromEntries(CHECK_NAMES.map((name) => [name, "not_run"]))
    };
    writeFile(staging, "public/manifest.json", json(publicManifest));
    scanPublic(path.join(staging, "public"));
    const manifest = { ...publicManifest, source_entries: files, files: inventory(staging), qualification: null };
    manifest.content_sha256 = sha256(json(manifest));
    writeFile(staging, INVENTORY_PATH, json(manifest));
    if (fs.existsSync(output)) fs.rmdirSync(output);
    fs.renameSync(staging, output);
    return { status: "prepared", source_commit: commit, content_sha256: manifest.content_sha256 };
  } finally {
    fs.rmSync(staging, { recursive: true, force: true });
  }
}

function readVerifiedPacket(options) {
  if (typeof options.packet !== "string" || !options.packet.trim()) fail("MISSING_PACKET");
  const requested = path.resolve(options.packet);
  if (fs.lstatSync(requested).isSymbolicLink()) fail("PACKET_SYMLINK");
  const root = fs.realpathSync(requested);
  const contents = readPacketFile(root, INVENTORY_PATH).toString("utf8");
  let manifest;
  try { manifest = JSON.parse(contents); } catch { fail("INVALID_MANIFEST"); }
  validateManifest(manifest);
  const expected = { ...manifest };
  delete expected.content_sha256;
  if (manifest.content_sha256 !== sha256(json(expected))) fail("MANIFEST_CHANGED");
  if (JSON.stringify(manifest.files) !== JSON.stringify(inventory(root))) fail("PACKET_CONTENT_CHANGED");
  verifySourceIdentity(root, manifest);
  let publicManifest;
  try { publicManifest = JSON.parse(readPacketFile(root, "public/manifest.json")); }
  catch (error) {
    if (error instanceof ReleaseError) throw error;
    fail("INVALID_MANIFEST");
  }
  if (!exactKeys(publicManifest, PUBLIC_KEYS) ||
      PUBLIC_KEYS.some((name) => JSON.stringify(manifest[name]) !== JSON.stringify(publicManifest[name]))) {
    fail("PUBLIC_MANIFEST_MISMATCH");
  }
  scanPublic(path.join(root, "public"));
  if (manifest.public_source_commit !== "not_created") verifyPublicSource(root, manifest);
  return { root, manifest };
}

function verifyReleasePacket(options) {
  const { manifest } = readVerifiedPacket(options);
  if (options.forPublication) validatePublicationReadiness(manifest);
  return { status: "verified", source_commit: manifest.source_commit,
    public_source_commit: manifest.public_source_commit, content_sha256: manifest.content_sha256 };
}

function publicValues(manifest) {
  return Object.fromEntries(PUBLIC_KEYS.map((name) => [name, manifest[name]]));
}

function saveManifest(root, manifest) {
  fs.writeFileSync(path.join(root, "public/manifest.json"), json(publicValues(manifest)));
  scanPublic(path.join(root, "public"));
  manifest.files = inventory(root);
  delete manifest.content_sha256;
  manifest.content_sha256 = sha256(json(manifest));
  const temporary = path.join(root, "private/manifest.json.next");
  fs.writeFileSync(temporary, json(manifest), { flag: "wx" });
  fs.renameSync(temporary, path.join(root, INVENTORY_PATH));
}

function sourcePolicy(root, manifest) {
  let policy;
  const bytes = readPacketFile(root, "private/source/" + POLICY_PATH);
  try { policy = JSON.parse(bytes); } catch { fail("INVALID_SOURCE_POLICY"); }
  if (!exactKeys(policy, ["schema_version", "include", "exclude"]) ||
      policy.schema_version !== 1 || !Array.isArray(policy.include) || !policy.include.length ||
      !Array.isArray(policy.exclude) || policy.include.some((name) => !safeRelative(name)) ||
      policy.exclude.some((entry) => !exactKeys(entry, ["path", "reason"]) ||
        !safeRelative(entry.path) || typeof entry.reason !== "string" || !entry.reason.trim())) {
    fail("INVALID_SOURCE_POLICY");
  }
  const names = [...policy.include, ...policy.exclude.map((entry) => entry.path)].sort(bytewise);
  if (names.some((name, i) => i > 0 && name === names[i - 1]) ||
      JSON.stringify(names) !== JSON.stringify(manifest.source_entries.map((entry) => entry.path))) {
    fail("SOURCE_POLICY_INCOMPLETE");
  }
  if (policy.include.some((name) => /^(?:\.planning|\.codex|\.claude|\.agents|\.aws|\.ssh|\.gsd)(?:\/|$)/i.test(name) ||
      /^docs\/(?:release|provenance)(?:\/|$)/i.test(name) || /(?:^|\/)(?:\.RData|\.Rhistory|\.Renviron)$/i.test(name))) {
    fail("PRIVATE_SOURCE_INCLUDED");
  }
  for (const name of ["DESCRIPTION", SMOKE_PATH]) {
    if (!policy.include.includes(name)) fail("MISSING_PUBLIC_SOURCE");
  }
  // Package implementation and notices cannot be silently dropped by a projection.
  for (const entry of manifest.source_entries) {
    if (/^(?:R|src)\//.test(entry.path) ||
        /^(?:LICENSE(?:\.[^/]+)?|COPYING|CONTRIBUTORS\.md|inst\/CITATION)$/.test(entry.path)) {
      if (!policy.include.includes(entry.path)) fail("MISSING_PUBLIC_SOURCE");
    }
  }
  return { policy, digest: sha256(bytes) };
}

function verifyPublicSource(root, manifest) {
  const { policy, digest } = sourcePolicy(root, manifest);
  if (digest !== manifest.source_policy_sha256) fail("SOURCE_POLICY_CHANGED");
  const repository = path.join(root, "private/public-source");
  readPacketFile(root, "private/public-source/DESCRIPTION");
  if (!fs.lstatSync(path.join(repository, ".git")).isDirectory() ||
      fs.lstatSync(path.join(repository, ".git")).isSymbolicLink() ||
      git(repository, ["rev-parse", "HEAD"]).trim() !== manifest.public_source_commit ||
      git(repository, ["rev-parse", "HEAD^{tree}"]).trim() !== manifest.public_source_tree ||
      git(repository, ["rev-list", "--count", "--all"]).trim() !== "1" ||
      git(repository, ["remote"]).trim() !== "") {
    fail("PUBLIC_SOURCE_IDENTITY_MISMATCH");
  }
  const refs = git(repository, ["for-each-ref", "--format=%(refname)"]).trim().split("\n").filter(Boolean);
  if (refs.some((ref) => !["refs/heads/main", "refs/tags/" + manifest.intended_tag].includes(ref))) {
    fail("PUBLIC_SOURCE_IDENTITY_MISMATCH");
  }
  if (refs.includes("refs/tags/" + manifest.intended_tag) &&
      git(repository, ["rev-parse", "refs/tags/" + manifest.intended_tag + "^{commit}"]).trim() !== manifest.public_source_commit) {
    fail("TAG_SOURCE_CONFLICT");
  }
  const expected = manifest.source_entries.filter((entry) => policy.include.includes(entry.path));
  if (JSON.stringify(selectedTree(repository, manifest.public_source_commit)) !== JSON.stringify(expected)) {
    fail("PUBLIC_SOURCE_IDENTITY_MISMATCH");
  }
  for (const entry of expected) {
    if (!readPacketFile(root, "private/public-source/" + entry.path)
      .equals(readPacketFile(root, "private/source/" + entry.path))) fail("PUBLIC_SOURCE_IDENTITY_MISMATCH");
  }
}

function stagePublicSource(options) {
  const { root, manifest } = readVerifiedPacket(options);
  if (manifest.public_source_commit !== "not_created") fail("PUBLIC_SOURCE_ALREADY_STAGED");
  const { policy, digest } = sourcePolicy(root, manifest);
  const repository = path.join(root, "private/public-source");
  const hooks = path.join(root, "private/support/empty-hooks");
  fs.mkdirSync(hooks, { recursive: true });
  fs.mkdirSync(repository);
  try {
    const algorithm = manifest.source_commit.length === 40 ? "sha1" : "sha256";
    // SHA-1 is Git's original format; avoid newer init options on older clients.
    git(repository, ["init", "--quiet", ...(algorithm === "sha256" ? ["--object-format=sha256"] : [])]);
    git(repository, ["symbolic-ref", "HEAD", "refs/heads/main"]);
    for (const entry of manifest.source_entries.filter((item) => policy.include.includes(item.path))) {
      writeFile(repository, entry.path, readPacketFile(root, "private/source/" + entry.path),
        entry.mode === "100755" ? 0o755 : 0o644);
      const oid = git(repository, ["hash-object", "-w", "--no-filters", "--", entry.path]).trim();
      if (oid !== entry.oid) fail("PUBLIC_SOURCE_IDENTITY_MISMATCH");
      git(repository, ["update-index", "--add", "--cacheinfo", entry.mode + "," + oid + "," + entry.path]);
    }
    const commitText = readPacketFile(root, "private/support/source-commit.txt").toString("utf8");
    const date = /^committer .* ([0-9]+ [+-][0-9]{4})$/m.exec(commitText);
    if (!date) fail("SOURCE_IDENTITY_MISMATCH");
    git(repository, ["-c", "core.hooksPath=" + hooks, "-c", "commit.gpgsign=false", "commit", "--quiet",
      "-m", "GEModelR " + manifest.version + " proposed public source\n\nDevelopment source: " + manifest.source_commit], "utf8", {
      GIT_AUTHOR_NAME: "GEModelR release preparation", GIT_AUTHOR_EMAIL: "release-preparation@example.invalid",
      GIT_COMMITTER_NAME: "GEModelR release preparation", GIT_COMMITTER_EMAIL: "release-preparation@example.invalid",
      GIT_AUTHOR_DATE: date[1], GIT_COMMITTER_DATE: date[1]
    });
    manifest.public_source_commit = git(repository, ["rev-parse", "HEAD"]).trim();
    manifest.public_source_tree = git(repository, ["rev-parse", "HEAD^{tree}"]).trim();
    manifest.source_policy_sha256 = digest;
    manifest.preparation_status = "complete";
    manifest.publication_readiness = "blocked";
    writeFile(root, "private/support/public-reachable-objects.txt", git(repository, ["rev-list", "--objects", "--all"]));
    verifyPublicSource(root, manifest);
    saveManifest(root, manifest);
    return { status: "staged", public_source_commit: manifest.public_source_commit,
      public_source_tree: manifest.public_source_tree, review_sha256: manifest.content_sha256 };
  } catch (error) {
    fs.rmSync(repository, { recursive: true, force: true });
    fs.rmSync(path.join(root, "private/support/public-reachable-objects.txt"), { force: true });
    throw error;
  }
}

function validQualification(value) {
  const keys = ["evidence_kind", "runtime", "guard", "install_status", "archive_check_status", "reason_codes"];
  const legacy = exactKeys(value, keys);
  return (legacy || exactKeys(value, [...keys, "url_check_status", "url_check_reason"])) &&
    ["actual", "fixture"].includes(value.evidence_kind) &&
    exactKeys(value.runtime, ["supported", "reason", "matrix_version", "matrix_minimum"]) &&
    typeof value.runtime.supported === "boolean" && /^[A-Z0-9_]+$/.test(value.runtime.reason) &&
    /^(?:[0-9]+(?:[.-][0-9]+)+|unavailable)$/.test(value.runtime.matrix_version) &&
    /^[0-9]+(?:[.-][0-9]+)+$/.test(value.runtime.matrix_minimum) &&
    exactKeys(value.guard, ["status", "exit_status", "reason_codes"]) &&
    ["passed", "blocked", "invalid", "failed", "unavailable"].includes(value.guard.status) &&
    (value.guard.exit_status === null || Number.isInteger(value.guard.exit_status)) &&
    Array.isArray(value.guard.reason_codes) && value.guard.reason_codes.every((code) => /^[A-Z0-9_]+$/.test(code)) &&
    ["not_run", "passed", "failed"].includes(value.install_status) &&
    ["not_run", "passed", "failed"].includes(value.archive_check_status) &&
    (legacy || (["not_run", "passed", "failed", "unavailable", "not_applicable"].includes(value.url_check_status) &&
      /^[A-Z0-9_]+$/.test(value.url_check_reason))) &&
    Array.isArray(value.reason_codes) && value.reason_codes.every((code) => /^[A-Z0-9_]+$/.test(code));
}

function validatePublicationReadiness(manifest) {
  const qualification = manifest.qualification;
  const archive = manifest.files?.find((entry) =>
    entry.path === "public/" + manifest.package + "_" + manifest.version + ".tar.gz");
  if (!qualification || !validQualification(qualification) || qualification.evidence_kind !== "actual" ||
      !qualification.runtime.supported || qualification.guard.status !== "passed" ||
      qualification.guard.exit_status !== 0 || qualification.guard.reason_codes.length ||
      qualification.reason_codes.length || qualification.install_status !== "passed" ||
      qualification.archive_check_status !== "passed" || manifest.qualification_status !== "passed" ||
      !((qualification.url_check_status === "passed" && qualification.url_check_reason === "URLS_VALIDATED") ||
        (qualification.url_check_status === "not_applicable" && qualification.url_check_reason === "NO_URLS")) ||
      !OID.test(manifest.public_source_commit) || !OID.test(manifest.public_source_tree) ||
      !SHA256.test(manifest.source_policy_sha256) || !SHA256.test(manifest.archive_sha256) ||
      !archive || archive.sha256 !== manifest.archive_sha256 ||
      manifest.archive_source_commit !== manifest.public_source_commit || manifest.release_notes_status !== "ready" ||
      ["archive_build", "archive_scan", "archive_check", "installed_smoke"].some((name) => manifest.checks[name] !== "passed")) {
    fail("PUBLICATION_NOT_READY");
  }
  return true;
}

function updatePublicationReadiness(root, manifest) {
  // Include newly produced assets before assessing them. saveManifest refreshes
  // this inventory again after writing the final public manifest.
  manifest.files = inventory(root);
  manifest.publication_readiness = "blocked";
  try { validatePublicationReadiness(manifest); manifest.publication_readiness = "ready"; }
  catch (error) { if (!(error instanceof ReleaseError)) throw error; }
  return manifest.publication_readiness;
}

function verifyCheckoutBytes(repository, commit) {
  const entries = selectedTree(repository, commit);
  const names = [];
  function visit(directory, prefix = "") {
    for (const name of fs.readdirSync(directory)) {
      if (!prefix && name === ".git") {
        if (!fs.lstatSync(path.join(directory, name)).isDirectory() ||
            fs.lstatSync(path.join(directory, name)).isSymbolicLink()) fail("CHECKOUT_CONTENT_MISMATCH");
        continue;
      }
      const relative = prefix ? prefix + "/" + name : name;
      if (!safeRelative(relative)) fail("CHECKOUT_CONTENT_MISMATCH");
      const stat = fs.lstatSync(path.join(directory, name));
      if (stat.isSymbolicLink()) fail("CHECKOUT_CONTENT_MISMATCH");
      if (stat.isDirectory()) visit(path.join(directory, name), relative);
      else if (stat.isFile()) names.push(relative);
      else fail("CHECKOUT_CONTENT_MISMATCH");
    }
  }
  visit(repository);
  if (JSON.stringify(names.sort(bytewise)) !== JSON.stringify(entries.map((entry) => entry.path))) {
    fail("CHECKOUT_CONTENT_MISMATCH");
  }
  const algorithm = commit.length === 40 ? "sha1" : "sha256";
  for (const entry of entries) {
    const file = path.join(repository, ...entry.path.split("/"));
    const bytes = fs.readFileSync(file);
    const executable = (fs.statSync(file).mode & 0o111) !== 0;
    if (gitObjectHash("blob", bytes, algorithm) !== entry.oid ||
        (process.platform !== "win32" && executable !== (entry.mode === "100755"))) {
      fail("CHECKOUT_CONTENT_MISMATCH");
    }
  }
}

function selectedClone(root, source, destination, commit) {
  const hooks = path.join(root, "private/support/empty-hooks");
  const config = path.join(root, "private/support/empty-git-config");
  if (!fs.existsSync(config)) writeFile(root, "private/support/empty-git-config", "");
  const env = { GIT_CONFIG_NOSYSTEM: "1", GIT_CONFIG_GLOBAL: config, GIT_TEMPLATE_DIR: hooks };
  git(root, ["-c", "core.hooksPath=" + hooks, "clone", "--quiet", "--template=" + hooks,
    "--no-hardlinks", "--no-checkout", "--no-tags", "--", source, destination], "utf8", env);
  git(destination, ["-c", "core.hooksPath=" + hooks, "-c", "core.autocrlf=false", "checkout", "--quiet", "--detach", commit, "--"], "utf8", env);
  git(destination, ["remote", "remove", "origin"], "utf8", env);
  // Tracked attributes can still request EOL/ident conversion. Replace checkout
  // output with raw committed blobs and verify the actual source before use.
  for (const entry of selectedTree(destination, commit)) {
    const file = path.join(destination, ...entry.path.split("/"));
    const bytes = git(destination, ["cat-file", "blob", entry.oid], null, env);
    fs.writeFileSync(file, bytes);
    fs.chmodSync(file, entry.mode === "100755" ? 0o755 : 0o644);
  }
  verifyCheckoutBytes(destination, commit);
}

function runtimeProbeCode() {
  return [
    'args = commandArgs(TRUE); .libPaths(c(args[[1]], .Library));',
    'description = read.dcf(args[[2]]); imports = strsplit(description[1,"Imports"], ",", fixed=TRUE)[[1]];',
    'declaration = trimws(imports)[grepl("^Matrix($|[[:space:](])", trimws(imports))];',
    'floor = "1.6-5"; if(length(declaration)==1 && grepl(">=", declaration)) floor = sub(".*>=[[:space:]]*([0-9.-]+).*", "\\\\1", declaration);',
    'v = tryCatch(as.character(packageVersion("Matrix")), error=function(e) "unavailable");',
    'ok = v != "unavailable" && package_version(v) >= package_version("1.6-5") && package_version(v) >= package_version(floor);',
    'cat(sprintf("{\\"supported\\":%s,\\"reason\\":\\"%s\\",\\"matrix_version\\":\\"%s\\",\\"matrix_minimum\\":\\"%s\\"}",',
    'if(ok) "true" else "false", if(ok) "SUPPORTED" else if(v=="unavailable") "MISSING_MATRIX" else "MATRIX_BELOW_FLOOR", v, floor));'
  ].join("\n");
}


function qualifyReleasePacket(options) {
  const { root, manifest } = readVerifiedPacket(options);
  if (manifest.public_source_commit === "not_created") fail("PUBLIC_SOURCE_NOT_STAGED");
  if (manifest.qualification !== null) fail("QUALIFICATION_ALREADY_RECORDED");
  if (typeof options.library !== "string" || !options.library.trim() ||
      !fs.existsSync(options.library) || !fs.statSync(options.library).isDirectory()) fail("MISSING_SELECTED_LIBRARY");
  const library = fs.realpathSync(options.library);
  const evidence = path.join(root, "private/evidence");
  const work = path.join(root, "private/work");
  fs.mkdirSync(evidence);
  fs.mkdirSync(work);
  const runner = options.runner || spawnSync;
  const qualification = {
    evidence_kind: options.runner ? "fixture" : "actual",
    runtime: { supported: false, reason: "RUNTIME_PROBE_FAILED", matrix_version: "unavailable", matrix_minimum: "1.6-5" },
    guard: { status: "unavailable", exit_status: null, reason_codes: ["GUARD_UNAVAILABLE"] },
    install_status: "not_run", archive_check_status: "not_run", url_check_status: "not_run",
    url_check_reason: "NOT_RUN", reason_codes: []
  };
  const env = { ...process.env, R_LIBS_USER: library, R_LIBS_SITE: "" };
  function command(name, args, cwd, label, extraEnv = {}) {
    const result = runner(name, args, { cwd, encoding: "utf8", maxBuffer: 128 * 1024 * 1024,
      timeout: label === "archive-check" ? 1800000 : 300000,
      windowsHide: true, env: { ...env, ...extraEnv } });
    fs.writeFileSync(path.join(evidence, label + ".stdout.log"), result.stdout || "");
    fs.writeFileSync(path.join(evidence, label + ".stderr.log"), result.stderr || "");
    fs.writeFileSync(path.join(evidence, label + ".exit.txt"), String(result.status ?? "unavailable") + "\n");
    return result;
  }
  // Inspect already-installed prerequisites before any package build, check or install.
  const probe = command("Rscript", ["--vanilla", "-e", runtimeProbeCode(), library,
    path.join(root, "private/source/DESCRIPTION")], work, "runtime");
  try {
    const runtime = JSON.parse(probe.stdout);
    if (probe.status === 0 && validQualification({ ...qualification, runtime })) qualification.runtime = runtime;
  } catch { /* Raw output remains private; never copy unknown values into reports. */ }
  const original = path.join(root, "private/original-source");
  const source = readPacketFile(root, "private/support/source-origin.txt").toString("utf8");
  if (!path.isAbsolute(source)) fail("INVALID_SOURCE_ORIGIN");
  selectedClone(root, source, original, manifest.source_commit);
  if (git(original, ["rev-parse", "HEAD^{tree}"]).trim() !== manifest.source_tree) fail("SOURCE_IDENTITY_MISMATCH");
  writeFile(root, "private/support/original-reachable-objects.txt", git(original, ["rev-list", "--objects", "--all"]));
  const guardScript = path.join(original, "tools/check_release_gates.R");
  if (fs.existsSync(guardScript)) {
    verifyCheckoutBytes(original, manifest.source_commit);
    const guard = command("Rscript", ["--vanilla", guardScript, "--root", original, "--offline"], original, "release-guard");
    const state = /^repository_state=(eligible|ready|blocked|invalid)$/m.exec(guard.stdout || "");
    const ready = /^release_ready=true$/m.test(guard.stdout || "");
    const reasons = /^reason_codes=([A-Z0-9_,]+)$/m.exec(guard.stdout || "");
    const codes = reasons ? (reasons[1] === "NONE" ? [] : reasons[1].split(",")) : ["GUARD_OUTPUT_INVALID"];
    qualification.guard = { status: guard.status === 0 && ["eligible", "ready"].includes(state?.[1]) && ready && !codes.length ? "passed" :
      state?.[1] === "blocked" ? "blocked" : state?.[1] === "invalid" ? "invalid" : "failed",
    exit_status: Number.isInteger(guard.status) ? guard.status : null, reason_codes: codes };
  }
  if (!qualification.runtime.supported) {
    manifest.qualification_status = "unavailable";
    qualification.reason_codes.push(qualification.runtime.reason);
  } else {
    const buildSource = path.join(work, "build-source");
    selectedClone(root, path.join(root, "private/public-source"), buildSource, manifest.public_source_commit);
    if (git(buildSource, ["rev-parse", "HEAD^{tree}"]).trim() !== manifest.public_source_tree) fail("PUBLIC_SOURCE_IDENTITY_MISMATCH");
    verifyCheckoutBytes(buildSource, manifest.public_source_commit);
    const build = command("R", ["CMD", "build", buildSource], buildSource, "archive-build");
    const basename = manifest.package + "_" + manifest.version + ".tar.gz";
    const built = path.join(buildSource, basename);
    manifest.checks.archive_build = build.status === 0 && fs.existsSync(built) && fs.lstatSync(built).isFile() ? "passed" : "failed";
    if (manifest.checks.archive_build === "passed") {
      const archive = path.join(root, "public", basename);
      fs.renameSync(built, archive);
      manifest.archive_source_commit = manifest.public_source_commit;
      manifest.archive_sha256 = sha256(fs.readFileSync(archive));
      const scan = command(process.execPath, [path.join(root, "private/support/check-public-content.cjs"), "--archive", archive], work, "archive-scan");
      manifest.checks.archive_scan = scan.status === 0 ? "passed" : "failed";
      if (manifest.checks.archive_scan === "passed") {
        const checkDirectory = path.join(work, "check");
        const installLibrary = path.join(work, "library");
        fs.mkdirSync(checkDirectory);
        fs.mkdirSync(installLibrary);
        const check = command("R", ["CMD", "check", "--as-cran", "--library=" + installLibrary,
          "--output=" + checkDirectory, archive], work, "archive-check");
        const checkLogPath = path.join(checkDirectory, manifest.package + ".Rcheck/00check.log");
        const checkLog = fs.existsSync(checkLogPath) ? fs.readFileSync(checkLogPath, "utf8") : "";
        const { assessCheckLog } = require(path.join(root, "private/support/assess-r-cmd-check.cjs"));
        const assessment = assessCheckLog(checkLog, check.status);
        fs.writeFileSync(path.join(evidence, "archive-check-assessment.json"), json(assessment));
        manifest.checks.archive_check = assessment.assessment_status;
        qualification.archive_check_status = manifest.checks.archive_check;
        if (manifest.checks.archive_check === "passed") {
          // R 4.3 reports URL work within CRAN incoming feasibility, without a
          // standalone URL log step. Retain separate URL evidence rather than
          // infer a network result from that general check status.
          const urls = command("Rscript", ["--vanilla", path.join(root, "private/support/check-release-urls.R"), buildSource], work, "url-check");
          qualification.url_check_status = "unavailable";
          qualification.url_check_reason = "URL_CHECK_UNAVAILABLE";
          try {
            const result = JSON.parse(urls.stdout);
            if ((urls.status === 0 || ["failed", "unavailable"].includes(result.status)) && exactKeys(result, ["status", "reason"]) &&
                ["passed", "failed", "unavailable", "not_applicable"].includes(result.status) && /^[A-Z0-9_]+$/.test(result.reason)) {
              qualification.url_check_status = result.status;
              qualification.url_check_reason = result.reason;
            }
          } catch { /* Unavailable URL evidence cannot become a network pass. */ }
          const install = command("R", ["CMD", "INSTALL", "--library=" + installLibrary, archive], work, "archive-install");
          qualification.install_status = install.status === 0 ? "passed" : "failed";
          if (install.status === 0) {
            const smoke = command("Rscript", ["--vanilla", path.join(root, "public/run-installed-release-smoke.R")], work, "installed-smoke", {
              GEModelR_TEST_LIBRARY: installLibrary, GEModelR_EXPECTED_VERSION: manifest.version,
              GEModelR_DISTRIBUTION_CHANNEL: "local", GEModelR_EXPECTED_SOURCE_COMMIT: manifest.public_source_commit
            });
            manifest.checks.installed_smoke = smoke.status === 0 && /^PASS installed-release-smoke$/m.test(smoke.stdout || "") ? "passed" : "failed";
          }
        }
      }
    }
    manifest.qualification_status = ["archive_build", "archive_scan", "archive_check", "installed_smoke"]
      .every((name) => manifest.checks[name] === "passed") ? "passed" : "failed";
    if (manifest.qualification_status !== "passed") qualification.reason_codes.push("ARCHIVE_QUALIFICATION_FAILED");
    else if (qualification.url_check_status === "failed") {
      manifest.qualification_status = "failed";
      qualification.reason_codes.push("URL_CHECK_FAILED");
    } else if (!["passed", "not_applicable"].includes(qualification.url_check_status)) {
      manifest.qualification_status = "unavailable";
      qualification.reason_codes.push("URL_CHECK_UNAVAILABLE");
    }
  }
  manifest.qualification = qualification;
  // Recheck selected bytes and refresh the asset inventory before readiness.
  verifyPublicSource(root, manifest);
  updatePublicationReadiness(root, manifest);
  saveManifest(root, manifest);
  return { status: "qualified", qualification_status: manifest.qualification_status,
    publication_readiness: manifest.publication_readiness, public_source_commit: manifest.public_source_commit,
    review_sha256: manifest.content_sha256 };
}

function main(argv) {
  const command = argv[0];
  const allowed = command === "prepare" ? ["--source-ref", "--output", "--tag"] :
    command === "qualify" ? ["--packet", "--library"] :
    ["verify", "stage-public-source"].includes(command) ? ["--packet"] : [];
  if (!allowed.length) fail("INVALID_COMMAND");
  const values = {};
  let forPublication = false;
  for (let i = 1; i < argv.length; i += 1) {
    const flag = argv[i];
    if (flag === "--for-publication" && command === "verify" && !forPublication) {
      forPublication = true;
      continue;
    }
    if (!allowed.includes(flag) || flag in values || typeof argv[i + 1] !== "string" ||
        argv[i + 1].startsWith("--")) fail("INVALID_ARGUMENTS");
    values[flag] = argv[++i];
  }
  const result = command === "prepare" ? prepareReleasePacket({
    sourceRef: values["--source-ref"], output: values["--output"], tag: values["--tag"]
  }) : command === "stage-public-source" ? stagePublicSource({ packet: values["--packet"] }) :
    command === "qualify" ? qualifyReleasePacket({ packet: values["--packet"], library: values["--library"] }) :
      verifyReleasePacket({ packet: values["--packet"], forPublication });
  process.stdout.write(json(result));
}

if (require.main === module) {
  try { main(process.argv.slice(2)); }
  catch (error) {
    process.stderr.write("FAIL " + (error instanceof ReleaseError ? error.code : "PACKET_IO_FAILED") + "\n");
    process.exitCode = 1;
  }
}

module.exports = { prepareReleasePacket, verifyReleasePacket, stagePublicSource,
  qualifyReleasePacket, validatePublicationReadiness, updatePublicationReadiness };
