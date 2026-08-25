#!/usr/bin/env Rscript

name_check_source_ids = function() {
  c(
    "cran-current", "cran-archive", "bioconductor-current",
    "bioconductor-history", "r-universe", "github"
  )
}

name_check_source_labels = function() {
  stats::setNames(c(
    "CRAN current", "CRAN archive", "Bioconductor current",
    "Bioconductor history", "R-universe", "GitHub"
  ), name_check_source_ids())
}

name_check_reason_suffix = function(source_id) {
  toupper(gsub("-", "_", source_id, fixed = TRUE))
}

name_check_fail = function(reason) {
  stop(as.character(reason)[[1L]], call. = FALSE)
}

name_check_validate_name = function(name) {
  valid = is.character(name) && length(name) == 1L && !is.na(name) &&
    nzchar(name) && nchar(name, type = "bytes") >= 2L &&
    identical(Encoding(name), "unknown") &&
    grepl("^[A-Za-z][A-Za-z0-9.]+$", name) &&
    !endsWith(name, ".")
  if (!valid) name_check_fail("NAME_SYNTAX_INVALID")
  name
}

name_check_ascii_fold = function(value) {
  chartr("ABCDEFGHIJKLMNOPQRSTUVWXYZ", "abcdefghijklmnopqrstuvwxyz", value)
}

name_check_exact_matches = function(name, candidates) {
  name_check_validate_name(name)
  if (!is.character(candidates)) {
    name_check_fail("NAME_CANDIDATES_INVALID")
  }
  candidates = candidates[!is.na(candidates)]
  candidates[name_check_ascii_fold(candidates) == name_check_ascii_fold(name)]
}

name_check_raw_text = function(value, source_id) {
  if (!is.raw(value)) {
    name_check_fail(paste0(
      "NAME_SOURCE_UNHASHABLE_", name_check_reason_suffix(source_id)
    ))
  }
  tryCatch(
    rawToChar(value),
    error = function(error) name_check_fail(paste0(
      "NAME_SOURCE_MALFORMED_", name_check_reason_suffix(source_id)
    ))
  )
}

name_check_raw_hash = function(value, source_id) {
  if (!is.raw(value)) {
    name_check_fail(paste0(
      "NAME_SOURCE_UNHASHABLE_", name_check_reason_suffix(source_id)
    ))
  }
  path = tempfile("GEModelR-name-response-")
  on.exit(unlink(path), add = TRUE)
  result = tryCatch({
    writeBin(value, path, useBytes = TRUE)
    unname(tools::md5sum(path)[[1L]])
  }, error = function(error) NA_character_)
  if (!is.character(result) || length(result) != 1L || is.na(result) ||
      !grepl("^[0-9a-f]{32}$", result)) {
    name_check_fail(paste0(
      "NAME_SOURCE_UNHASHABLE_", name_check_reason_suffix(source_id)
    ))
  }
  result
}

name_check_regex_values = function(text, pattern, replacement) {
  matches = regmatches(text, gregexpr(pattern, text, perl = TRUE))[[1L]]
  if (!length(matches) || identical(matches, character())) return(character())
  sub(pattern, replacement, matches, perl = TRUE)
}

name_check_parse_packages = function(text, source_id) {
  if (!grepl("(^|\n)Package:[[:space:]]*", text, perl = TRUE)) {
    name_check_fail(paste0(
      "NAME_SOURCE_MALFORMED_", name_check_reason_suffix(source_id)
    ))
  }
  lines = strsplit(text, "\n", fixed = TRUE)[[1L]]
  package_lines = grep("^Package:[[:space:]]*", lines, value = TRUE)
  values = sub("^Package:[[:space:]]*", "", package_lines)
  values = trimws(values)
  if (!length(values) || any(!grepl("^[A-Za-z][A-Za-z0-9.]*$", values))) {
    name_check_fail(paste0(
      "NAME_SOURCE_MALFORMED_", name_check_reason_suffix(source_id)
    ))
  }
  values
}

