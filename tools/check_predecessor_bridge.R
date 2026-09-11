#!/usr/bin/env Rscript

bridge_abort = function(code, detail = NULL) {
  message = if (is.null(detail) || !length(detail) || !nzchar(detail)) {
    code
  } else {
    paste(code, detail)
  }
  stop(message, call. = FALSE)
}

bridge_script_path = local({
  source_files = vapply(sys.frames(), function(frame) {
    value = frame$ofile
    if (is.null(value) || !length(value)) "" else as.character(value[[1L]])
  }, character(1))
  source_files = source_files[nzchar(source_files)]
  file_argument = grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (length(source_files)) {
    normalizePath(tail(source_files, 1L), mustWork = TRUE)
  } else if (length(file_argument)) {
    normalizePath(sub("^--file=", "", file_argument[[1L]]), mustWork = TRUE)
  } else {
    NA_character_
  }
})

bridge_repository_root = function() {
  working = normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  ancestors = working
  while (!identical(tail(ancestors, 1L), dirname(tail(ancestors, 1L)))) {
    ancestors = c(ancestors, dirname(tail(ancestors, 1L)))
  }
  candidates = c(
    if (!is.na(bridge_script_path)) dirname(dirname(bridge_script_path))
    else character(),
    ancestors
  )
  for (candidate in unique(candidates)) {
    if (file.exists(file.path(candidate, "DESCRIPTION")) &&
        file.exists(file.path(
          candidate, "inst", "migration", "predecessor-fingerprints.dcf"
        ))) {
      return(normalizePath(candidate, winslash = "/", mustWork = TRUE))
    }
  }
  bridge_abort("BRIDGE_ROOT_NOT_FOUND")
}

bridge_registry_fields = function() {
  c(
    "Schema", "Record-Id", "Package-Name", "Package-Version",
    "Source-Scope", "Source-File-Count", "Source-Fingerprint",
    "Source-Locator-Type", "Source-Locator", "Source-Immutable-Id",
    "Fixture-Path", "Fixture-Digest-Algorithm", "Fixture-Digest",
    "Tablo-Path", "Tablo-Digest-Algorithm", "Tablo-Digest",
    "Data-Fingerprint", "Install-Command", "Conversion-Command",
    "Lineage-Review-State", "Reachability-Review-State", "Rationale"
  )
}

bridge_source_scope_description = function() {
  paste(
    "Git-tracked regular files under DESCRIPTION, NAMESPACE, R, src, inst,",
    "tests/testthat, and tools; exclude only",
    "inst/migration/predecessor-fingerprints.dcf and",
    "tests/testthat/fixtures/serialization/tabloToR-schema1-lineage.rds;",
    "C-byte radix path order; MD5 over path-NUL-file-MD5 records"
  )
}

bridge_install_command = function() {
  'R CMD INSTALL --library="$TABLOTOR_BRIDGE_LIB" "$TABLOTOR_BRIDGE_SOURCE"'
}

bridge_conversion_command = function() {
  paste0(
    "R --vanilla -q -e 'library(tabloToR, ",
    "lib.loc = Sys.getenv(\"TABLOTOR_BRIDGE_LIB\")); ",
    "model = readRDS(Sys.getenv(\"TABLOTOR_RAW_RDS\")); ",
    "model$saveState(Sys.getenv(\"TABLOTOR_LOGICAL_STATE\"))'"
  )
}

bridge_registry_path = function(root = bridge_repository_root()) {
  file.path(root, "inst", "migration", "predecessor-fingerprints.dcf")
}

