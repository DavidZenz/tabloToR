phase02_tool_path = function(name) {
  source_candidate = testthat::test_path("..", "..", "inst", "tools", name)
  if (file.exists(source_candidate)) {
    return(normalizePath(source_candidate, mustWork = TRUE))
  }
  installed_candidate = system.file("tools", name, package = "GEModelR")
  if (nzchar(installed_candidate)) {
    return(normalizePath(installed_candidate, mustWork = TRUE))
  }
  # Administrative tools are deliberately excluded from installed packages.
  # A missing tool in a source checkout must still fail rather than skip.
  phase02_require_source_tree()
  stop("Missing Phase 02 source tool: ", name, call. = FALSE)
}

phase02_cli_path = function(name) {
  source_candidate = testthat::test_path("..", "..", "tools", name)
  if (file.exists(source_candidate)) {
    return(normalizePath(source_candidate, mustWork = TRUE))
  }
  phase02_tool_path(name)
}

phase02_require_source_tree = function() {
  available = file.exists(testthat::test_path("..", "..", "DESCRIPTION")) &&
    dir.exists(testthat::test_path("..", "..", "R")) &&
    dir.exists(testthat::test_path("..", "..", "src"))
  testthat::skip_if_not(
    available,
    "Phase 02 proposal regeneration requires the package source tree"
  )
}

load_phase02_tool = function(name) {
  environment = new.env(parent = globalenv())
  sys.source(phase02_tool_path(name), envir = environment)
  environment
}

copy_phase02_artifacts = function(refresh, source, destination) {
  dir.create(destination, recursive = TRUE, showWarnings = FALSE)
  files = refresh$phase02_stable_artifact_names()
  files = files[file.exists(file.path(source, files))]
  copied = file.copy(
    file.path(source, files),
    file.path(destination, files)
  )
  stopifnot(all(copied))
  invisible(destination)
}

copy_phase02_canonical = function(refresh, destination) {
  copy_phase02_artifacts(refresh, refresh$phase02_canonical_dir(), destination)
}

copy_phase02_source_scope = function(refresh, destination) {
  root = refresh$phase02_repository_root()
  relative = refresh$phase02_identity_source_files(root)
  for (path in relative) {
    target = file.path(destination, path)
    dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
    stopifnot(file.copy(file.path(root, path), target))
  }
  invisible(destination)
}

read_phase02_source_text = function(path) {
  rawToChar(readBin(path, "raw", n = file.info(path)$size))
}

write_phase02_source_text = function(text, path) {
  connection = file(path, open = "wb")
  on.exit(close(connection), add = TRUE)
  writeBin(charToRaw(text), connection)
  invisible(path)
}

write_phase02_identity_map = function(value, path) {
  write.dcf(
    as.data.frame(value, stringsAsFactors = FALSE, check.names = FALSE),
    file = path, keep.white = names(value), useBytes = TRUE
  )
  invisible(path)
}

replace_phase02_source_identity = function(refresh, root, map) {
  for (relative in refresh$phase02_identity_source_files(root)) {
    path = file.path(root, relative)
    text = read_phase02_source_text(path)
    for (index in seq_len(nrow(map))) {
      text = gsub(
        map[index, "Predecessor"], map[index, "Current"], text,
        fixed = TRUE
      )
    }
    write_phase02_source_text(text, path)
  }
  invisible(root)
}

mutate_phase02_source = function(root, relative, old, new) {
  path = file.path(root, relative)
  text = read_phase02_source_text(path)
  stopifnot(grepl(old, text, fixed = TRUE))
  text = sub(old, new, text, fixed = TRUE)
  write_phase02_source_text(text, path)
  invisible(root)
}
