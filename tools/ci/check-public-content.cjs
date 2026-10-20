#!/usr/bin/env node
"use strict";

const fs = require("node:fs");
const path = require("node:path");
const zlib = require("node:zlib");

const BLOCK_SIZE = 512;
const FORBIDDEN_SEGMENT = ".pkgdown-site";
const MAX_FILE_BYTES = 50 * 1024 * 1024;
const LARGE_SERIALIZED_FILE_BYTES = 10 * 1024 * 1024;
const REPOSITORY_ONLY_SEGMENTS = new Set([
  ".claude",
  ".codex",
  ".agents",
  ".aws",
  ".cache",
  ".git",
  ".github",
  ".gsd",
  ".local-gtap-test",
  ".planning",
  ".ssh",
  ".rcheck",
  ".rdata",
  ".rhistory",
  ".rproj.user",
  ".renviron"
].map((segment) => segment.toLowerCase()));
const REPOSITORY_ONLY_DOCUMENTS = new Set([
  "AGENTS.md",
  "AGENTS.html",
  "CONTRIBUTORS.md",
  "CONTRIBUTORS.html",
  "GOVERNANCE.md",
  "GOVERNANCE.html",
  "rcpp-solver-acceleration-plan.md",
  "rcpp-solver-acceleration-plan.html"
].map((document) => document.toLowerCase()));
const TEXT_FILE_EXTENSIONS = new Set([
  ".c", ".cc", ".cpp", ".cjs", ".csv", ".dcf", ".h", ".hpp",
  ".html", ".ini", ".js", ".json", ".md", ".mjs", ".py", ".r",
  ".rmd", ".sh", ".sql", ".toml", ".txt", ".xml", ".yaml", ".yml"
]);
const TEXT_FILE_NAMES = new Set([
  "CITATION", "DESCRIPTION", "LICENSE", "Makefile", "Makevars",
  "NAMESPACE", "cleanup", "configure", "configure.win"
]);
const PUBLIC_POLICY_PATHS = new Set([
  "DESCRIPTION", "README.md", "NEWS.md", "inst/CITATION"
]);
const PUBLIC_POLICY_MARKER_REASONS = new Set([
  "repository-only release or provenance reference is present",
  "release blocker identifier is present",
  "attribution blocker identifier is present",
  "reviewed attribution ledger content is present"
]);
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
  },
  {
    pattern: /-----BEGIN (?:OPENSSH |RSA |EC |DSA )?PRIVATE KEY-----/,
    reason: "private-key material is present"
  },
  {
    pattern: /\bAKIA[0-9A-Z]{16}\b/,
    reason: "AWS access-key material is present"
  },
  {
    pattern: /\b(?:gh[pousr]_[A-Za-z0-9_]{30,}|github_pat_[A-Za-z0-9_]{50,})\b/,
    reason: "GitHub access-token material is present"
  },
  {
    pattern: /\bxox[baprs]-[A-Za-z0-9-]{20,}\b/,
    reason: "Slack access-token material is present"
  }
];
const REPOSITORY_PATH_CANDIDATE_PATTERN =
  /\bdocs[^<>\s"'`]{0,128}?\b(?:provenance|release)\b/gi;
const ENCODED_PATH_SEPARATOR_PATTERN =
  /%(?:25)*(?:2f|5c)|&(?:amp;)*(?:sol|bsol);?|&(?:amp;)*#(?:0*47|x0*2f|0*92|x0*5c);?/i;
const PRIVATE_PATH_PATTERN = /(?:^|[._-])(?:private|confidential|proprietary|credentials?|passwords?|secrets?)(?:$|[._-])/i;
const PRIVATE_INPUT_EXTENSIONS = new Set([".har", ".gdx"]);
const SERIALIZED_EXTENSIONS = new Set([".rds", ".rda", ".rdata"]);
const SOLUTION_FILE_PATTERN = /(?:^|[._-])(?:full[-_]?scale|solution|levels)(?:[._-]|$)/i;
const GTAP_SERIALIZED_FILE_PATTERN = /(?:^|[._-])gtap(?:12a)?(?:[._-]|$)/i;
const SCRATCH_EXTENSIONS = new Set([
  ".a", ".class", ".core", ".dll", ".dylib", ".exe", ".o", ".pyc",
  ".so", ".swp", ".tmp"
]);

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
  let longLink = null;

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
      longLink = trimLongName(data.subarray(bodyOffset, bodyOffset + bodySize));
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
    const linkPath = effective.linkpath || longLink ||
      readString(header.subarray(157, 257));
    entries.push({
      path: memberPath,
      size: bodySize,
      type,
      linkPath,
      contents: type === "0" || type === "7"
        ? data.subarray(bodyOffset, bodyOffset + bodySize)
        : Buffer.alloc(0)
    });
    offset = bodyOffset + paddedSize(bodySize);
    localPax = {};
    longName = null;
    longLink = null;
  }

  fail("tar stream has no complete two-block end marker");
}