bridge_hash_raw = function(value, algorithm = c("sha256", "md5")) {
  algorithm = match.arg(algorithm)
  if (!is.raw(value)) bridge_abort("BRIDGE_HASH_INPUT_INVALID")
  if (identical(algorithm, "sha256")) {
    if (requireNamespace("openssl", quietly = TRUE)) {
      return(unclass(as.character(openssl::sha256(value))))
    }
    if (requireNamespace("digest", quietly = TRUE)) {
      return(digest::digest(value, algo = "sha256", serialize = FALSE))
    }
    bridge_abort("BRIDGE_SHA256_UNAVAILABLE")
  }
  path = tempfile("bridge-md5-")
  on.exit(unlink(path), add = TRUE)
  connection = file(path, open = "wb")
  writeBin(value, connection)
  close(connection)
  unname(tools::md5sum(path))
}

bridge_read_raw = function(path, maximum = 256 * 1024^2) {
  info = file.info(path)
  if (!nrow(info) || is.na(info$size[[1L]]) || info$size[[1L]] < 1 ||
      info$size[[1L]] > maximum || !isTRUE(file_test("-f", path))) {
    bridge_abort("BRIDGE_FILE_INVALID", path)
  }
  connection = file(path, open = "rb")
  on.exit(close(connection), add = TRUE)
  readBin(connection, "raw", n = as.integer(info$size[[1L]]))
}

bridge_hash_file = function(path, algorithm = c("sha256", "md5")) {
  bridge_hash_raw(bridge_read_raw(path), match.arg(algorithm))
}

bridge_object_fingerprint = function(value) {
  bridge_hash_raw(serialize(value, NULL, version = 3L), "md5")
}

bridge_resolve_path = function(root, relative, must_exist = TRUE) {
  if (!is.character(relative) || length(relative) != 1L ||
      is.na(relative) || !nzchar(relative) ||
      !identical(relative, trimws(relative)) ||
      grepl("[\r\n*?{}]", relative) ||
      grepl("[", relative, fixed = TRUE) ||
      grepl("]", relative, fixed = TRUE)) {
    bridge_abort("BRIDGE_PATH_INVALID", relative)
  }
  relative = gsub("\\", "/", relative, fixed = TRUE)
  components = strsplit(relative, "/", fixed = TRUE)[[1L]]
  if (startsWith(relative, "/") || grepl("^[A-Za-z]:", relative) ||
      any(components %in% c("", ".", ".."))) {
    bridge_abort("BRIDGE_PATH_INVALID", relative)
  }
  root = normalizePath(root, winslash = "/", mustWork = TRUE)
  candidate = do.call(file.path, as.list(c(root, components)))
  parent = normalizePath(dirname(candidate), winslash = "/", mustWork = TRUE)
  if (!identical(parent, root) &&
      !startsWith(parent, paste0(root, "/"))) {
    bridge_abort("BRIDGE_PATH_ESCAPE", relative)
  }
  if (isTRUE(must_exist) &&
      (!file.exists(candidate) || dir.exists(candidate) ||
       !isTRUE(file_test("-f", candidate)))) {
    bridge_abort("BRIDGE_PATH_MISSING", relative)
  }
  candidate
}

