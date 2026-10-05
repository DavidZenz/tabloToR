#!/usr/bin/env python3
"""Collect a bounded official CRAN source catalog; retain metadata, not tarballs."""
import argparse
import csv
from datetime import datetime, timezone
import hashlib
import io
from pathlib import Path
import re
import tarfile
from urllib.request import urlopen

ARCHIVE = "https://cran.r-project.org/src/contrib/Archive/Matrix/"


def version_key(version):
    return tuple(int(part) for part in re.split(r"[.-]", version))


def digest(data, algorithm="md5"):
    return hashlib.new(algorithm, data).hexdigest()


def collect(output, through):
    if not re.fullmatch(r"[0-9]+[.][0-9]+[-.][0-9]+", through):
        raise ValueError("Exact catalog endpoint required")
    output.mkdir(parents=True, exist_ok=True)
    index = urlopen(ARCHIVE, timeout=60).read()
    versions = set(re.findall(r'href="Matrix_([0-9]+[.][0-9]+[-.][0-9]+)[.]tar[.]gz"',
                              index.decode("utf-8")))
    bounded = sorted({v for v in versions if version_key("1.6-5") <= version_key(v) <= version_key(through)}
                     | {through}, key=version_key)
    if bounded[0] != "1.6-5":
        raise ValueError("Provisional release missing from official archive")
    (output / "archive-index.html").write_bytes(index)
    rows = []
    for order, version in enumerate(bounded, 1):
        source = ((ARCHIVE if version in versions else "https://cran.r-project.org/src/contrib/")
                  + "Matrix_" + version + ".tar.gz")
        raw = urlopen(source, timeout=60).read()
        with tarfile.open(fileobj=io.BytesIO(raw), mode="r:gz") as archive:
            description = archive.extractfile("Matrix/DESCRIPTION").read()
        text = description.decode("utf-8")
        if not re.search(r"^Package: Matrix$", text, re.MULTILINE) or not re.search(
                r"^Version: " + re.escape(version) + r"$", text, re.MULTILINE):
            raise ValueError("Source DESCRIPTION version mismatch")
        requirement = re.search(r"(?m)^Depends:[^\n]*(?:\n[ \t]+[^\n]*)*", text)
        required_r = re.search(r"\bR\s*\(>=\s*([0-9]+(?:[.][0-9]+)+)\)", requirement.group(0))
        if not required_r:
            raise ValueError("Unsupported source R requirement")
        filename = "Matrix_" + version + ".DESCRIPTION"
        (output / filename).write_bytes(description)
        rows.append(dict(matrix_version=version, source_url=source, requires_r=required_r.group(1),
            release_order=str(order), description_file=filename, description_md5=digest(description),
            source_sha256=digest(raw, "sha256")))
        print("Retained official source metadata: Matrix", version, "R >=", required_r.group(1), flush=True)
    catalog = output / "releases.csv"
    with catalog.open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    snapshot = {"ArchiveURL": ARCHIVE, "ArchiveFile": "archive-index.html",
        "ArchiveMD5": digest(index), "Through": through, "CatalogFile": "releases.csv",
        "CatalogMD5": digest(catalog.read_bytes()),
        "CollectedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "Collection": "official-cran-source-descriptions-v1"}
    (output / "snapshot.dcf").write_text("".join("{}: {}\n".format(k, v) for k, v in snapshot.items()))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--through", required=True)
    args = parser.parse_args()
    collect(args.output, args.through)