name_check_parse_archive = function(text, source_id) {
  html_like = grepl("<html|<!DOCTYPE|href=", text, ignore.case = TRUE)
  if (!html_like) {
    name_check_fail(paste0(
      "NAME_SOURCE_MALFORMED_", name_check_reason_suffix(source_id)
    ))
  }
  values = name_check_regex_values(
    text,
    "href=[\"']([A-Za-z][A-Za-z0-9.]*)/[\"']",
    "\\1"
  )
  values
}

name_check_parse_runiverse = function(text, source_id) {
  if (!grepl("\"results\"[[:space:]]*:", text) ||
      (!grepl("\"total\"[[:space:]]*:", text) &&
       !grepl("\"limit\"[[:space:]]*:", text))) {
    name_check_fail(paste0(
      "NAME_SOURCE_MALFORMED_", name_check_reason_suffix(source_id)
    ))
  }
  name_check_regex_values(
    text,
    '"Package"[[:space:]]*:[[:space:]]*"([A-Za-z][A-Za-z0-9.]*)"',
    "\\1"
  )
}

name_check_parse_github = function(text, source_id) {
  if (!grepl('"items"[[:space:]]*:', text) ||
      !grepl('"total_count"[[:space:]]*:', text)) {
    name_check_fail(paste0(
      "NAME_SOURCE_MALFORMED_", name_check_reason_suffix(source_id)
    ))
  }
  full_names = name_check_regex_values(
    text,
    "\"full_name\"[[:space:]]*:[[:space:]]*\"[^\"/]+[/]([A-Za-z][A-Za-z0-9.]*)\"",
    "\\1"
  )
  full_names
}

name_check_parse_source = function(source_id, value) {
  text = name_check_raw_text(value, source_id)
  if (source_id %in% c(
    "cran-current", "bioconductor-current", "bioconductor-history"
  )) {
    return(name_check_parse_packages(text, source_id))
  }
  if (identical(source_id, "cran-archive")) {
    return(name_check_parse_archive(text, source_id))
  }
  if (identical(source_id, "r-universe")) {
    return(name_check_parse_runiverse(text, source_id))
  }
  if (identical(source_id, "github")) {
    return(name_check_parse_github(text, source_id))
  }
  name_check_fail("NAME_SOURCE_UNKNOWN")
}

name_check_validate_kind = function(check_kind) {
  if (!is.character(check_kind) || length(check_kind) != 1L ||
      is.na(check_kind) ||
      !check_kind %in% c("initial", "reservation", "release")) {
    name_check_fail("NAME_CHECK_KIND_INVALID")
  }
  check_kind
}

name_check_timestamp = function() {
  format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

name_check_evaluate_fixture = function(name, sources,
                                        check_kind = "initial",
                                        checked_at = name_check_timestamp(),
                                        fail_on_collision = TRUE) {
  name = name_check_validate_name(name)
  check_kind = name_check_validate_kind(check_kind)
  if (!is.character(checked_at) || length(checked_at) != 1L ||
      !grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$",
             checked_at)) {
    name_check_fail("NAME_CHECK_TIMESTAMP_INVALID")
  }
  required = name_check_source_ids()
  source_ids = vapply(sources, function(source) {
    if (is.list(source) && length(source$id) == 1L) {
      as.character(source$id)
    } else {
      ""
    }
  }, character(1))
  for (source_id in required) {
    if (sum(source_ids == source_id) != 1L) {
      name_check_fail(paste0(
        "NAME_SOURCE_MISSING_", name_check_reason_suffix(source_id)
      ))
    }
  }
  if (length(sources) != length(required) || any(!source_ids %in% required)) {
    name_check_fail("NAME_SOURCE_SET_INVALID")
  }
  sources = sources[match(required, source_ids)]
  labels = name_check_source_labels()
  rows = vector("list", length(required))
  collisions = character()
  for (index in seq_along(required)) {
    source_id = required[[index]]
    source = sources[[index]]
    if (!isTRUE(source$available)) {
      name_check_fail(paste0(
        "NAME_SOURCE_UNAVAILABLE_", name_check_reason_suffix(source_id)
      ))
    }
    if (!is.character(source$query) || length(source$query) != 1L ||
        !nzchar(source$query)) {
      name_check_fail(paste0(
        "NAME_SOURCE_MALFORMED_", name_check_reason_suffix(source_id)
      ))
    }
    raw_md5 = name_check_raw_hash(source$raw, source_id)
    candidates = name_check_parse_source(source_id, source$raw)
    exact = name_check_exact_matches(name, candidates)
    exact = unique(exact)
    if (length(exact)) {
      collisions = c(collisions, paste0(source_id, ":", exact))
    }
    rows[[index]] = data.frame(
      source_id = source_id,
      source = unname(labels[[source_id]]),
      query = source$query,
      available = "yes",
      raw_md5 = raw_md5,
      exact_matches = if (length(exact)) paste(exact, collapse = ",") else "NONE",
      result = if (length(exact)) "collision" else "pass",
      stringsAsFactors = FALSE
    )
  }
  source_frame = do.call(rbind, rows)
  rownames(source_frame) = NULL
  result = list(
    name = name,
    check_kind = check_kind,
    checked_at_utc = checked_at,
    overall_result = if (length(collisions)) {
      "NAME_EXACT_COLLISION"
    } else {
      "NAME_AVAILABLE_NO_EXACT_COLLISION"
    },
    sources = source_frame,
    collisions = collisions
  )
  if (length(collisions) && isTRUE(fail_on_collision)) {
    condition = simpleError("NAME_EXACT_COLLISION")
    attr(condition, "name_check_result") = result
    stop(condition)
  }
  result
}