bridge_read_registry = function(
    path = bridge_registry_path(root), root = bridge_repository_root()) {
  value = tryCatch(
    read.dcf(path),
    error = function(error) bridge_abort(
      "BRIDGE_REGISTRY_INVALID", conditionMessage(error)
    )
  )
  value = as.data.frame(value, stringsAsFactors = FALSE, check.names = FALSE)
  if (!identical(names(value), bridge_registry_fields()) ||
      nrow(value) != 1L) {
    bridge_abort("BRIDGE_REGISTRY_FIELDS")
  }
  value[] = lapply(value, as.character)
  if (anyNA(value) || any(!nzchar(as.matrix(value))) ||
      any(as.matrix(value) != trimws(as.matrix(value)))) {
    bridge_abort("BRIDGE_REGISTRY_INCOMPLETE")
  }
  if (!identical(value[["Schema"]], "gemodelr-predecessor-lineage-v1") ||
      !identical(value[["Record-Id"]], "tablotr-0.1.0-bridge")) {
    bridge_abort("BRIDGE_REGISTRY_SCHEMA")
  }
  if (!identical(value[["Package-Name"]], "tabloToR") ||
      !identical(value[["Package-Version"]], "0.1.0")) {
    bridge_abort("BRIDGE_PACKAGE_IDENTITY")
  }
  if (!identical(
    value[["Source-Scope"]], bridge_source_scope_description()
  )) {
    bridge_abort("BRIDGE_SOURCE_SCOPE")
  }
  count = suppressWarnings(as.integer(value[["Source-File-Count"]]))
  if (is.na(count) || count < 1L ||
      !identical(as.character(count), value[["Source-File-Count"]])) {
    bridge_abort("BRIDGE_SOURCE_COUNT")
  }
  if (!grepl("^[0-9a-f]{32}$", value[["Source-Fingerprint"]]) ||
      !grepl("^[0-9a-f]{40}$", value[["Source-Immutable-Id"]])) {
    bridge_abort("BRIDGE_SOURCE_ID")
  }
  if (!value[["Source-Locator-Type"]] %in% c("unresolved", "git-commit")) {
    bridge_abort("BRIDGE_SOURCE_LOCATOR_TYPE")
  }
  if (identical(value[["Source-Locator-Type"]], "unresolved") &&
      !identical(value[["Source-Locator"]], "unresolved")) {
    bridge_abort("BRIDGE_SOURCE_LOCATOR")
  }
  if (!identical(
    value[["Fixture-Path"]],
    "tests/testthat/fixtures/serialization/tabloToR-schema1-lineage.rds"
  ) || !identical(
    value[["Tablo-Path"]], "tests/testthat/fixtures/three-region.tab"
  )) {
    bridge_abort("BRIDGE_EVIDENCE_PATH")
  }
  if (!identical(value[["Fixture-Digest-Algorithm"]], "sha256") ||
      !identical(value[["Tablo-Digest-Algorithm"]], "sha256") ||
      !grepl("^[0-9a-f]{64}$", value[["Fixture-Digest"]]) ||
      !grepl("^[0-9a-f]{64}$", value[["Tablo-Digest"]]) ||
      !grepl("^[0-9a-f]{32}$", value[["Data-Fingerprint"]])) {
    bridge_abort("BRIDGE_EVIDENCE_DIGEST")
  }
  if (!identical(value[["Install-Command"]], bridge_install_command()) ||
      !identical(
        value[["Conversion-Command"]], bridge_conversion_command()
      ) ||
      grepl("<[^>]+>|pending|placeholder",
            paste(value[["Install-Command"]],
                  value[["Conversion-Command"]]),
            ignore.case = TRUE)) {
    bridge_abort("BRIDGE_COMMAND")
  }
  if (!identical(value[["Lineage-Review-State"]], "reviewed") ||
      !value[["Reachability-Review-State"]] %in%
        c("unresolved", "approved")) {
    bridge_abort("BRIDGE_REVIEW_STATE")
  }
  invisible(value)
}

bridge_git_path = function() {
  candidates = c("/usr/bin/git", Sys.which("git"))
  candidates = candidates[nzchar(candidates) & file.exists(candidates)]
  if (!length(candidates)) bridge_abort("BRIDGE_GIT_UNAVAILABLE")
  normalizePath(candidates[[1L]], mustWork = TRUE)
}

bridge_run = function(command, arguments, directory = NULL,
                       environment = character()) {
  old = NULL
  if (!is.null(directory)) {
    old = setwd(directory)
    on.exit(setwd(old), add = TRUE)
  }
  output = system2(
    command, arguments, stdout = TRUE, stderr = TRUE, env = environment
  )
  status = attr(output, "status")
  if (is.null(status)) status = 0L
  if (!identical(as.integer(status), 0L)) {
    bridge_abort(
      "BRIDGE_COMMAND_FAILED",
      paste(c(command, arguments, output), collapse = "\n")
    )
  }
  output
}

