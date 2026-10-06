"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const test = require("node:test");
const zlib = require("node:zlib");

const checker = path.join(__dirname, "check-public-content.cjs");

function tarHeader(name, size) {
  const header = Buffer.alloc(512);
  header.write(name, 0, 100, "utf8");
  header.write("0000644\0", 100, 8, "ascii");
  header.write("0000000\0", 108, 8, "ascii");
  header.write("0000000\0", 116, 8, "ascii");
  header.write(size.toString(8).padStart(11, "0") + "\0", 124, 12, "ascii");
  header.write("00000000000\0", 136, 12, "ascii");
  header.fill(32, 148, 156);
  header[156] = "0".charCodeAt(0);
  header.write("ustar\0", 257, 6, "ascii");
  header.write("00", 263, 2, "ascii");
  let checksum = 0;
  for (const byte of header) checksum += byte;
  header.write(checksum.toString(8).padStart(6, "0") + "\0 ", 148, 8, "ascii");
  return header;
}

function makeTarGz(entries) {
  const blocks = [];
  for (const entry of entries) {
    const body = Buffer.from(entry.contents || "", "utf8");
    blocks.push(tarHeader(entry.path, body.length));
    blocks.push(body);
    const padding = (512 - (body.length % 512)) % 512;
    if (padding > 0) blocks.push(Buffer.alloc(padding));
  }
  blocks.push(Buffer.alloc(1024));
  return zlib.gzipSync(Buffer.concat(blocks));
}

function runChecker(args) {
  return spawnSync(process.execPath, [checker, ...args], {
    encoding: "utf8"
  });
}

function withTempDirectory(callback) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "gemodelr-public-content-"));
  try {
    callback(root);
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
}

test("accepts a clean source archive", () => {
  withTempDirectory((root) => {
    const archive = path.join(root, "clean.tar.gz");
    fs.writeFileSync(archive, makeTarGz([
      { path: "GEModelR/DESCRIPTION", contents: "Package: GEModelR\n" },
      { path: "GEModelR/vignettes/first-simulation.Rmd", contents: "guide\n" }
    ]));
    const result = runChecker(["--archive", archive]);
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.stdout, /PASS --archive/);
  });
});

test("rejects a source archive containing the generated site", () => {
  withTempDirectory((root) => {
    const archive = path.join(root, "site-in-archive.tar.gz");
    fs.writeFileSync(archive, makeTarGz([
      { path: "GEModelR/.pkgdown-site/index.html", contents: "site\n" }
    ]));
    const result = runChecker(["--archive", archive]);
    assert.equal(result.status, 1);
    assert.match(result.stderr, /\.pkgdown-site/);
  });
});

test("fails closed when the archive cannot be parsed", () => {
  withTempDirectory((root) => {
    const archive = path.join(root, "invalid.tar.gz");
    fs.writeFileSync(archive, Buffer.from("not a gzip archive"));
    const result = runChecker(["--archive", archive]);
    assert.equal(result.status, 1);
    assert.match(result.stderr, /cannot decompress archive/);
  });
});

test("scans every generated-site path", () => {
  withTempDirectory((root) => {
    const site = path.join(root, "site");
    fs.mkdirSync(path.join(site, "articles"), { recursive: true });
    fs.writeFileSync(path.join(site, "index.html"), "public\n");
    fs.writeFileSync(path.join(site, "articles", "guide.html"), "public\n");
    assert.equal(runChecker(["--site", site]).status, 0);

    fs.mkdirSync(path.join(site, "nested", ".pkgdown-site"), { recursive: true });
    const result = runChecker(["--site", site]);
    assert.equal(result.status, 1);
    assert.match(result.stderr, /\.pkgdown-site/);
  });
});

test("scans every staged artifact path", () => {
  withTempDirectory((root) => {
    const staged = path.join(root, "staged");
    fs.mkdirSync(path.join(staged, "articles"), { recursive: true });
    fs.writeFileSync(path.join(staged, "index.html"), "public\n");
    assert.equal(runChecker(["--artifact-dir", staged]).status, 0);

    fs.writeFileSync(path.join(staged, "private.txt"), "unexpected\n");
    fs.mkdirSync(path.join(staged, ".pkgdown-site"));
    const result = runChecker(["--artifact-dir", staged]);
    assert.equal(result.status, 1);
    assert.match(result.stderr, /\.pkgdown-site/);
  });
});