function pathViolation(entryPath) {
  const normalized = entryPath.replace(/\\/g, "/");
  if (normalized.startsWith("/") || /^[A-Za-z]:/.test(normalized)) {
    return "path is absolute rather than relative to the scanned root";
  }
  const rawParts = normalized.split("/");
  if (rawParts.includes("..")) {
    return "path escapes the scanned root";
  }
  const parts = normalized
    .split("/")
    .filter((part) => part !== "" && part !== ".");
  const policyParts = parts.map((part) => part.toLowerCase());
  if (policyParts.some((part) => PRIVATE_PATH_PATTERN.test(part) ||
      /^\.env(?:$|[._-])/i.test(part) ||
      /^\.renviron$/i.test(part) ||
      /^id_(?:rsa|ed25519)$/i.test(part))) {
    return "private or credential-like path is present";
  }
  if (policyParts.includes(FORBIDDEN_SEGMENT.toLowerCase())) {
    return "generated pkgdown site is nested inside the scanned output";
  }
  if (policyParts.some((part) => REPOSITORY_ONLY_SEGMENTS.has(part))) {
    return "repository-only planning or workflow content is present";
  }
  const docsIndex = policyParts.lastIndexOf("docs");
  if (docsIndex >= 0 &&
      ["release", "provenance"].includes(policyParts[docsIndex + 1])) {
    return "repository-only release or provenance evidence is present";
  }
  if (REPOSITORY_ONLY_DOCUMENTS.has(policyParts[policyParts.length - 1])) {
    return "repository-only maintainer document is present";
  }
  return null;
}

function fileViolation(entryPath, size) {
  const basename = path.posix.basename(entryPath.replace(/\\/g, "/"));
  const extension = path.posix.extname(basename).toLowerCase();
  if (SCRATCH_EXTENSIONS.has(extension)) {
    return "compiled or temporary scratch file is present";
  }
  if (PRIVATE_INPUT_EXTENSIONS.has(extension)) {
    return "private or full-scale model input file is present";
  }
  if (extension === ".rdata" || extension === ".rda") {
    return "serialized workspace or solution artifact is present";
  }
  if (size > MAX_FILE_BYTES) {
    return "file exceeds the 50 MiB public-artifact limit";
  }
  if (SERIALIZED_EXTENSIONS.has(extension) &&
      (size > LARGE_SERIALIZED_FILE_BYTES ||
       SOLUTION_FILE_PATTERN.test(basename) ||
       GTAP_SERIALIZED_FILE_PATTERN.test(basename))) {
    return "full-scale solution or serialized model artifact is present";
  }
  if ((extension === ".csv" || extension === ".json" || extension === ".txt") &&
      SOLUTION_FILE_PATTERN.test(basename)) {
    return "full-scale solution or model-result artifact is present";
  }
  return null;
}

function decodeHtmlCharacterReferences(content) {
  let decoded = content;
  for (let pass = 0; pass < 4; pass += 1) {
    const next = decoded.replace(
      /&(?:amp|percnt|sol|bsol);?|&#(?:[0-9]+|x[0-9a-f]+);?/gi,
      (reference) => {
        if (/^&#/i.test(reference)) {
          const numeric = reference.slice(2).replace(/;$/, "");
          const codePoint = /^x/i.test(numeric)
            ? Number.parseInt(numeric.slice(1), 16)
            : Number.parseInt(numeric, 10);
          if (!Number.isInteger(codePoint) || codePoint < 0 ||
              codePoint > 0x10ffff ||
              (codePoint >= 0xd800 && codePoint <= 0xdfff)) {
            return reference;
          }
          return String.fromCodePoint(codePoint);
        }
        const entity = reference.slice(1).replace(/;$/, "").toLowerCase();
        return {
          amp: "&",
          percnt: "%",
          sol: "/",
          bsol: "\\"
        }[entity] || reference;
      }
    );
    if (next === decoded) break;
    decoded = next;
  }
  return decoded;
}