bridge_source_candidates = function(root) {
  tracked = character()
  git_marker = file.path(root, ".git")
  if (file.exists(git_marker) || dir.exists(git_marker)) {
    git = bridge_git_path()
    tracked = tryCatch(
      suppressWarnings(bridge_run(
        git, c("-C", shQuote(root), "ls-files")
      )),
      error = function(error) character()
    )
  }
  if (length(tracked)) return(tracked)
  relative = list.files(
    root, recursive = TRUE, all.files = TRUE,
    full.names = FALSE, include.dirs = FALSE, no.. = TRUE
  )
  relative[!startsWith(relative, ".git/")]
}

bridge_source_files = function(root) {
  relative = bridge_source_candidates(root)
  keep = relative %in% c("DESCRIPTION", "NAMESPACE") |
    grepl("^(R|src|inst|tests/testthat|tools)/", relative)
  relative = relative[keep]
  relative = setdiff(
    relative,
    c(
      "inst/migration/predecessor-fingerprints.dcf",
      "tests/testthat/fixtures/serialization/tabloToR-schema1-lineage.rds"
    )
  )
  relative = unique(relative)
  relative = relative[order(relative, method = "radix")]
  paths = file.path(root, relative)
  regular = file.exists(paths) & !dir.exists(paths) &
    file_test("-f", paths)
  relative = relative[regular]
  if (!length(relative) || any(nzchar(Sys.readlink(file.path(root, relative))))) {
    bridge_abort("BRIDGE_SOURCE_FILES_INVALID")
  }
  relative
}

bridge_source_state = function(root) {
  root = normalizePath(root, winslash = "/", mustWork = TRUE)
  relative = bridge_source_files(root)
  paths = file.path(root, relative)
  sizes = file.info(paths)$size
  if (any(!is.finite(sizes)) || any(sizes > 5 * 1024^2)) {
    bridge_abort("BRIDGE_SOURCE_SIZE")
  }
  hashes = unname(tools::md5sum(paths))
  records = do.call(c, Map(function(path, hash) {
    c(charToRaw(path), as.raw(0), charToRaw(hash), charToRaw("\n"))
  }, relative, hashes))
  list(
    files = relative,
    count = as.integer(length(relative)),
    fingerprint = bridge_hash_raw(records, "md5")
  )
}

bridge_extract_local_source = function(root, immutable_id, destination) {
  if (!grepl("^[0-9a-f]{40}$", immutable_id)) {
    bridge_abort("BRIDGE_SOURCE_ID")
  }
  dir.create(destination, recursive = TRUE, showWarnings = FALSE)
  archive = tempfile("tablotr-bridge-", fileext = ".tar")
  on.exit(unlink(archive), add = TRUE)
  bridge_run(
    bridge_git_path(),
    c(
      "-C", shQuote(root), "archive", "--format=tar",
      paste0("--output=", shQuote(archive)), immutable_id
    )
  )
  utils::untar(archive, exdir = destination)
  if (!file.exists(file.path(destination, "DESCRIPTION"))) {
    bridge_abort("BRIDGE_ARCHIVE_INVALID")
  }
  normalizePath(destination, winslash = "/", mustWork = TRUE)
}

bridge_copy_file = function(source, destination) {
  dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
  if (!file.copy(source, destination, overwrite = TRUE, copy.mode = TRUE)) {
    bridge_abort("BRIDGE_COPY_FAILED", source)
  }
  invisible(destination)
}

bridge_install_source = function(source) {
  library = tempfile("tablotr-bridge-library-")
  dir.create(library, recursive = TRUE, showWarnings = FALSE)
  bridge_run(
    file.path(R.home("bin"), "R"),
    c(
      "CMD", "INSTALL", paste0("--library=", shQuote(library)),
      shQuote(source)
    )
  )
  installed = file.path(library, "tabloToR")
  if (!dir.exists(installed)) bridge_abort("BRIDGE_INSTALL_MISSING")
  list(
    library = normalizePath(library, winslash = "/", mustWork = TRUE),
    package = normalizePath(installed, winslash = "/", mustWork = TRUE)
  )
}