name_check_markdown_escape = function(value) {
  gsub("|", "&#124;", value, fixed = TRUE)
}

name_check_write_report = function(result, output) {
  parent = dirname(output)
  if (!dir.exists(parent)) dir.create(parent, recursive = TRUE)
  output = normalizePath(output, mustWork = FALSE)
  rows = result$sources
  table_rows = vapply(seq_len(nrow(rows)), function(index) {
    paste0(
      "| ", name_check_markdown_escape(rows$source[[index]]),
      " | `", name_check_markdown_escape(rows$query[[index]]),
      "` | ", rows$available[[index]],
      " | `", rows$raw_md5[[index]],
      "` | ", name_check_markdown_escape(rows$exact_matches[[index]]),
      " | ", rows$result[[index]], " |"
    )
  }, character(1))
  machine_rows = vapply(seq_len(nrow(rows)), function(index) {
    paste0(
      "Source-Row: ", rows$source_id[[index]],
      "|available=", rows$available[[index]],
      "|raw-md5=", rows$raw_md5[[index]],
      "|matches=", rows$exact_matches[[index]],
      "|result=", rows$result[[index]],
      "|query=", rows$query[[index]]
    )
  }, character(1))
  lines = c(
    "# GEModelR Name Availability Evidence",
    "",
    "## Configuration",
    "",
    paste0("Name: ", result$name),
    paste0("Check-Kind: ", result$check_kind),
    paste0("Checked-At-UTC: ", result$checked_at_utc),
    paste0("Overall-Result: ", result$overall_result),
    "Reviewer: awaiting-human-approval",
    "Review-Date-UTC: awaiting-human-approval",
    "",
    "The check uses ASCII case-folded exact matching. Substrings and Unicode",
    "lookalikes are not exact package or repository-name collisions.",
    "",
    "## Results",
    "",
    paste0(
      "| Source | Query identity | Available | Raw MD5 | Exact matches | Result |"
    ),
    "| --- | --- | --- | --- | --- | --- |",
    table_rows,
    "",
    "## Machine-readable source rows",
    "",
    machine_rows,
    "",
    "## Reproduction",
    "",
    paste0(
      "Run `Rscript --vanilla tools/check_name_availability.R --name ",
      result$name, " --output docs/release/NAME-CHECK.md --check-kind ",
      result$check_kind, "`."
    ),
    "A fresh `reservation` check is required immediately before repository",
    "reservation. A fresh `release` check is required immediately before",
    "release or publication.",
    "",
    "## Scope and privacy boundary",
    "",
    "This is point-in-time exact-name collision evidence. It is not trademark clearance,",
    "not a reservation, and not evidence that the name remains available later.",
    "Only public query identities, hashes, and exact names are recorded; credentials,",
    "private correspondence, and private repository metadata are excluded."
  )
  writeLines(lines, output, useBytes = TRUE)
  invisible(output)
}

