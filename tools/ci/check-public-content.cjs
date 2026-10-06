#!/usr/bin/env node
"use strict";

const fs = require("node:fs");
const path = require("node:path");
const zlib = require("node:zlib");

const BLOCK_SIZE = 512;
const FORBIDDEN_SEGMENT = ".pkgdown-site";
const REPOSITORY_ONLY_SEGMENTS = new Set([
  ".claude",
  ".codex",
  ".git",
  ".github",
  ".gsd",
  ".local-gtap-test",
  ".planning"
]);
const REPOSITORY_ONLY_DOCUMENTS = new Set([
  "AGENTS.md",
  "AGENTS.html",
  "CONTRIBUTORS.md",
  "CONTRIBUTORS.html",
  "GOVERNANCE.md",
  "GOVERNANCE.html",
  "rcpp-solver-acceleration-plan.md",
  "rcpp-solver-acceleration-plan.html"
]);
const TEXT_FILE_EXTENSIONS = new Set([".html", ".json", ".md", ".txt", ".xml"]);
const PRIVATE_CONTENT_MARKERS = [
  {
    pattern: /docs[\\/](?:provenance|release)(?:[\\/]|[?#\s"')]|$)/i,
    reason: "repository-only release or provenance reference is present"
  },
  {
    pattern: /\bDEPENDENCY_COMPATIBILITY_AUDIT_PENDING\b/,
    reason: "release blocker identifier is present"
  },
  {
    pattern: /\bATTRIBUTION_IDENTITY_UNRESOLVED\b/,
    reason: "attribution blocker identifier is present"
  },
  {
    pattern: /\b(?:Attribution-Role|Evidence-Key):/i,
    reason: "reviewed attribution ledger content is present"
  }
];

function fail(message) {
  throw new Error(message);
}

function readString(field) {
  const end = field.indexOf(0);
  const value = end === -1 ? field : field.subarray(0, end);
  return value.toString("utf8").trim();
}

function readNumber(field, label) {
  if (field.length === 0) fail("empty tar " + label);
  if ((field[0] & 0x80) !== 0) {
    if ((field[0] & 0x40) !== 0) fail("negative tar " + label + " is unsupported");
    let value = field[0] & 0x7f;
    for (let i = 1; i < field.length; i += 1) {
      value = value * 256 + field[i];
    }
    if (!Number.isSafeInteger(value)) fail("unsafe tar " + label);
    return value;
  }

  const digits = field.toString("ascii").replace(/^[\0 ]+|[\0 ]+$/g, "");
  if (digits === "") return 0;
  if (!/^[0-7]+$/.test(digits)) fail("invalid tar " + label);
  const value = Number.parseInt(digits, 8);
  if (!Number.isSafeInteger(value)) fail("unsafe tar " + label);
  return value;
}

function verifyHeader(header, offset) {
  const expected = readNumber(header.subarray(148, 156), "checksum");
  let unsigned = 0;
  let signed = 0;
  for (let i = 0; i < BLOCK_SIZE; i += 1) {
    const byte = i >= 148 && i < 156 ? 32 : header[i];
    unsigned += byte;
    signed += byte > 127 ? byte - 256 : byte;
  }
  if (expected !== unsigned && expected !== signed) {
    fail("tar header checksum mismatch at byte " + offset);
  }
}

function parsePax(data) {
  const values = {};
  let offset = 0;
  while (offset < data.length) {
    const space = data.indexOf(0x20, offset);
    if (space === -1) fail("malformed PAX record length");
    const lengthText = data.subarray(offset, space).toString("ascii");
    if (!/^[1-9][0-9]*$/.test(lengthText)) fail("invalid PAX record length");
    const length = Number(lengthText);
    const end = offset + length;
    if (!Number.isSafeInteger(length) || end > data.length ||
        data[end - 1] !== 0x0a || space + 1 >= end - 1) {
      fail("truncated or malformed PAX record");
    }
    const record = data.subarray(space + 1, end - 1).toString("utf8");
    const equals = record.indexOf("=");
    if (equals <= 0) fail("malformed PAX key/value record");
    values[record.slice(0, equals)] = record.slice(equals + 1);
    offset = end;
  }
  return values;
}

function trimLongName(data) {
  return data.toString("utf8").replace(/[\0\n]+$/g, "");
}

function paddedSize(size) {
  return Math.ceil(size / BLOCK_SIZE) * BLOCK_SIZE;
}

function parseTar(data) {
  const entries = [];
  let offset = 0;
  let zeroBlocks = 0;
  let localPax = {};
  let globalPax = {};
  let longName = null;

  while (offset + BLOCK_SIZE <= data.length) {
    const header = data.subarray(offset, offset + BLOCK_SIZE);
    let isZero = true;
    for (let i = 0; i < BLOCK_SIZE; i += 1) {
      if (header[i] !== 0) {
        isZero = false;
        break;
      }
    }
    if (isZero) {
      zeroBlocks += 1;
      offset += BLOCK_SIZE;
      if (zeroBlocks >= 2) {
        for (let i = offset; i < data.length; i += 1) {
          if (data[i] !== 0) fail("nonzero data follows tar end marker");
        }
        return entries;
      }
      continue;
    }
    if (zeroBlocks !== 0) fail("incomplete tar end marker");
    verifyHeader(header, offset);

    const headerName = readString(header.subarray(0, 100));
    const prefix = readString(header.subarray(345, 500));
    const headerPath = prefix ? prefix + "/" + headerName : headerName;
    const headerSize = readNumber(header.subarray(124, 136), "size");
    const type = String.fromCharCode(header[156] || 48);
    const bodyOffset = offset + BLOCK_SIZE;
    let bodySize = headerSize;

    if (type === "x" || type === "g") {
      if (bodyOffset + paddedSize(bodySize) > data.length) {
        fail("truncated PAX header body");
      }
      const pax = parsePax(data.subarray(bodyOffset, bodyOffset + bodySize));
      if (type === "g") globalPax = Object.assign(globalPax, pax);
      else localPax = Object.assign(localPax, pax);
      offset = bodyOffset + paddedSize(bodySize);
      continue;
    }

    if (type === "L") {
      if (bodyOffset + paddedSize(bodySize) > data.length) {
        fail("truncated GNU long-name header body");
      }
      longName = trimLongName(data.subarray(bodyOffset, bodyOffset + bodySize));
      offset = bodyOffset + paddedSize(bodySize);
      continue;
    }

    if (type === "K") {
      if (bodyOffset + paddedSize(bodySize) > data.length) {
        fail("truncated GNU long-link header body");
      }
      offset = bodyOffset + paddedSize(bodySize);
      continue;
    }

    const effective = Object.assign({}, globalPax, localPax);
    const memberPath = effective.path || longName || headerPath;
    if (!memberPath) fail("tar member has an empty path");
    if (effective.size !== undefined) {
      if (!/^(0|[1-9][0-9]*)$/.test(effective.size)) fail("invalid PAX size");
      bodySize = Number(effective.size);
      if (!Number.isSafeInteger(bodySize)) fail("unsafe PAX size");
    }
    if (bodyOffset + paddedSize(bodySize) > data.length) {
      fail("truncated tar member body for " + memberPath);
    }
    entries.push(memberPath);
    offset = bodyOffset + paddedSize(bodySize);
    localPax = {};
    longName = null;
  }

  fail("tar stream has no complete two-block end marker");
}

function pathViolation(entryPath) {
  const parts = entryPath
    .replace(/\\/g, "/")
    .split("/")
    .filter((part) => part !== "" && part !== ".");
  if (parts.includes(FORBIDDEN_SEGMENT)) {
    return "generated pkgdown site is nested inside the scanned output";
  }
  if (parts.some((part) => REPOSITORY_ONLY_SEGMENTS.has(part))) {
    return "repository-only planning or workflow content is present";
  }
  const docsIndex = parts.lastIndexOf("docs");
  if (docsIndex >= 0 &&
      ["release", "provenance"].includes(parts[docsIndex + 1])) {
    return "repository-only release or provenance evidence is present";
  }
  if (REPOSITORY_ONLY_DOCUMENTS.has(parts[parts.length - 1])) {
    return "repository-only maintainer document is present";
  }
  return null;
}

function contentViolation(content) {
  const normalized = content
    .replace(/%2f/gi, "/")
    .replace(/&#(?:x2f|47);/gi, "/")
    .replace(/&#x5c;/gi, "\\");
  for (const marker of PRIVATE_CONTENT_MARKERS) {
    if (marker.pattern.test(normalized)) return marker.reason;
  }
  return null;
}

function inspectArchive(archivePath) {
  let compressed;
  try {
    compressed = fs.readFileSync(archivePath);
  } catch (error) {
    fail("cannot read archive " + archivePath + ": " + error.message);
  }

  let tar;
  try {
    tar = zlib.gunzipSync(compressed);
  } catch (error) {
    fail("cannot decompress archive " + archivePath + ": " + error.message);
  }

  const entries = parseTar(tar);
  const violations = entries.flatMap((entryPath) => {
    const reason = pathViolation(entryPath);
    return reason ? [{ path: entryPath, reason }] : [];
  });
  return { entries, violations };
}

function isWithin(root, target) {
  const relative = path.relative(root, target);
  return relative === "" || (!relative.startsWith(".." + path.sep) &&
    relative !== ".." && !path.isAbsolute(relative));
}

function inspectDirectory(rootPath, mode) {
  let rootStat;
  try {
    rootStat = fs.lstatSync(rootPath);
  } catch (error) {
    fail("cannot read " + mode + " directory " + rootPath + ": " + error.message);
  }
  if (!rootStat.isDirectory() || rootStat.isSymbolicLink()) {
    fail(mode + " root is not a real directory: " + rootPath);
  }

  let root;
  try {
    root = fs.realpathSync(rootPath);
  } catch (error) {
    fail("cannot resolve " + mode + " root " + rootPath + ": " + error.message);
  }

  const entries = [];
  const violations = [];
  const pending = [{ absolute: root, relative: "" }];
  while (pending.length > 0) {
    const current = pending.pop();
    let children;
    try {
      children = fs.readdirSync(current.absolute, { withFileTypes: true });
    } catch (error) {
      fail("cannot list " + mode + " directory " + current.relative +
        ": " + error.message);
    }

    for (const child of children) {
      const relative = current.relative
        ? path.join(current.relative, child.name)
        : child.name;
      const absolute = path.join(current.absolute, child.name);
      let stat;
      try {
        stat = fs.lstatSync(absolute);
      } catch (error) {
        fail("cannot inspect " + mode + " entry " + relative +
          ": " + error.message);
      }
      entries.push(relative);
      const reason = pathViolation(relative);
      if (reason) {
        violations.push({
          path: relative,
          reason
        });
      }
      if (stat.isSymbolicLink()) {
        let target;
        try {
          target = fs.realpathSync(absolute);
        } catch (error) {
          fail("cannot resolve " + mode + " symlink " + relative +
            ": " + error.message);
        }
        if (!isWithin(root, target)) {
          violations.push({
            path: relative,
            reason: "symlink escapes the scanned root"
          });
        }
      } else if (stat.isDirectory()) {
        pending.push({ absolute, relative });
      } else if (!stat.isFile()) {
        violations.push({
          path: relative,
          reason: "unsupported filesystem entry type"
        });
      } else if (TEXT_FILE_EXTENSIONS.has(path.extname(child.name).toLowerCase())) {
        let content;
        try {
          content = fs.readFileSync(absolute, "utf8");
        } catch (error) {
          fail("cannot read " + mode + " content " + relative +
            ": " + error.message);
        }
        const contentReason = contentViolation(content);
        if (contentReason) {
          violations.push({ path: relative, reason: contentReason });
        }
      }
    }
  }
  return { entries, violations };
}

function inspect(mode, target) {
  if (mode === "--archive") return inspectArchive(target);
  if (mode === "--site") return inspectDirectory(target, "site");
  if (mode === "--artifact-dir") return inspectDirectory(target, "artifact");
  fail("unknown mode " + mode);
}

function main(argv) {
  if (argv.length !== 4) {
    fail("usage: check-public-content.cjs --archive PATH | --site PATH | --artifact-dir PATH");
  }
  const mode = argv[2];
  if (!["--archive", "--site", "--artifact-dir"].includes(mode)) {
    fail("usage: check-public-content.cjs --archive PATH | --site PATH | --artifact-dir PATH");
  }
  const result = inspect(mode, argv[3]);
  if (result.violations.length > 0) {
    for (const violation of result.violations) {
      process.stderr.write("FAIL " + violation.path + ": " + violation.reason + "\n");
    }
    process.exitCode = 1;
    return;
  }
  process.stdout.write("PASS " + mode + " " + argv[3] +
    " (" + result.entries.length + " entries scanned)\n");
}

if (require.main === module) {
  try {
    main(process.argv);
  } catch (error) {
    process.stderr.write("FAIL: " + error.message + "\n");
    process.exitCode = 1;
  }
}

module.exports = {
  contentViolation,
  inspect,
  inspectArchive,
  inspectDirectory,
  parseTar,
  pathViolation
};