bridge_reproduce_fixture = function(source, output) {
  install = bridge_install_source(source)
  on.exit(unlink(install$library, recursive = TRUE, force = TRUE), add = TRUE)
  script = tempfile("tablotr-bridge-reproduce-", fileext = ".R")
  metadata = tempfile("tablotr-bridge-metadata-", fileext = ".rds")
  on.exit(unlink(c(script, metadata)), add = TRUE)
  lines = c(
    "args = commandArgs(trailingOnly = TRUE)",
    "library(tabloToR, lib.loc = args[[1L]], character.only = FALSE)",
    "regions = c('north', 'south', 'east')",
    "input = list(basedata = list(",
    "  weight = array(c(1, 1.5, 2), dim = 3L, dimnames = list(reg = regions)),",
    "  stock = array(c(100, 200, 300), dim = 3L, dimnames = list(reg = regions))",
    "))",
    "model = GEModel$new()",
    "model$loadTablo(file.path(args[[2L]], 'tests', 'testthat', 'fixtures', 'three-region.tab'))",
    "model$setClosure('tax')",
    "model$loadData(input, engine = 'sparse')",
    "model$saveState(args[[3L]])",
    "saveRDS(list(package = as.character(packageVersion('tabloToR')), package_path = find.package('tabloToR'), data_fingerprint = model$sourceData$data_fingerprint), args[[4L]], version = 3L)"
  )
  writeLines(lines, script, useBytes = TRUE)
  bridge_run(
    file.path(R.home("bin"), "Rscript"),
    c(
      "--vanilla", shQuote(script), shQuote(install$library),
      shQuote(source), shQuote(output), shQuote(metadata)
    )
  )
  result = readRDS(metadata)
  if (!identical(result$package, "0.1.0") ||
      !startsWith(
        normalizePath(result$package_path, winslash = "/", mustWork = TRUE),
        paste0(install$library, "/")
      )) {
    bridge_abort("BRIDGE_INSTALLED_IDENTITY")
  }
  result
}

bridge_validate_payload = function(payload, registry, source_root) {
  expected = c(
    "schema", "schema_version", "package_lineage", "source", "engine",
    "levels", "closure", "shocks", "accepted", "memory_budget",
    "diagnostics"
  )
  if (!is.list(payload) || is.object(payload) ||
      !identical(names(payload), expected) ||
      !identical(payload$schema, "gemodel-logical-state") ||
      !identical(payload$schema_version, 1L)) {
    bridge_abort("BRIDGE_FIXTURE_SCHEMA")
  }
  lineage = list(
    name = unname(registry[["Package-Name"]]),
    version = unname(registry[["Package-Version"]]),
    source_fingerprint = unname(registry[["Source-Fingerprint"]])
  )
  if (!identical(payload$package_lineage, lineage)) {
    bridge_abort("BRIDGE_FIXTURE_LINEAGE")
  }
  tablo = bridge_read_raw(file.path(
    source_root, "tests", "testthat", "fixtures", "three-region.tab"
  ))
  if (!identical(payload$source$tablo_source, tablo) ||
      !identical(
        payload$source$tablo_fingerprint,
        bridge_object_fingerprint(tablo)
      ) ||
      !identical(
        payload$source$data_fingerprint,
        bridge_object_fingerprint(payload$source$loaded_data)
      ) ||
      !identical(
        payload$source$data_fingerprint,
        unname(registry[["Data-Fingerprint"]])
      )) {
    bridge_abort("BRIDGE_FIXTURE_CONTENT")
  }
  invisible(payload)
}

