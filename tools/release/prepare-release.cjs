#!/usr/bin/env node
"use strict";

const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const scannerPath = path.join(__dirname, "../ci/check-public-content.cjs");
const { inspect } = require(scannerPath);

const INVENTORY_PATH = "private/manifest.json";
const SMOKE_PATH = "tools/ci/run-installed-release-smoke.R";
const NOTES_PATH = "docs/release/RELEASE-NOTES.md";
const CHECK_NAMES = ["archive_build", "archive_scan", "archive_check", "installed_smoke",
  "github_install", "runiverse_install", "publication"];

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

function git(repository, args, encoding = "utf8") {
  const env = { ...process.env, GIT_TERMINAL_PROMPT: "0" };
  for (const name of Object.keys(env)) {
    if (/^GIT_(?:DIR|WORK_TREE|INDEX_FILE|OBJECT_DIRECTORY|ALTERNATE_OBJECT_DIRECTORIES|CONFIG_COUNT|CONFIG_KEY_\d+|CONFIG_VALUE_\d+)$/.test(name)) {
      delete env[name];
    }
  }
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
      part !== "" && part !== "." && part !== ".." && part.toLowerCase() !== ".git");
}

function selectedTree(repository, commit) {
  return git(repository, ["ls-tree", "-r", "-z", "--full-tree", commit])
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
  while (!fs.existsSync(parent)) {
    suffix.unshift(path.basename(parent));
    const next = path.dirname(parent);
    if (next === parent) fail("INVALID_OUTPUT");
    parent = next;
  }
  if (fs.lstatSync(parent).isSymbolicLink() && parent === requested) fail("OUTPUT_SYMLINK");
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
      publication_readiness: "unqualified", release_notes_status: notes ? "ready" : "unavailable",
      checks: Object.fromEntries(CHECK_NAMES.map((name) => [name, "not_run"]))
    };
    writeFile(staging, "public/manifest.json", json(publicManifest));
    scanPublic(path.join(staging, "public"));
    const manifest = { ...publicManifest, source_entries: files, files: inventory(staging) };
    manifest.content_sha256 = sha256(json(manifest));
    writeFile(staging, INVENTORY_PATH, json(manifest));
    if (fs.existsSync(output)) fs.rmdirSync(output);
    fs.renameSync(staging, output);
    return { status: "prepared", source_commit: commit, content_sha256: manifest.content_sha256 };
  } finally {
    fs.rmSync(staging, { recursive: true, force: true });
  }
}

function verifyReleasePacket(options) {
  if (typeof options.packet !== "string" || !options.packet.trim()) fail("MISSING_PACKET");
  const root = path.resolve(options.packet);
  if (fs.lstatSync(root).isSymbolicLink()) fail("PACKET_SYMLINK");
  const contents = fs.readFileSync(path.join(root, INVENTORY_PATH), "utf8");
  let manifest;
  try { manifest = JSON.parse(contents); } catch { fail("INVALID_MANIFEST"); }
  const expected = { ...manifest };
  delete expected.content_sha256;
  if (manifest.content_sha256 !== sha256(json(expected))) fail("MANIFEST_CHANGED");
  if (JSON.stringify(manifest.files) !== JSON.stringify(inventory(root))) fail("PACKET_CONTENT_CHANGED");
  scanPublic(path.join(root, "public"));
  return { status: "verified", source_commit: manifest.source_commit,
    content_sha256: manifest.content_sha256 };
}

function main(argv) {
  const command = argv[0];
  const allowed = command === "prepare" ? ["--source-ref", "--output", "--tag"] :
    command === "verify" ? ["--packet"] : [];
  if (!allowed.length) fail("INVALID_COMMAND");
  const values = {};
  for (let i = 1; i < argv.length; i += 2) {
    const flag = argv[i];
    if (!allowed.includes(flag) || flag in values || typeof argv[i + 1] !== "string" ||
        argv[i + 1].startsWith("--")) fail("INVALID_ARGUMENTS");
    values[flag] = argv[i + 1];
  }
  const result = command === "prepare" ? prepareReleasePacket({
    sourceRef: values["--source-ref"], output: values["--output"], tag: values["--tag"]
  }) : verifyReleasePacket({ packet: values["--packet"] });
  process.stdout.write(json(result));
}

if (require.main === module) {
  try { main(process.argv.slice(2)); }
  catch (error) {
    process.stderr.write("FAIL " + (error instanceof ReleaseError ? error.code : "PACKET_IO_FAILED") + "\n");
    process.exitCode = 1;
  }
}

module.exports = { prepareReleasePacket, verifyReleasePacket };
