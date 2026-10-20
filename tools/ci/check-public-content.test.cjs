"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const test = require("node:test");
const zlib = require("node:zlib");

const checker = path.join(__dirname, "check-public-content.cjs");

function tarHeader(name, size, type = "0", linkPath = "") {
  const header = Buffer.alloc(512);
  header.write(name, 0, 100, "utf8");
  header.write("0000644\0", 100, 8, "ascii");
  header.write("0000000\0", 108, 8, "ascii");
  header.write("0000000\0", 116, 8, "ascii");
  header.write(size.toString(8).padStart(11, "0") + "\0", 124, 12, "ascii");
  header.write("00000000000\0", 136, 12, "ascii");
  header.fill(32, 148, 156);
  header[156] = type.charCodeAt(0);
  header.write(linkPath, 157, 100, "utf8");
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
    blocks.push(tarHeader(
      entry.path, body.length, entry.type || "0", entry.linkPath || ""
    ));
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
      { path: "GEModelR/README.md", contents: "See docs/provenance/ATTRIBUTION.md for package credit.\n" },
      { path: "GEModelR/NEWS.md", contents: "Attribution-Role: reviewed package metadata\n" },
      { path: "GEModelR/inst/CITATION", contents: "Package citation.\n" },
      { path: "GEModelR/vignettes/first-simulation.Rmd", contents: "guide\n" },
      { path: "GEModelR/benchmarks/run-model.R", contents: "runBenchmark()\n" },
      { path: "GEModelR/benchmarks/repair-gtap-20261017.csv", contents: "component,elapsed_ms\nsolve,1.0\n" },
      { path: "GEModelR/tests/testthat/fixtures/three-region.tab", contents: "TABLO\n" }
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

test("rejects credential paths, model inputs, solutions, and compiled scratch", () => {
  withTempDirectory((root) => {
    const cases = [
      ["GEModelR/inst/data/credentials.txt", "private or credential-like path"],
      ["GEModelR/inst/data/private.har", "private or full-scale model input"],
      ["GEModelR/results/solution.rds", "full-scale solution"],
      ["GEModelR/src/sparse-lu.o", "compiled or temporary scratch"],
      ["GEModelR/model.RData", "serialized workspace"]
    ];
    for (const [member, reason] of cases) {
      const archive = path.join(root, "rejected.tar.gz");
      fs.writeFileSync(archive, makeTarGz([{ path: member, contents: "x" }]));
      const result = runChecker(["--archive", archive]);
      assert.equal(result.status, 1, member);
      assert.match(result.stderr, new RegExp(reason));
    }
  });
});

test("rejects credential-like text and escaping archive links", () => {
  withTempDirectory((root) => {
    const archive = path.join(root, "credential.tar.gz");
    fs.writeFileSync(archive, makeTarGz([
      { path: "GEModelR/notes.txt", contents: "AKIA1234567890ABCDEF\n" }
    ]));
    const credential = runChecker(["--archive", archive]);
    assert.equal(credential.status, 1);
    assert.match(credential.stderr, /AWS access-key material/);

    fs.writeFileSync(archive, makeTarGz([{
      path: "GEModelR/data/link", type: "2", linkPath: "../../../outside.har"
    }]));
    const link = runChecker(["--archive", archive]);
    assert.equal(link.status, 1);
    assert.match(link.stderr, /archive link escapes the scanned root/);
  });
});

test("scans credential markers in extensionless package metadata", () => {
  withTempDirectory((root) => {
    const archive = path.join(root, "metadata-token.tar.gz");
    fs.writeFileSync(archive, makeTarGz([
      { path: "GEModelR/DESCRIPTION", contents: "Package: GEModelR\nAWS: AKIA1234567890ABCDEF\n" }
    ]));
    const result = runChecker(["--archive", archive]);
    assert.equal(result.status, 1);
    assert.match(result.stderr, /AWS access-key material/);
  });
});

test("does not extend package policy exceptions to nested files", () => {
  withTempDirectory((root) => {
    const archive = path.join(root, "nested-reference.tar.gz");
    fs.writeFileSync(archive, makeTarGz([
      { path: "GEModelR/docs/README.md", contents: "See docs/provenance/RIGHTS.md.\n" }
    ]));
    const result = runChecker(["--archive", archive]);
    assert.equal(result.status, 1);
    assert.match(result.stderr, /repository-only release or provenance reference/);
  });
});

test("rejects repository-only workflow content in a source archive", () => {
  withTempDirectory((root) => {
    const archive = path.join(root, "repository-only.tar.gz");
    fs.writeFileSync(archive, makeTarGz([
      { path: "GEModelR/.github/workflows/native-ci.yaml", contents: "workflow\n" }
    ]));
    const result = runChecker(["--archive", archive]);
    assert.equal(result.status, 1);
    assert.match(result.stderr, /repository-only planning or workflow content/);
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

    fs.rmSync(path.join(site, "nested"), { recursive: true, force: true });
    fs.writeFileSync(path.join(site, "GOVERNANCE.html"), "maintainer-only\n");
    const repositoryOnly = runChecker(["--site", site]);
    assert.equal(repositoryOnly.status, 1);
    assert.match(repositoryOnly.stderr, /repository-only maintainer document/);
  });
});

test("rejects literal and encoded repository-only paths in every scan mode", () => {
  withTempDirectory((root) => {
    const site = path.join(root, "site");
    fs.mkdirSync(site, { recursive: true });
    fs.writeFileSync(path.join(site, "index.html"), "Public guide\n");
    assert.equal(runChecker(["--site", site]).status, 0);

    const paths = [
      "docs/provenance/RIGHTS.md",
      "docs&#47;provenance&#47;RIGHTS.md",
      "docs&sol;provenance&sol;RIGHTS.md",
      "docs%2fprovenance%2fRIGHTS.md"
    ];
    for (const candidate of paths) {
      fs.writeFileSync(
        path.join(site, "index.html"),
        `See ${candidate} for the reviewed evidence.\n`
      );
      const provenance = runChecker(["--site", site]);
      assert.equal(provenance.status, 1, candidate);
      assert.match(
        provenance.stderr,
        /repository-only release or provenance reference/
      );
    }

    fs.writeFileSync(
      path.join(site, "index.html"),
      "Current state: ATTRIBUTION_IDENTITY_UNRESOLVED.\n"
    );
    const blocker = runChecker(["--artifact-dir", site]);
    assert.equal(blocker.status, 1);
    assert.match(blocker.stderr, /attribution blocker identifier/);

    fs.writeFileSync(
      path.join(site, "index.html"),
      "See docs&sol;provenance&sol;RIGHTS.md for the reviewed evidence.\n"
    );
    const stagedProvenance = runChecker(["--artifact-dir", site]);
    assert.equal(stagedProvenance.status, 1);
    assert.match(
      stagedProvenance.stderr,
      /repository-only release or provenance reference/
    );

    const archive = path.join(root, "named-entity.tar.gz");
    fs.writeFileSync(archive, makeTarGz([{
      path: "GEModelR/index.html",
      contents: "See docs&sol;provenance&sol;RIGHTS.md for the evidence.\n"
    }]));
    const archivedProvenance = runChecker(["--archive", archive]);
    assert.equal(archivedProvenance.status, 1);
    assert.match(
      archivedProvenance.stderr,
      /repository-only release or provenance reference/
    );
  });
});

test("rejects HTML-encoded percent separators in every scan mode", () => {
  withTempDirectory((root) => {
    const site = path.join(root, "site");
    fs.mkdirSync(site, { recursive: true });
    const candidates = [
      "docs&#x25;2fprovenance&#x25;2fRIGHTS.md",
      "docs&percnt;2fprovenance&percnt;2fRIGHTS.md"
    ];

    for (const candidate of candidates) {
      const contents = `See ${candidate} for reviewed evidence.\n`;
      fs.writeFileSync(path.join(site, "index.html"), contents);
      for (const mode of ["--site", "--artifact-dir"]) {
        const result = runChecker([mode, site]);
        assert.equal(result.status, 1, `${mode}: ${candidate}`);
        assert.match(
          result.stderr,
          /repository-only release or provenance reference/
        );
      }

      const archive = path.join(root, "encoded-percent.tar.gz");
      fs.writeFileSync(archive, makeTarGz([{
        path: "GEModelR/index.html",
        contents
      }]));
      const archived = runChecker(["--archive", archive]);
      assert.equal(archived.status, 1, `--archive: ${candidate}`);
      assert.match(
        archived.stderr,
        /repository-only release or provenance reference/
      );
    }
  });
});

test("rejects case-variant repository-only paths in directories and archives", () => {
  withTempDirectory((root) => {
    const candidates = [
      ".GITHUB/workflows/release.yml",
      "docs/Provenance/UPSTREAM-REQUEST.md",
      "docs/Release/RELEASE-GATES.md"
    ];
    const staged = path.join(root, "staged");
    const entries = [];

    for (const candidate of candidates) {
      const stagedPath = path.join(staged, candidate);
      fs.mkdirSync(path.dirname(stagedPath), { recursive: true });
      fs.writeFileSync(stagedPath, "repository-only evidence\n");
      entries.push({
        path: `GEModelR/${candidate}`,
        contents: "repository-only evidence\n"
      });

      const directoryResult = runChecker(["--artifact-dir", staged]);
      assert.equal(directoryResult.status, 1, candidate);
      assert.match(
        directoryResult.stderr,
        /repository-only (?:planning or workflow content|release or provenance evidence)/
      );
    }

    const archive = path.join(root, "case-variant.tar.gz");
    fs.writeFileSync(archive, makeTarGz(entries));
    const archived = runChecker(["--archive", archive]);
    assert.equal(archived.status, 1);
    assert.match(
      archived.stderr,
      /repository-only (?:planning or workflow content|release or provenance evidence)/
    );
  });
});

test("rejects private files, compiled scratch, oversized files, and escaping links", () => {
  withTempDirectory((root) => {
    const staged = path.join(root, "staged");
    fs.mkdirSync(staged, { recursive: true });
    fs.writeFileSync(path.join(staged, "ordinary.md"), "public summary\n");
    assert.equal(runChecker(["--artifact-dir", staged]).status, 0);

    fs.mkdirSync(path.join(staged, ".ssh"));
    let result = runChecker(["--artifact-dir", staged]);
    assert.equal(result.status, 1);
    assert.match(result.stderr, /repository-only planning or workflow content/);

    fs.rmSync(path.join(staged, ".ssh"), { recursive: true, force: true });
    fs.writeFileSync(path.join(staged, "native.so"), "object");
    result = runChecker(["--artifact-dir", staged]);
    assert.equal(result.status, 1);
    assert.match(result.stderr, /compiled or temporary scratch/);

    fs.rmSync(path.join(staged, "native.so"));
    const large = path.join(staged, "large-output.txt");
    fs.closeSync(fs.openSync(large, "w"));
    fs.truncateSync(large, 50 * 1024 * 1024 + 1);
    result = runChecker(["--artifact-dir", staged]);
    assert.equal(result.status, 1);
    assert.match(result.stderr, /50 MiB/);

    fs.rmSync(large);
    const outside = path.join(root, "outside.txt");
    fs.writeFileSync(outside, "not staged\n");
    fs.symlinkSync(outside, path.join(staged, "outside.txt"));
    result = runChecker(["--artifact-dir", staged]);
    assert.equal(result.status, 1);
    assert.match(result.stderr, /symlink escapes the scanned root/);
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

    fs.rmSync(path.join(staged, ".pkgdown-site"), { recursive: true, force: true });
    fs.mkdirSync(path.join(staged, "docs", "provenance"), { recursive: true });
    fs.writeFileSync(path.join(staged, "docs", "provenance", "RIGHTS.md"), "evidence\n");
    const repositoryOnly = runChecker(["--artifact-dir", staged]);
    assert.equal(repositoryOnly.status, 1);
    assert.match(repositoryOnly.stderr, /repository-only release or provenance evidence/);
  });
});