bridge_verify_source = function(source_root, fixture, registry) {
  source_state = bridge_source_state(source_root)
  if (!identical(
    source_state$count,
    as.integer(registry[["Source-File-Count"]])
  ) || !identical(
    source_state$fingerprint,
    unname(registry[["Source-Fingerprint"]])
  )) {
    bridge_abort("BRIDGE_SOURCE_DRIFT")
  }
  description = read.dcf(file.path(source_root, "DESCRIPTION"))[1L, ]
  if (!identical(
    unname(description[["Package"]]), unname(registry[["Package-Name"]])
  ) || !identical(
    unname(description[["Version"]]), unname(registry[["Package-Version"]])
  )) {
    bridge_abort("BRIDGE_PACKAGE_IDENTITY")
  }
  tablo_path = file.path(source_root, registry[["Tablo-Path"]])
  if (!identical(
    bridge_hash_file(tablo_path, "sha256"),
    unname(registry[["Tablo-Digest"]])
  )) {
    bridge_abort("BRIDGE_TABLO_DRIFT")
  }
  payload = readRDS(fixture)
  bridge_validate_payload(payload, registry, source_root)
  reproduced = tempfile("tablotr-schema1-lineage-", fileext = ".rds")
  on.exit(unlink(reproduced), add = TRUE)
  metadata = bridge_reproduce_fixture(source_root, reproduced)
  reproduced_payload = readRDS(reproduced)
  bridge_validate_payload(reproduced_payload, registry, source_root)
  fixture_raw = bridge_read_raw(fixture)
  reproduced_raw = bridge_read_raw(reproduced)
  list(
    package_name = unname(description[["Package"]]),
    package_version = unname(description[["Version"]]),
    source_fingerprint = source_state$fingerprint,
    fixture_digest = bridge_hash_raw(fixture_raw, "sha256"),
    reproduced_digest = bridge_hash_raw(reproduced_raw, "sha256"),
    bytes_identical = identical(reproduced_raw, fixture_raw),
    content_identical = identical(reproduced_payload, payload),
    data_fingerprint = metadata$data_fingerprint,
    installed_package = metadata$package_path
  )
}

bridge_verify_local = function(root = bridge_repository_root()) {
  registry = bridge_read_registry(root = root)
  fixture = bridge_resolve_path(root, registry[["Fixture-Path"]])
  if (!identical(
    bridge_hash_file(fixture, "sha256"),
    unname(registry[["Fixture-Digest"]])
  )) {
    bridge_abort("BRIDGE_FIXTURE_DIGEST_DRIFT")
  }
  workspace = tempfile("tablotr-bridge-source-")
  on.exit(unlink(workspace, recursive = TRUE, force = TRUE), add = TRUE)
  source = bridge_extract_local_source(
    root, registry[["Source-Immutable-Id"]], workspace
  )
  result = bridge_verify_source(source, fixture, registry)
  result$commands_exact = identical(
    unname(registry[["Install-Command"]]), bridge_install_command()
  ) && identical(
    unname(registry[["Conversion-Command"]]), bridge_conversion_command()
  )
  result$clean = isTRUE(result$bytes_identical) &&
    isTRUE(result$content_identical) && isTRUE(result$commands_exact) &&
    identical(result$fixture_digest, result$reproduced_digest)
  if (!isTRUE(result$clean)) bridge_abort("BRIDGE_REPRODUCTION_DRIFT")
  result
}