name_check_marker = function(lines, field) {
  pattern = paste0("^", field, ":[[:space:]]*(.*)$")
  hits = grep(pattern, lines, value = TRUE)
  sub(pattern, "\\1", hits)
}

name_check_verify_report = function(path, require_review = TRUE) {
  if (!file.exists(path)) name_check_fail("NAME_REPORT_MISSING")
  lines = tryCatch(
    readLines(path, warn = FALSE, encoding = "UTF-8"),
    error = function(error) name_check_fail("NAME_REPORT_MALFORMED")
  )
  fields = c(
    "Name", "Check-Kind", "Checked-At-UTC", "Overall-Result",
    "Reviewer", "Review-Date-UTC"
  )
  values = lapply(fields, function(field) name_check_marker(lines, field))
  names(values) = fields
  if (any(vapply(values, length, integer(1)) != 1L)) {
    name_check_fail("NAME_REPORT_MALFORMED")
  }
  values = vapply(values, `[[`, character(1), 1L)
  name_check_validate_name(values[["Name"]])
  name_check_validate_kind(values[["Check-Kind"]])
  valid_result = identical(
    values[["Overall-Result"]], "NAME_AVAILABLE_NO_EXACT_COLLISION"
  )
  if (!valid_result) name_check_fail("NAME_REPORT_NOT_CLEAR")
  if (!grepl(
    "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$",
    values[["Checked-At-UTC"]]
  )) {
    name_check_fail("NAME_REPORT_MALFORMED")
  }
  source_rows = grep("^Source-Row: ", lines, value = TRUE)
  source_ids = sub("^Source-Row: ([^|]+).*$", "\\1", source_rows)
  if (!identical(source_ids, name_check_source_ids()) ||
      any(!grepl("\\|available=yes\\|", source_rows)) ||
      any(!grepl("\\|raw-md5=[0-9a-f]{32}\\|", source_rows)) ||
      any(!grepl("\\|matches=NONE\\|result=pass\\|", source_rows))) {
    name_check_fail("NAME_REPORT_SOURCE_ROWS_INVALID")
  }
  pending = "awaiting-human-approval"
  if (isTRUE(require_review) &&
      (identical(values[["Reviewer"]], pending) ||
       identical(values[["Review-Date-UTC"]], pending))) {
    name_check_fail("NAME_REPORT_REVIEW_UNAPPROVED")
  }
  if (isTRUE(require_review) &&
      (!nzchar(values[["Reviewer"]]) ||
       !grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}(T[0-9]{2}:[0-9]{2}:[0-9]{2}Z)?$",
              values[["Review-Date-UTC"]]))) {
    name_check_fail("NAME_REPORT_REVIEW_INVALID")
  }
  TRUE
}

name_check_identity_fields = function(record) {
  if (identical(record, "governance")) {
    return(c(
      "Maintainer", "Approved-Contact", "Release-Authority",
      "Security-Route", "Identity-Approval", "Reviewer",
      "Review-Date-UTC"
    ))
  }
  if (identical(record, "repository")) {
    return(c(
      "Owner-Slug", "Repository-Name", "Canonical-URL", "Issue-Tracker",
      "Visibility-Boundary", "Identity-Approval", "Reviewer",
      "Review-Date-UTC", "Reservation-Authorization",
      "Visibility-Detachment-Authorization", "Branch-Settings-Authorization",
      "Release-Authorization"
    ))
  }
  name_check_fail("NAME_IDENTITY_RECORD_INVALID")
}