function contentViolation(content, filePath = "") {
  const normalized = decodeHtmlCharacterReferences(content)
    .replace(/%(?:25)*(?:2f|5c)/gi, (separator) =>
      /5c$/i.test(separator) ? "\\" : "/")
    .replace(/&(?:amp;)*sol;?/gi, "/")
    .replace(/&(?:amp;)*bsol;?/gi, "\\")
    .replace(/&(?:amp;)*#(?:0*47|x0*2f);?/gi, "/")
    .replace(/&(?:amp;)*#(?:0*92|x0*5c);?/gi, "\\");
  // These four package-facing metadata files intentionally state the public
  // attribution/release boundary. The evidence trees themselves remain barred.
  const normalizedPath = filePath.replace(/\\/g, "/");
  const pathParts = normalizedPath.split("/").filter((part) => part !== "");
  if (pathParts[0] === "GEModelR") pathParts.shift();
  const allowPublicPolicyMarkers = PUBLIC_POLICY_PATHS.has(pathParts.join("/"));
  for (const marker of PRIVATE_CONTENT_MARKERS) {
    if (allowPublicPolicyMarkers &&
        PUBLIC_POLICY_MARKER_REASONS.has(marker.reason)) continue;
    if (marker.pattern.test(normalized)) return marker.reason;
  }
  for (const candidate of normalized.matchAll(
    REPOSITORY_PATH_CANDIDATE_PATTERN
  )) {
    if (ENCODED_PATH_SEPARATOR_PATTERN.test(candidate[0])) {
      return "repository-only release or provenance reference is present";
    }
  }
  return null;
}

function isTextFile(filePath) {
  const normalized = filePath.replace(/\\/g, "/");
  return TEXT_FILE_NAMES.has(path.posix.basename(normalized)) ||
    TEXT_FILE_EXTENSIONS.has(path.posix.extname(normalized).toLowerCase());
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
    tar = zlib.gunzipSync(compressed, { maxOutputLength: 512 * 1024 * 1024 });
  } catch (error) {
    fail("cannot decompress archive " + archivePath + ": " + error.message);
  }

  const entries = parseTar(tar);
  const violations = entries.flatMap((entry) => {
    const reasons = [];
    const pathReason = pathViolation(entry.path);
    if (pathReason) reasons.push({ path: entry.path, reason: pathReason });
    if (!pathReason && !["0", "5", "7", "2", "1"].includes(entry.type)) {
      reasons.push({ path: entry.path, reason: "unsupported tar entry type is present" });
    }
    if (!pathReason && ["2", "1"].includes(entry.type)) {
      const linkPath = entry.linkPath.replace(/\\/g, "/");
      const target = entry.type === "2"
        ? path.posix.normalize(path.posix.join(
          path.posix.dirname(entry.path), linkPath
        ))
        : path.posix.normalize(linkPath);
      if (!linkPath || linkPath.startsWith("/") ||
          /^[A-Za-z]:/.test(linkPath) ||
          target === ".." || target.startsWith("../")) {
        reasons.push({ path: entry.path, reason: "archive link escapes the scanned root" });
      }
    }
    if (["0", "7"].includes(entry.type)) {
      const fileReason = fileViolation(entry.path, entry.size);
      if (fileReason) reasons.push({ path: entry.path, reason: fileReason });
      if (entry.size <= MAX_FILE_BYTES && isTextFile(entry.path)) {
        const contentReason = contentViolation(
          entry.contents.toString("utf8"), entry.path
        );
        if (contentReason) reasons.push({ path: entry.path, reason: contentReason });
      }
    }
    return reasons;
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
      } else {
        const fileReason = fileViolation(relative, stat.size);
        if (fileReason) violations.push({ path: relative, reason: fileReason });
        if (stat.size <= MAX_FILE_BYTES && isTextFile(relative)) {
          let content;
          try {
            content = fs.readFileSync(absolute, "utf8");
          } catch (error) {
            fail("cannot read " + mode + " content " + relative +
              ": " + error.message);
          }
          const contentReason = contentViolation(content, relative);
          if (contentReason) {
            violations.push({ path: relative, reason: contentReason });
          }
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
  decodeHtmlCharacterReferences,
  inspect,
  inspectArchive,
  inspectDirectory,
  parseTar,
  pathViolation
};