bridge_fetch_reachable_source = function(registry, destination) {
  if (!identical(registry[["Source-Locator-Type"]], "git-commit") ||
      identical(registry[["Source-Locator"]], "unresolved")) {
    bridge_abort("BRIDGE_REACHABILITY_UNRESOLVED")
  }
  locator = unname(registry[["Source-Locator"]])
  if (!grepl("^(https://|ssh://)", locator)) {
    bridge_abort("BRIDGE_REACHABILITY_LOCATOR")
  }
  dir.create(destination, recursive = TRUE, showWarnings = FALSE)
  git = bridge_git_path()
  bridge_run(git, c("-C", shQuote(destination), "init", "--quiet"))
  bridge_run(git, c(
    "-C", shQuote(destination), "remote", "add", "origin", shQuote(locator)
  ))
  bridge_run(git, c(
    "-C", shQuote(destination), "fetch", "--quiet", "--depth=1", "origin",
    registry[["Source-Immutable-Id"]]
  ))
  bridge_run(git, c(
    "-C", shQuote(destination), "checkout", "--quiet", "--detach", "FETCH_HEAD"
  ))
  observed = bridge_run(git, c(
    "-C", shQuote(destination), "rev-parse", "HEAD"
  ))
  if (!identical(observed[[1L]], registry[["Source-Immutable-Id"]])) {
    bridge_abort("BRIDGE_REACHABILITY_ID")
  }
  normalizePath(destination, winslash = "/", mustWork = TRUE)
}

bridge_verify_reachable = function(root = bridge_repository_root()) {
  registry = bridge_read_registry(root = root)
  workspace = tempfile("tablotr-reachable-source-")
  on.exit(unlink(workspace, recursive = TRUE, force = TRUE), add = TRUE)
  source = bridge_fetch_reachable_source(registry, workspace)
  fixture = bridge_resolve_path(root, registry[["Fixture-Path"]])
  result = bridge_verify_source(source, fixture, registry)
  result$locator = unname(registry[["Source-Locator"]])
  result$immutable_id = unname(registry[["Source-Immutable-Id"]])
  result$install_command = unname(registry[["Install-Command"]])
  result$conversion_command = unname(registry[["Conversion-Command"]])
  result$clean = isTRUE(result$bytes_identical) &&
    isTRUE(result$content_identical) &&
    identical(result$fixture_digest, result$reproduced_digest)
  if (!isTRUE(result$clean)) bridge_abort("BRIDGE_REPRODUCTION_DRIFT")
  result
}

bridge_usage = function() {
  paste(
    "Usage:",
    "  rtk Rscript --vanilla tools/check_predecessor_bridge.R --verify-local",
    paste(
      "  rtk Rscript --vanilla tools/check_predecessor_bridge.R",
      "--verify-reachable"
    ),
    sep = "\n"
  )
}

bridge_main = function(arguments = commandArgs(trailingOnly = TRUE)) {
  if (identical(arguments, "--help")) {
    cat(bridge_usage(), "\n")
    return(invisible(0L))
  }
  if (identical(arguments, "--verify-local")) {
    result = bridge_verify_local()
    cat("Predecessor bridge local verification: PASS\n")
    cat(sprintf("Package: %s %s\n", result$package_name,
                result$package_version))
    cat(sprintf("Source-Fingerprint: %s\n", result$source_fingerprint))
    cat(sprintf("Fixture-SHA256: %s\n", result$fixture_digest))
    cat(sprintf("Reproduced-SHA256: %s\n", result$reproduced_digest))
    return(invisible(0L))
  }
  if (identical(arguments, "--verify-reachable")) {
    result = bridge_verify_reachable()
    cat("Predecessor bridge reachable verification: PASS\n")
    cat(sprintf("Locator: %s\n", result$locator))
    cat(sprintf("Immutable-Id: %s\n", result$immutable_id))
    cat(sprintf("Package: %s %s\n", result$package_name,
                result$package_version))
    cat(sprintf("Source-Fingerprint: %s\n", result$source_fingerprint))
    cat(sprintf("Fixture-SHA256: %s\n", result$fixture_digest))
    cat("Install-Command:\n", result$install_command, "\n")
    cat("Conversion-Command:\n", result$conversion_command, "\n")
    return(invisible(0L))
  }
  bridge_abort("BRIDGE_ARGUMENT_INVALID")
}

if (sys.nframe() == 0L) bridge_main()