name_check_read_identity = function(path, record) {
  suffix = toupper(record)
  if (!file.exists(path)) {
    name_check_fail(paste0("NAME_IDENTITY_", suffix, "_MISSING"))
  }
  lines = tryCatch(
    readLines(path, warn = FALSE, encoding = "UTF-8"),
    error = function(error) name_check_fail(paste0(
      "NAME_IDENTITY_", suffix, "_MALFORMED"
    ))
  )
  fields = name_check_identity_fields(record)
  values = lapply(fields, function(field) name_check_marker(lines, field))
  names(values) = fields
  if (any(vapply(values, length, integer(1)) != 1L)) {
    name_check_fail(paste0("NAME_IDENTITY_", suffix, "_MALFORMED"))
  }
  values = vapply(values, `[[`, character(1), 1L)
  if (any(is.na(values)) || any(!nzchar(values)) ||
      any(values != trimws(values))) {
    name_check_fail(paste0("NAME_IDENTITY_", suffix, "_MALFORMED"))
  }
  values
}

name_check_valid_email = function(value) {
  is.character(value) && length(value) == 1L && !is.na(value) &&
    grepl(
      "^[^[:space:]<>@]+@[^[:space:]<>@.]+([.][^[:space:]<>@.]+)+$",
      value
    )
}

name_check_valid_security_route = function(value) {
  name_check_valid_email(value) ||
    (startsWith(value, "mailto:") &&
       name_check_valid_email(sub("^mailto:", "", value))) ||
    grepl("^https://[^[:space:]]+$", value)
}

name_check_valid_github_owner = function(value) {
  grepl("^[A-Za-z0-9]([A-Za-z0-9-]{0,37}[A-Za-z0-9])?$", value)
}

name_check_valid_review_date = function(value) {
  grepl(
    "^[0-9]{4}-[0-9]{2}-[0-9]{2}(T[0-9]{2}:[0-9]{2}:[0-9]{2}Z)?$",
    value
  )
}

name_check_verify_identity = function(governance_path, repository_path,
                                       expect = "unapproved") {
  if (!is.character(expect) || length(expect) != 1L || is.na(expect) ||
      !expect %in% c("unapproved", "approved")) {
    name_check_fail("NAME_IDENTITY_EXPECT_INVALID")
  }
  governance = name_check_read_identity(governance_path, "governance")
  repository = name_check_read_identity(repository_path, "repository")

  if (!identical(governance[["Maintainer"]], "David Zenz") ||
      !identical(governance[["Release-Authority"]], "David Zenz") ||
      !identical(repository[["Repository-Name"]], "GEModelR") ||
      !identical(repository[["Visibility-Boundary"]], "private-development")) {
    name_check_fail("NAME_IDENTITY_LOCKED_VALUE_MISMATCH")
  }

  authorization_fields = c(
    "Reservation-Authorization", "Visibility-Detachment-Authorization",
    "Branch-Settings-Authorization", "Release-Authorization"
  )
  if (any(repository[authorization_fields] != "not-authorized")) {
    name_check_fail("NAME_IDENTITY_EXTERNAL_ACTION_AUTHORIZED")
  }

  pending = "awaiting-human-approval"
  if (identical(expect, "unapproved")) {
    governance_pending = c(
      "Approved-Contact", "Security-Route", "Reviewer", "Review-Date-UTC"
    )
    repository_pending = c(
      "Owner-Slug", "Canonical-URL", "Issue-Tracker", "Reviewer",
      "Review-Date-UTC"
    )
    if (!identical(governance[["Identity-Approval"]], "unapproved") ||
        !identical(repository[["Identity-Approval"]], "unapproved") ||
        any(governance[governance_pending] != pending) ||
        any(repository[repository_pending] != pending)) {
      name_check_fail("NAME_IDENTITY_UNAPPROVED_INVALID")
    }
    return(TRUE)
  }

  if (!identical(governance[["Identity-Approval"]], "approved") ||
      !identical(repository[["Identity-Approval"]], "approved") ||
      any(governance == pending) || any(repository == pending)) {
    name_check_fail("NAME_IDENTITY_APPROVAL_INCOMPLETE")
  }
  if (!name_check_valid_email(governance[["Approved-Contact"]])) {
    name_check_fail("NAME_IDENTITY_CONTACT_INVALID")
  }
  if (!name_check_valid_security_route(governance[["Security-Route"]])) {
    name_check_fail("NAME_IDENTITY_SECURITY_ROUTE_INVALID")
  }
  owner = repository[["Owner-Slug"]]
  if (!name_check_valid_github_owner(owner)) {
    name_check_fail("NAME_IDENTITY_OWNER_SLUG_INVALID")
  }
  canonical = paste0("https://github.com/", owner, "/GEModelR")
  if (!identical(repository[["Canonical-URL"]], canonical) ||
      !identical(repository[["Issue-Tracker"]], paste0(canonical, "/issues"))) {
    name_check_fail("NAME_IDENTITY_URL_MISMATCH")
  }
  if (!identical(governance[["Reviewer"]], repository[["Reviewer"]]) ||
      !identical(
        governance[["Review-Date-UTC"]], repository[["Review-Date-UTC"]]
      ) || !nzchar(governance[["Reviewer"]]) ||
      !name_check_valid_review_date(governance[["Review-Date-UTC"]])) {
    name_check_fail("NAME_IDENTITY_SIGNATURE_MISMATCH")
  }
  TRUE
}

name_check_download = function(url, source_id, timeout_seconds = 30L,
                                maximum_bytes = 100 * 1024^2) {
  path = tempfile(paste0("GEModelR-", source_id, "-"))
  on.exit(unlink(path), add = TRUE)
  old_timeout = getOption("timeout")
  on.exit(options(timeout = old_timeout), add = TRUE)
  options(timeout = max(1L, as.integer(timeout_seconds)))
  status = tryCatch(
    suppressWarnings(utils::download.file(
      url, path, quiet = TRUE, mode = "wb", method = "libcurl",
      headers = c(
        `User-Agent` = "GEModelR-name-check/1",
        Accept = "application/vnd.github+json, application/json, text/plain, text/html"
      )
    )),
    error = function(error) 1L
  )
  size = if (file.exists(path)) file.info(path)$size else NA_real_
  if (!isTRUE(status == 0L) || is.na(size) || size <= 0 ||
      size > maximum_bytes) {
    name_check_fail(paste0(
      "NAME_SOURCE_UNAVAILABLE_", name_check_reason_suffix(source_id)
    ))
  }
  readBin(path, what = "raw", n = size)
}

name_check_bioc_versions = function(release_index) {
  text = name_check_raw_text(release_index, "bioconductor-history")
  matches = name_check_regex_values(
    text, '<tr>[[:space:]]*<td style="text-align: left">(?:<a[^>]*>)?([0-9]+[.][0-9]+)(?:</a>)?</td>', paste0(intToUtf8(92L), "1")
  )
  versions = unique(matches)
  versions = versions[grepl("^[0-9]+[.][0-9]+$", versions)]
  if (length(versions) < 2L) {
    name_check_fail("NAME_SOURCE_MALFORMED_BIOCONDUCTOR_HISTORY")
  }
  versions[order(as.numeric(sub("[.].*$", "", versions)),
                 as.numeric(sub("^.*[.]", "", versions)), decreasing = TRUE)]
}

name_check_bioc_history = function(timeout_seconds = 30L) {
  index_url = "https://bioconductor.org/about/release-announcements/"
  release_index = name_check_download(
    index_url, "bioconductor-history", timeout_seconds
  )
  versions = name_check_bioc_versions(release_index)
  historical = versions[-1L]
  indexed = historical[as.numeric(historical) >= 1.8]
  chunks = list(release_index)
  for (version in indexed) {
    url = paste0(
      "https://bioconductor.org/packages/", version,
      "/bioc/src/contrib/PACKAGES"
    )
    payload = name_check_download(
      url, "bioconductor-history", timeout_seconds
    )
    boundary = charToRaw(paste0(
      "\nBioconductor-Version: ", version, "\n"
    ))
    chunks = c(chunks, list(boundary, payload))
  }
  list(
    raw = do.call(c, chunks),
    query = paste0(
      index_url,
      " + https://bioconductor.org/packages/{version}/bioc/src/contrib/PACKAGES",
      " [indexed package manifests: ", paste(indexed, collapse = ","), "]"
    )
  )
}

name_check_collect_live = function(name, timeout_seconds = 30L) {
  name = name_check_validate_name(name)
  encoded = utils::URLencode(name, reserved = TRUE)
  definitions = list(
    list(
      id = "cran-current",
      query = "https://cran.r-project.org/src/contrib/PACKAGES",
      url = "https://cran.r-project.org/src/contrib/PACKAGES"
    ),
    list(
      id = "cran-archive",
      query = "https://cran.r-project.org/src/contrib/Archive/",
      url = "https://cran.r-project.org/src/contrib/Archive/"
    ),
    list(
      id = "bioconductor-current",
      query = "https://bioconductor.org/packages/release/bioc/src/contrib/PACKAGES",
      url = "https://bioconductor.org/packages/release/bioc/src/contrib/PACKAGES"
    ),
    list(
      id = "r-universe",
      query = paste0(
        "https://r-universe.dev/api/search?q=package%3A", encoded,
        "&limit=100"
      ),
      url = paste0(
        "https://r-universe.dev/api/search?q=package%3A", encoded,
        "&limit=100"
      )
    ),
    list(
      id = "github",
      query = paste0(
        "https://api.github.com/search/repositories?q=", encoded,
        "%20in%3Aname&per_page=100"
      ),
      url = paste0(
        "https://api.github.com/search/repositories?q=", encoded,
        "%20in%3Aname&per_page=100"
      )
    )
  )
  collected = lapply(definitions, function(definition) {
    list(
      id = definition$id,
      query = definition$query,
      available = TRUE,
      raw = name_check_download(
        definition$url, definition$id, timeout_seconds
      )
    )
  })
  history = name_check_bioc_history(timeout_seconds)
  collected = append(collected, list(list(
    id = "bioconductor-history",
    query = history$query,
    available = TRUE,
    raw = history$raw
  )), after = 3L)
  collected
}

name_check_test_fixture = function(package = "AnotherPackage") {
  payloads = list(
    `cran-current` = charToRaw(paste0("Package: ", package, "\nVersion: 1\n")),
    `cran-archive` = charToRaw(paste0(
      "<html><a href=\"", package, "/\">", package, "</a></html>"
    )),
    `bioconductor-current` = charToRaw(paste0(
      "Package: ", package, "\nVersion: 1\n"
    )),
    `bioconductor-history` = charToRaw(paste0(
      "Bioconductor-Version: 3.22\nPackage: ", package, "\nVersion: 1\n"
    )),
    `r-universe` = charToRaw(paste0(
      '{"results":[{"Package":"', package, '"}],"total":1}'
    )),
    github = charToRaw(paste0(
      '{"items":[{"full_name":"owner/', package,
      '"}],"total_count":1}'
    ))
  )
  lapply(name_check_source_ids(), function(source_id) {
    list(
      id = source_id,
      query = paste0("https://fixture.invalid/", source_id),
      available = TRUE,
      raw = payloads[[source_id]]
    )
  })
}

name_check_expect_failure = function(expression, reason) {
  observed = tryCatch({
    force(expression)
    ""
  }, error = function(error) conditionMessage(error))
  if (!identical(observed, reason)) {
    stop(sprintf("Expected %s, observed %s", reason, observed), call. = FALSE)
  }
  TRUE
}

name_check_self_test = function() {
  invalid = list(NULL, "", "G", "GEModelR.", "GE-ModelR", "GЕModelR")
  for (value in invalid) {
    name_check_expect_failure(
      name_check_validate_name(value), "NAME_SYNTAX_INVALID"
    )
  }
  stopifnot(identical(
    name_check_exact_matches(
      "GEModelR", c("gemodelr", "GEModelRtools", "GЕModelR")
    ),
    "gemodelr"
  ))
  clean = name_check_evaluate_fixture(
    "GEModelR", name_check_test_fixture(), checked_at = "2026-08-25T00:00:00Z"
  )
  stopifnot(
    identical(clean$overall_result, "NAME_AVAILABLE_NO_EXACT_COLLISION"),
    identical(clean$sources$source_id, name_check_source_ids())
  )
  collision = name_check_test_fixture()
  collision[[6L]]$raw = charToRaw(paste0(
    '{"items":[{"full_name":"owner/gemodelr"}],"total_count":1}'
  ))
  name_check_expect_failure(
    name_check_evaluate_fixture("GEModelR", collision),
    "NAME_EXACT_COLLISION"
  )
  unavailable = name_check_test_fixture()
  unavailable[[2L]]$available = FALSE
  name_check_expect_failure(
    name_check_evaluate_fixture("GEModelR", unavailable),
    "NAME_SOURCE_UNAVAILABLE_CRAN_ARCHIVE"
  )
  malformed = name_check_test_fixture()
  malformed[[3L]]$raw = charToRaw("malformed")
  name_check_expect_failure(
    name_check_evaluate_fixture("GEModelR", malformed),
    "NAME_SOURCE_MALFORMED_BIOCONDUCTOR_CURRENT"
  )
  unhashable = name_check_test_fixture()
  unhashable[[4L]]$raw = environment()
  name_check_expect_failure(
    name_check_evaluate_fixture("GEModelR", unhashable),
    "NAME_SOURCE_UNHASHABLE_BIOCONDUCTOR_HISTORY"
  )
  path = tempfile("GEModelR-name-report-", fileext = ".md")
  on.exit(unlink(path), add = TRUE)
  name_check_write_report(clean, path)
  stopifnot(name_check_verify_report(path, require_review = FALSE))
  message("self_test=pass")
  invisible(TRUE)
}

name_check_cli_value = function(args, flag, required = FALSE, default = NULL) {
  exact = which(args == flag)
  joined = grep(paste0("^", flag, "="), args)
  values = character()
  if (length(exact)) {
    for (index in exact) {
      if (index == length(args)) name_check_fail("NAME_ARGUMENT_MISSING_VALUE")
      values = c(values, args[[index + 1L]])
    }
  }
  if (length(joined)) {
    values = c(values, sub(paste0("^", flag, "="), "", args[joined]))
  }
  if (!length(values)) {
    if (required) name_check_fail("NAME_ARGUMENT_REQUIRED")
    return(default)
  }
  if (length(values) != 1L || !nzchar(values)) {
    name_check_fail("NAME_ARGUMENT_INVALID")
  }
  values[[1L]]
}

name_check_main = function(args = commandArgs(trailingOnly = TRUE)) {
  if ("--self-test" %in% args) {
    name_check_self_test()
    return(invisible(TRUE))
  }
  verify_report = name_check_cli_value(args, "--verify-report")
  if (!is.null(verify_report)) {
    name_check_verify_report(verify_report, require_review = TRUE)
    message("report_status=approved")
    return(invisible(TRUE))
  }
  if ("--verify-identity" %in% args) {
    index = which(args == "--verify-identity")
    if (length(index) != 1L || index + 2L > length(args) ||
        startsWith(args[[index + 1L]], "--") ||
        startsWith(args[[index + 2L]], "--")) {
      name_check_fail("NAME_IDENTITY_ARGUMENTS_INVALID")
    }
    expect = name_check_cli_value(
      args, "--expect", required = TRUE
    )
    name_check_verify_identity(
      args[[index + 1L]], args[[index + 2L]], expect = expect
    )
    message(paste0("identity_status=", expect))
    return(invisible(TRUE))
  }
  name = name_check_cli_value(args, "--name", required = TRUE)
  output = name_check_cli_value(args, "--output", required = TRUE)
  check_kind = name_check_cli_value(
    args, "--check-kind", default = "initial"
  )
  sources = name_check_collect_live(name)
  result = name_check_evaluate_fixture(
    name, sources, check_kind = check_kind, fail_on_collision = FALSE
  )
  name_check_write_report(result, output)
  if (!identical(
    result$overall_result, "NAME_AVAILABLE_NO_EXACT_COLLISION"
  )) {
    name_check_fail("NAME_EXACT_COLLISION")
  }
  message("overall_result=NAME_AVAILABLE_NO_EXACT_COLLISION")
  invisible(TRUE)
}

if (sys.nframe() == 0L) {
  tryCatch(
    name_check_main(),
    error = function(error) {
      message(conditionMessage(error))
      quit(save = "no", status = 1L, runLast = FALSE)
    }
  )
}
