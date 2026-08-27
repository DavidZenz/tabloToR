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

name_check_ascii_valid = function(value) {
  if (!is.character(value) || anyNA(value) || any(!nzchar(value))) {
    return(FALSE)
  }
  converted = suppressWarnings(iconv(
    value, from = "UTF-8", to = "ASCII", sub = NA_character_
  ))
  all(!is.na(converted))
}

name_check_exact_matches = function(name, candidates) {
  name_check_validate_name(name)
  if (!name_check_ascii_valid(candidates) && length(candidates)) {
    name_check_fail("NAME_CANDIDATES_INVALID")
  }
  if (!is.character(candidates)) {
    name_check_fail("NAME_CANDIDATES_INVALID")
  }
  candidates[name_check_ascii_fold(candidates) == name_check_ascii_fold(name)]
}

name_check_raw_text = function(value, source_id) {
  if (!is.raw(value)) {
    name_check_fail(paste0(
      "NAME_SOURCE_UNHASHABLE_", name_check_reason_suffix(source_id)
    ))
  }
  text = tryCatch(
    rawToChar(value),
    error = function(error) name_check_fail(paste0(
      "NAME_SOURCE_MALFORMED_", name_check_reason_suffix(source_id)
    ))
  )
  decoded = suppressWarnings(iconv(
    text, from = "UTF-8", to = "UTF-8", sub = NA_character_
  ))
  if (length(decoded) != 1L || is.na(decoded) || !validUTF8(decoded)) {
    name_check_fail(paste0(
      "NAME_SOURCE_MALFORMED_", name_check_reason_suffix(source_id)
    ))
  }
  decoded
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

name_check_pattern_count = function(text, pattern) {
  matches = gregexpr(pattern, text, perl = TRUE)[[1L]]
  if (identical(matches[[1L]], -1L)) 0L else length(matches)
}

name_check_malformed_reason = function(source_id) {
  paste0("NAME_SOURCE_MALFORMED_", name_check_reason_suffix(source_id))
}

name_check_incomplete_reason = function(source_id) {
  paste0("NAME_SOURCE_INCOMPLETE_", name_check_reason_suffix(source_id))
}

name_check_json_integer = function(text, key, source_id) {
  key_pattern = paste0('"', key, '"[[:space:]]*:')
  value_pattern = paste0(
    '"', key, '"[[:space:]]*:[[:space:]]*([0-9]+)'
  )
  values = name_check_regex_values(text, value_pattern, "\\1")
  if (name_check_pattern_count(text, key_pattern) != 1L ||
      length(values) != 1L) {
    name_check_fail(name_check_malformed_reason(source_id))
  }
  numeric_value = suppressWarnings(as.numeric(values[[1L]]))
  if (!is.finite(numeric_value) || numeric_value < 0 ||
      numeric_value != floor(numeric_value) ||
      numeric_value > .Machine$integer.max) {
    name_check_fail(name_check_malformed_reason(source_id))
  }
  as.integer(numeric_value)
}

name_check_json_logical = function(text, key, source_id) {
  key_pattern = paste0('"', key, '"[[:space:]]*:')
  value_pattern = paste0(
    '"', key, '"[[:space:]]*:[[:space:]]*(true|false)'
  )
  values = name_check_regex_values(text, value_pattern, "\\1")
  if (name_check_pattern_count(text, key_pattern) != 1L ||
      length(values) != 1L) {
    name_check_fail(name_check_malformed_reason(source_id))
  }
  identical(values[[1L]], "true")
}

name_check_parse_packages = function(text, source_id) {
  if (!grepl("(^|\n)Package:[[:space:]]*", text, perl = TRUE)) {
    name_check_fail(name_check_malformed_reason(source_id))
  }
  lines = strsplit(text, "\n", fixed = TRUE)[[1L]]
  package_lines = grep("^Package:[[:space:]]*", lines, value = TRUE)
  values = sub("^Package:[[:space:]]*", "", package_lines)
  values = trimws(values)
  if (!length(values) || !name_check_ascii_valid(values) ||
      any(!grepl("^[A-Za-z][A-Za-z0-9.]*$", values))) {
    name_check_fail(name_check_malformed_reason(source_id))
  }
  values
}

name_check_parse_archive = function(text, source_id) {
  html_like = grepl("<html|<!DOCTYPE", text, ignore.case = TRUE) &&
    grepl("href=", text, ignore.case = TRUE)
  if (!html_like) {
    name_check_fail(name_check_malformed_reason(source_id))
  }
  values = name_check_regex_values(
    text,
    "href=[\"']([A-Za-z][A-Za-z0-9.]*)/[\"']",
    "\\1"
  )
  if (!length(values) || !name_check_ascii_valid(values)) {
    name_check_fail(name_check_malformed_reason(source_id))
  }
  values
}

name_check_parse_runiverse_candidates = function(text, source_id) {
  if (name_check_pattern_count(
    text, '"results"[[:space:]]*:[[:space:]]*\\['
  ) != 1L) {
    name_check_fail(name_check_malformed_reason(source_id))
  }
  key_count = name_check_pattern_count(
    text, '"Package"[[:space:]]*:'
  )
  values = name_check_regex_values(
    text,
    '"Package"[[:space:]]*:[[:space:]]*"([A-Za-z][A-Za-z0-9.]*)"',
    "\\1"
  )
  if (key_count != length(values) ||
      (length(values) && !name_check_ascii_valid(values))) {
    name_check_fail(name_check_malformed_reason(source_id))
  }
  values
}

name_check_parse_github_candidates = function(text, source_id) {
  if (name_check_pattern_count(
    text, '"items"[[:space:]]*:[[:space:]]*\\['
  ) != 1L) {
    name_check_fail(name_check_malformed_reason(source_id))
  }
  key_count = name_check_pattern_count(
    text, '"full_name"[[:space:]]*:'
  )
  values = name_check_regex_values(
    text,
    '"full_name"[[:space:]]*:[[:space:]]*"[^"/]+/([A-Za-z0-9._-]+)"',
    "\\1"
  )
  if (key_count != length(values) ||
      (length(values) && !name_check_ascii_valid(values))) {
    name_check_fail(name_check_malformed_reason(source_id))
  }
  values
}

name_check_parse_count = function(source_id, value) {
  if (!source_id %in% c("github", "r-universe")) {
    name_check_fail("NAME_SOURCE_COUNT_UNSUPPORTED")
  }
  text = name_check_raw_text(value, source_id)
  if (identical(source_id, "github")) {
    candidates = name_check_parse_github_candidates(text, source_id)
    return(list(
      total = name_check_json_integer(text, "total_count", source_id),
      returned = as.integer(length(candidates)),
      incomplete = name_check_json_logical(
        text, "incomplete_results", source_id
      ),
      skip = NA_integer_,
      limit = NA_integer_,
      candidates = candidates
    ))
  }
  candidates = name_check_parse_runiverse_candidates(text, source_id)
  limit = name_check_json_integer(text, "limit", source_id)
  if (limit < 1L) name_check_fail(name_check_malformed_reason(source_id))
  total_key_count = name_check_pattern_count(
    text, '"total"[[:space:]]*:'
  )
  if (total_key_count == 1L) {
    total = name_check_json_integer(text, "total", source_id)
  } else {
    exact_empty = total_key_count == 0L && !length(candidates) &&
      name_check_pattern_count(
        text,
        '"_nocasepkg"[[:space:]]*:[[:space:]]*"[A-Za-z][A-Za-z0-9.]*"'
      ) == 1L
    if (!exact_empty) name_check_fail(name_check_malformed_reason(source_id))
    total = 0L
  }
  list(
    total = total,
    returned = as.integer(length(candidates)),
    incomplete = FALSE,
    skip = name_check_json_integer(text, "skip", source_id),
    limit = limit,
    candidates = candidates
  )
}

name_check_validate_page_set = function(source_id, pages,
                                         maximum_results = NULL) {
  if (!source_id %in% c("github", "r-universe")) {
    name_check_fail("NAME_SOURCE_COUNT_UNSUPPORTED")
  }
  incomplete_reason = name_check_incomplete_reason(source_id)
  if (!is.list(pages) || !length(pages)) {
    name_check_fail(incomplete_reason)
  }
  page_ids = vapply(pages, function(page) {
    if (is.list(page) && length(page$page) == 1L) {
      suppressWarnings(as.integer(page$page))
    } else {
      NA_integer_
    }
  }, integer(1))
  if (anyNA(page_ids) ||
      !identical(page_ids, as.integer(seq_along(pages)))) {
    name_check_fail(incomplete_reason)
  }
  queries = vapply(pages, function(page) {
    if (is.character(page$query) && length(page$query) == 1L &&
        !is.na(page$query)) page$query else ""
  }, character(1))
  if (any(!nzchar(queries)) || anyDuplicated(queries)) {
    name_check_fail(incomplete_reason)
  }
  if (identical(source_id, "github") && length(pages) > 1L) {
    tied = vapply(seq_along(pages), function(index) {
      grepl(
        paste0("([?&])page=", index, "(&|$)"),
        queries[[index]], perl = TRUE
      )
    }, logical(1))
    if (any(!tied)) name_check_fail(incomplete_reason)
  }
  available = vapply(pages, function(page) isTRUE(page$available), logical(1))
  if (any(!available)) {
    name_check_fail(paste0(
      "NAME_SOURCE_UNAVAILABLE_", name_check_reason_suffix(source_id)
    ))
  }
  roles = vapply(pages, function(page) {
    value = page$role
    if (is.null(value)) "results" else as.character(value)[[1L]]
  }, character(1))
  if (any(!roles %in% c("results", "count")) ||
      (identical(source_id, "github") && any(roles != "results")) ||
      sum(roles == "count") > 1L ||
      (any(roles == "count") && which(roles == "count") != 1L)) {
    name_check_fail(incomplete_reason)
  }
  metadata = lapply(pages, function(page) {
    name_check_parse_count(source_id, page$raw)
  })
  totals = vapply(metadata, `[[`, integer(1), "total")
  if (length(unique(totals)) != 1L) name_check_fail(incomplete_reason)
  total = totals[[1L]]
  if (is.null(maximum_results)) {
    maximum_results = if (identical(source_id, "github")) 1000L else 100000L
  }
  maximum_results = suppressWarnings(as.integer(maximum_results)[[1L]])
  if (is.na(maximum_results) || maximum_results < 0L ||
      total > maximum_results) {
    name_check_fail(incomplete_reason)
  }
  if (identical(source_id, "github") &&
      any(vapply(metadata, `[[`, logical(1), "incomplete"))) {
    name_check_fail(incomplete_reason)
  }
  result_indexes = which(roles == "results")
  if (!length(result_indexes)) name_check_fail(incomplete_reason)
  if (identical(source_id, "r-universe")) {
    skips = vapply(metadata[result_indexes], `[[`, integer(1), "skip")
    returned = vapply(
      metadata[result_indexes], `[[`, integer(1), "returned"
    )
    if (skips[[1L]] != 0L ||
        (length(skips) > 1L &&
         any(skips[-1L] != head(skips, -1L) + head(returned, -1L)))) {
      name_check_fail(incomplete_reason)
    }
  }
  candidates = unlist(
    lapply(metadata[result_indexes], `[[`, "candidates"),
    use.names = FALSE
  )
  if (length(candidates) != total ||
      (total > 0L && !length(candidates))) {
    name_check_fail(incomplete_reason)
  }
  raw_md5 = vapply(pages, function(page) {
    name_check_raw_hash(page$raw, source_id)
  }, character(1))
  details = data.frame(
    page = page_ids,
    query = queries,
    role = roles,
    declared_count = totals,
    returned_count = vapply(metadata, `[[`, integer(1), "returned"),
    completeness = ifelse(roles == "count", "count-probe", "complete"),
    raw_md5 = raw_md5,
    stringsAsFactors = FALSE
  )
  list(
    candidates = candidates,
    details = details,
    declared_count = total,
    complete = TRUE
  )
}

name_check_query_set = function(query, key, value) {
  pattern = paste0("([?&])", key, "=[^&]*")
  replacement = paste0("\\1", key, "=", as.character(value))
  if (grepl(pattern, query, perl = TRUE)) {
    return(sub(pattern, replacement, query, perl = TRUE))
  }
  paste0(query, if (grepl("?", query, fixed = TRUE)) "&" else "?",
         key, "=", as.character(value))
}

name_check_collect_pages = function(source_id, query,
                                     timeout_seconds = 30L,
                                     page_size = 100L,
                                     download = NULL) {
  if (!source_id %in% c("github", "r-universe") ||
      !is.character(query) || length(query) != 1L || !nzchar(query)) {
    name_check_fail(name_check_malformed_reason(source_id))
  }
  page_size = suppressWarnings(as.integer(page_size)[[1L]])
  if (is.na(page_size) || page_size < 1L ||
      (identical(source_id, "github") && page_size > 100L)) {
    name_check_fail(name_check_malformed_reason(source_id))
  }
  if (is.null(download)) download = name_check_download
  fetch = function(url) download(url, source_id, timeout_seconds)
  if (identical(source_id, "github")) {
    base_query = name_check_query_set(query, "per_page", page_size)
    first_query = name_check_query_set(base_query, "page", 1L)
    pages = list(list(
      page = 1L, query = first_query, available = TRUE,
      raw = fetch(first_query), role = "results"
    ))
    first = name_check_parse_count(source_id, pages[[1L]]$raw)
    if (first$total > 1000L) {
      name_check_fail(name_check_incomplete_reason(source_id))
    }
    page_count = max(1L, as.integer(ceiling(first$total / page_size)))
    if (page_count > 1L) {
      for (page in 2:page_count) {
        page_query = name_check_query_set(base_query, "page", page)
        pages[[page]] = list(
          page = as.integer(page), query = page_query, available = TRUE,
          raw = fetch(page_query), role = "results"
        )
      }
    }
  } else {
    first_query = name_check_query_set(query, "limit", page_size)
    first_query = name_check_query_set(first_query, "skip", 0L)
    first_page = list(
      page = 1L, query = first_query, available = TRUE,
      raw = fetch(first_query), role = "results"
    )
    first = name_check_parse_count(source_id, first_page$raw)
    if (first$total > 100000L) {
      name_check_fail(name_check_incomplete_reason(source_id))
    }
    pages = list(first_page)
    if (first$returned != first$total) {
      pages[[1L]]$role = "count"
      complete_query = name_check_query_set(
        first_query, "limit", max(1L, first$total)
      )
      pages[[2L]] = list(
        page = 2L, query = complete_query, available = TRUE,
        raw = fetch(complete_query), role = "results"
      )
    }
  }
  validated = name_check_validate_page_set(source_id, pages)
  validated$pages = pages
  validated
}

name_check_parse_runiverse = function(text, source_id) {
  name_check_parse_runiverse_candidates(text, source_id)
}

name_check_parse_github = function(text, source_id) {
  name_check_parse_github_candidates(text, source_id)
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
  detail_sets = vector("list", length(required))
  names(detail_sets) = required
  collisions = character()
  for (index in seq_along(required)) {
    source_id = required[[index]]
    source = sources[[index]]
    bounded = source_id %in% c("github", "r-universe")
    composite_bioc = source_id %in% c(
      "bioconductor-current", "bioconductor-history"
    ) && !is.null(source$details)
    if (bounded) {
      pages = source$pages
      if (is.null(pages)) {
        pages = list(list(
          page = 1L, query = source$query, available = source$available,
          raw = source$raw, role = "results"
        ))
      }
      validated = name_check_validate_page_set(source_id, pages)
      candidates = validated$candidates
      details = validated$details
      candidate_sets = lapply(pages, function(page) {
        name_check_parse_count(source_id, page$raw)$candidates
      })
    } else if (composite_bioc) {
      validated = name_check_validate_source_details(source_id, source)
      candidates = validated$candidates
      details = validated$details
      candidate_sets = validated$candidate_sets
    } else {
      if (!isTRUE(source$available)) {
        name_check_fail(paste0(
          "NAME_SOURCE_UNAVAILABLE_", name_check_reason_suffix(source_id)
        ))
      }
      if (!is.character(source$query) || length(source$query) != 1L ||
          !nzchar(source$query)) {
        name_check_fail(name_check_malformed_reason(source_id))
      }
      candidates = name_check_parse_source(source_id, source$raw)
      details = data.frame(
        detail_id = paste0(source_id, "-1"),
        release = "",
        repository = "",
        page = 1L,
        query = source$query,
        role = "results",
        declared_count = as.integer(length(candidates)),
        returned_count = as.integer(length(candidates)),
        completeness = "complete",
        raw_md5 = name_check_raw_hash(source$raw, source_id),
        stringsAsFactors = FALSE
      )
      candidate_sets = list(candidates)
    }
    if (!"detail_id" %in% names(details)) {
      details$detail_id = paste0(source_id, "-page-", details$page)
    }
    if (!"release" %in% names(details)) details$release = ""
    if (!"repository" %in% names(details)) details$repository = ""
    details = details[, c(
      "detail_id", "release", "repository", "page", "query", "role",
      "declared_count", "returned_count", "completeness", "raw_md5"
    )]
    if (length(candidate_sets) != nrow(details)) {
      name_check_fail(name_check_incomplete_reason(source_id))
    }
    detail_matches = vapply(candidate_sets, function(values) {
      exact = unique(name_check_exact_matches(name, values))
      if (length(exact)) paste(exact, collapse = ",") else "NONE"
    }, character(1))
    details$available = "yes"
    details$exact_matches = detail_matches
    details$result = ifelse(detail_matches == "NONE", "pass", "collision")
    query = paste(details$query, collapse = " + ")
    raw_md5 = name_check_parent_hash(details)
    detail_sets[[source_id]] = details
    exact = unique(name_check_exact_matches(name, candidates))
    if (length(exact)) {
      collisions = c(collisions, paste0(source_id, ":", exact))
    }
    rows[[index]] = data.frame(
      source_id = source_id,
      source = unname(labels[[source_id]]),
      query = query,
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
    source_details = detail_sets,
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
  details = do.call(rbind, lapply(names(result$source_details), function(id) {
    value = result$source_details[[id]]
    value$source_id = id
    value[, c(
      "source_id", "detail_id", "release", "repository", "page", "query",
      "role", "available", "declared_count", "returned_count",
      "completeness", "raw_md5", "exact_matches", "result"
    )]
  }))
  rownames(details) = NULL
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
  detail_rows = vapply(seq_len(nrow(details)), function(index) {
    paste0(
      "Source-Detail: ", details$source_id[[index]],
      "|detail-id=", details$detail_id[[index]],
      "|release=", details$release[[index]],
      "|repository=", details$repository[[index]],
      "|page=", details$page[[index]],
      "|role=", details$role[[index]],
      "|available=", details$available[[index]],
      "|declared-count=", details$declared_count[[index]],
      "|returned-count=", details$returned_count[[index]],
      "|completeness=", details$completeness[[index]],
      "|raw-md5=", details$raw_md5[[index]],
      "|matches=", details$exact_matches[[index]],
      "|result=", details$result[[index]],
      "|query=", details$query[[index]]
    )
  }, character(1))
  lines = c(
    "# GEModelR Name Availability Evidence",
    "",
    "## Configuration",
    "",
    "Name-Evidence-Version: 1",
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
    "## Machine-readable source details",
    "",
    detail_rows,
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

name_check_parse_machine_rows = function(lines, prefix, fields) {
  hits = grep(paste0("^", prefix, ": "), lines, value = TRUE)
  if (!length(hits)) name_check_fail("NAME_REPORT_SOURCE_DETAILS_INVALID")
  records = lapply(hits, function(line) {
    body = sub(paste0("^", prefix, ": "), "", line)
    parts = strsplit(body, "|", fixed = TRUE)[[1L]]
    record = stats::setNames(as.list(rep("", length(fields))), fields)
    record[[fields[[1L]]]] = parts[[1L]]
    for (part in parts[-1L]) {
      position = regexpr("=", part, fixed = TRUE)[[1L]]
      if (position < 2L) name_check_fail("NAME_REPORT_SOURCE_DETAILS_INVALID")
      key = substr(part, 1L, position - 1L)
      value = substr(part, position + 1L, nchar(part))
      if (!key %in% fields[-1L] || nzchar(record[[key]])) {
        name_check_fail("NAME_REPORT_SOURCE_DETAILS_INVALID")
      }
      record[[key]] = value
    }
    if (any(vapply(record[-c(3L, 4L)], function(value) {
      !is.character(value) || length(value) != 1L || !nzchar(value)
    }, logical(1)))) {
      name_check_fail("NAME_REPORT_SOURCE_DETAILS_INVALID")
    }
    record
  })
  as.data.frame(do.call(rbind, lapply(records, unlist)),
                stringsAsFactors = FALSE)
}

name_check_verify_report = function(path, require_review = TRUE) {
  if (!file.exists(path)) name_check_fail("NAME_REPORT_MISSING")
  lines = tryCatch(
    readLines(path, warn = FALSE, encoding = "UTF-8"),
    error = function(error) name_check_fail("NAME_REPORT_MALFORMED")
  )
  fields = c(
    "Name-Evidence-Version", "Name", "Check-Kind", "Checked-At-UTC",
    "Overall-Result", "Reviewer", "Review-Date-UTC"
  )
  values = lapply(fields, function(field) name_check_marker(lines, field))
  names(values) = fields
  if (any(vapply(values, length, integer(1)) != 1L)) {
    name_check_fail("NAME_REPORT_MALFORMED")
  }
  values = vapply(values, `[[`, character(1), 1L)
  if (!identical(values[["Name-Evidence-Version"]], "1")) {
    name_check_fail("NAME_REPORT_VERSION_UNSUPPORTED")
  }
  name_check_validate_name(values[["Name"]])
  name_check_validate_kind(values[["Check-Kind"]])
  if (!identical(
    values[["Overall-Result"]], "NAME_AVAILABLE_NO_EXACT_COLLISION"
  )) {
    name_check_fail("NAME_REPORT_NOT_CLEAR")
  }
  if (!grepl(
    "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$",
    values[["Checked-At-UTC"]]
  )) {
    name_check_fail("NAME_REPORT_MALFORMED")
  }
  source_rows = name_check_parse_machine_rows(
    lines, "Source-Row",
    c("source_id", "available", "raw-md5", "matches", "result", "query")
  )
  if (!identical(source_rows$source_id, name_check_source_ids()) ||
      any(source_rows$available != "yes") ||
      any(!grepl("^[0-9a-f]{32}$", source_rows[["raw-md5"]])) ||
      any(source_rows$matches != "NONE") ||
      any(source_rows$result != "pass") ||
      any(!grepl("^https://", source_rows$query))) {
    name_check_fail("NAME_REPORT_SOURCE_ROWS_INVALID")
  }
  detail_rows = name_check_parse_machine_rows(
    lines, "Source-Detail",
    c(
      "source_id", "detail-id", "release", "repository", "page", "role",
      "available", "declared-count", "returned-count", "completeness",
      "raw-md5", "matches", "result", "query"
    )
  )
  if (nrow(detail_rows) < length(name_check_source_ids()) ||
      !identical(unique(detail_rows$source_id), name_check_source_ids()) ||
      anyDuplicated(detail_rows[["detail-id"]]) ||
      any(detail_rows$available != "yes") ||
      any(!grepl("^[0-9a-f]{32}$", detail_rows[["raw-md5"]])) ||
      any(detail_rows$matches != "NONE") ||
      any(detail_rows$result != "pass") ||
      any(!grepl("^https://", detail_rows$query)) ||
      any(!detail_rows$completeness %in% c(
        "manifest", "complete", "count-probe"
      ))) {
    name_check_fail("NAME_REPORT_SOURCE_DETAILS_INVALID")
  }
  integer_fields = c("page", "declared-count", "returned-count")
  for (field in integer_fields) {
    parsed = suppressWarnings(as.integer(detail_rows[[field]]))
    if (anyNA(parsed) || any(parsed < 0L) ||
        any(as.character(parsed) != detail_rows[[field]])) {
      name_check_fail("NAME_REPORT_SOURCE_DETAILS_INVALID")
    }
    detail_rows[[field]] = parsed
  }
  for (source_id in name_check_source_ids()) {
    subset = detail_rows[detail_rows$source_id == source_id, , drop = FALSE]
    normalized = data.frame(
      detail_id = subset[["detail-id"]],
      release = subset$release,
      repository = subset$repository,
      page = subset$page,
      query = subset$query,
      role = subset$role,
      declared_count = subset[["declared-count"]],
      returned_count = subset[["returned-count"]],
      completeness = subset$completeness,
      raw_md5 = subset[["raw-md5"]],
      available = subset$available,
      exact_matches = subset$matches,
      result = subset$result,
      stringsAsFactors = FALSE
    )
    parent = source_rows[source_rows$source_id == source_id, , drop = FALSE]
    if (nrow(parent) != 1L ||
        !identical(parent$query, paste(normalized$query, collapse = " + ")) ||
        !identical(parent[["raw-md5"]], name_check_parent_hash(normalized)) ||
        !identical(parent$matches, "NONE") ||
        !identical(parent$result, "pass")) {
      name_check_fail("NAME_REPORT_SOURCE_ROWS_INVALID")
    }
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

name_check_version_at_least = function(version, minimum) {
  utils::compareVersion(as.character(version), as.character(minimum)) >= 0L
}

name_check_bioc_repositories = function(
    version, release_manifest, repository_manifest, source_id
) {
  if (!source_id %in% c(
    "bioconductor-current", "bioconductor-history"
  ) || !is.character(version) || length(version) != 1L ||
      !grepl("^[0-9]+[.][0-9]+$", version)) {
    name_check_fail(name_check_malformed_reason(source_id))
  }
  release_text = name_check_raw_text(release_manifest, source_id)
  repository_text = name_check_raw_text(repository_manifest, source_id)
  version_pattern = gsub(".", "[.]", version, fixed = TRUE)
  repositories = name_check_regex_values(
    release_text,
    paste0(
      '/packages/json/', version_pattern,
      '/([^"]+)/packages[.]js'
    ),
    "\\1"
  )
  if (!length(repositories)) {
    if (!grepl("BiocView|AnnotationData[.]html|ExperimentData[.]html",
               release_text)) {
      name_check_fail(name_check_malformed_reason(source_id))
    }
    repositories = "bioc"
    if (grepl("AnnotationData[.]html", release_text)) {
      repositories = c(repositories, "data/annotation")
    }
    if (grepl("ExperimentData[.]html", release_text)) {
      repositories = c(repositories, "data/experiment")
    }
  }
  required_manifest_entries = c(
    'BioCsoft = "bioc"', 'BioCann = "data/annotation"',
    'BioCexp = "data/experiment"', 'BioCworkflows = "workflows"'
  )
  if (any(!vapply(
    required_manifest_entries, grepl, logical(1),
    x = repository_text, fixed = TRUE
  ))) {
    name_check_fail(name_check_malformed_reason(source_id))
  }
  books_threshold = name_check_regex_values(
    repository_text,
    'BioCbooks[[:space:]]*=[[:space:]]*if[[:space:]]*[(]version[(][)][[:space:]]*>=[[:space:]]*"([0-9]+[.][0-9]+)"[)][[:space:]]*"books"',
    "\\1"
  )
  if (length(books_threshold) != 1L) {
    name_check_fail(name_check_malformed_reason(source_id))
  }
  if (name_check_version_at_least(version, books_threshold[[1L]])) {
    repositories = c(repositories, "books")
  }
  repositories = unique(repositories)
  valid = grepl(
    "^[A-Za-z0-9.]+(/[A-Za-z0-9.]+)*$", repositories
  )
  if (!length(repositories) || any(!valid)) {
    name_check_fail(name_check_malformed_reason(source_id))
  }
  preferred = c(
    "bioc", "data/annotation", "data/experiment", "workflows", "books"
  )
  repositories = c(
    preferred[preferred %in% repositories],
    sort(setdiff(repositories, preferred))
  )
  data.frame(
    repository = repositories,
    path = paste0(
      "https://bioconductor.org/packages/", version, "/",
      repositories, "/src/contrib/PACKAGES"
    ),
    stringsAsFactors = FALSE
  )
}

name_check_bioc_detail_value = function(detail, field, source_id) {
  value = detail[[field]]
  if (!is.character(value) || length(value) != 1L || is.na(value) ||
      !nzchar(value)) {
    name_check_fail(name_check_malformed_reason(source_id))
  }
  value
}

name_check_validate_source_details = function(source_id, source) {
  if (!source_id %in% c(
    "bioconductor-current", "bioconductor-history"
  ) || !is.list(source)) {
    name_check_fail(name_check_malformed_reason(source_id))
  }
  incomplete_reason = name_check_incomplete_reason(source_id)
  repository_manifest = source$repository_manifest
  release_manifests = source$release_manifests
  package_details = source$details
  if (!is.list(repository_manifest) || !isTRUE(repository_manifest$available) ||
      !is.list(release_manifests) || !length(release_manifests) ||
      !is.list(package_details)) {
    name_check_fail(incomplete_reason)
  }
  repository_query = name_check_bioc_detail_value(
    repository_manifest, "query", source_id
  )
  if (!grepl("^https://", repository_query)) {
    name_check_fail(name_check_malformed_reason(source_id))
  }
  repository_hash = name_check_raw_hash(repository_manifest$raw, source_id)
  repository_raw = repository_manifest$raw
  versions = vapply(release_manifests, function(manifest) {
    name_check_bioc_detail_value(manifest, "release", source_id)
  }, character(1))
  if (anyDuplicated(versions) ||
      (identical(source_id, "bioconductor-current") &&
       length(versions) != 1L)) {
    name_check_fail(incomplete_reason)
  }
  expected_sets = vector("list", length(release_manifests))
  release_hashes = character(length(release_manifests))
  release_queries = character(length(release_manifests))
  release_raws = vector("list", length(release_manifests))
  for (index in seq_along(release_manifests)) {
    manifest = release_manifests[[index]]
    if (!isTRUE(manifest$available)) {
      name_check_fail(paste0(
        "NAME_SOURCE_UNAVAILABLE_", name_check_reason_suffix(source_id)
      ))
    }
    release = versions[[index]]
    query = name_check_bioc_detail_value(manifest, "query", source_id)
    expected_query = paste0(
      "https://bioconductor.org/packages/", release, "/BiocViews.html"
    )
    if (!identical(query, expected_query)) {
      name_check_fail(name_check_malformed_reason(source_id))
    }
    release_queries[[index]] = query
    release_hashes[[index]] = name_check_raw_hash(manifest$raw, source_id)
    release_raws[[index]] = manifest$raw
    expected_sets[[index]] = name_check_bioc_repositories(
      release, manifest$raw, repository_raw, source_id
    )
    expected_sets[[index]]$release = release
  }
  expected = do.call(rbind, expected_sets)
  expected$key = paste(expected$release, expected$repository, sep = "/")
  actual_release = vapply(package_details, function(detail) {
    name_check_bioc_detail_value(detail, "release", source_id)
  }, character(1))
  actual_repository = vapply(package_details, function(detail) {
    name_check_bioc_detail_value(detail, "repository", source_id)
  }, character(1))
  actual_keys = paste(actual_release, actual_repository, sep = "/")
  if (anyDuplicated(actual_keys) ||
      !identical(actual_keys, expected$key)) {
    name_check_fail(incomplete_reason)
  }
  package_hashes = character(length(package_details))
  package_queries = character(length(package_details))
  package_counts = integer(length(package_details))
  package_candidates = vector("list", length(package_details))
  package_raws = vector("list", length(package_details))
  for (index in seq_along(package_details)) {
    detail = package_details[[index]]
    if (!isTRUE(detail$available)) {
      name_check_fail(paste0(
        "NAME_SOURCE_UNAVAILABLE_", name_check_reason_suffix(source_id)
      ))
    }
    query = name_check_bioc_detail_value(detail, "query", source_id)
    if (!identical(query, expected$path[[index]])) {
      name_check_fail(name_check_malformed_reason(source_id))
    }
    package_queries[[index]] = query
    package_hashes[[index]] = name_check_raw_hash(detail$raw, source_id)
    package_raws[[index]] = detail$raw
    text = name_check_raw_text(detail$raw, source_id)
    values = name_check_parse_packages(text, source_id)
    package_candidates[[index]] = values
    package_counts[[index]] = length(values)
  }
  manifest_details = data.frame(
    detail_id = c(
      paste0(source_id, "-repository-manifest"),
      paste0(source_id, "-", versions, "-release-manifest")
    ),
    release = c("", versions),
    repository = "manifest",
    page = 0L,
    query = c(repository_query, release_queries),
    role = c("repository-manifest", rep("release-manifest", length(versions))),
    declared_count = 0L,
    returned_count = 0L,
    completeness = "manifest",
    raw_md5 = c(repository_hash, release_hashes),
    stringsAsFactors = FALSE
  )
  package_frame = data.frame(
    detail_id = paste0(
      source_id, "-", expected$release, "-",
      gsub("/", "-", expected$repository, fixed = TRUE)
    ),
    release = expected$release,
    repository = expected$repository,
    page = 0L,
    query = package_queries,
    role = "packages",
    declared_count = package_counts,
    returned_count = package_counts,
    completeness = "complete",
    raw_md5 = package_hashes,
    stringsAsFactors = FALSE
  )
  candidate_sets = c(
    rep(list(character()), nrow(manifest_details)), package_candidates
  )
  list(
    candidates = unlist(package_candidates, use.names = FALSE),
    details = rbind(manifest_details, package_frame),
    candidate_sets = candidate_sets,
    raw = do.call(c, c(list(repository_raw), release_raws, package_raws)),
    complete = TRUE
  )
}

name_check_parent_hash = function(details) {
  fields = c(
    "detail_id", "release", "repository", "page", "query", "role",
    "declared_count", "returned_count", "completeness", "raw_md5",
    "available", "exact_matches", "result"
  )
  if (!all(fields %in% names(details)) || !nrow(details)) {
    name_check_fail("NAME_REPORT_SOURCE_DETAILS_INVALID")
  }
  rows = apply(details[, fields, drop = FALSE], 1L, function(row) {
    paste(row, collapse = "|")
  })
  name_check_raw_hash(
    charToRaw(paste(rows, collapse = "\n")), "report-source-details"
  )
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

name_check_collect_bioc = function(
    source_id, versions, repository_manifest, timeout_seconds = 30L
) {
  repository_url = paste0(
    "https://raw.githubusercontent.com/Bioconductor/",
    "BiocManager/devel/R/repositories.R"
  )
  release_manifests = vector("list", length(versions))
  details = list()
  for (index in seq_along(versions)) {
    version = versions[[index]]
    manifest_url = paste0(
      "https://bioconductor.org/packages/", version, "/BiocViews.html"
    )
    manifest_raw = name_check_download(
      manifest_url, source_id, timeout_seconds
    )
    release_manifests[[index]] = list(
      release = version,
      query = manifest_url,
      available = TRUE,
      raw = manifest_raw
    )
    repositories = name_check_bioc_repositories(
      version, manifest_raw, repository_manifest, source_id
    )
    for (row in seq_len(nrow(repositories))) {
      details[[length(details) + 1L]] = list(
        release = version,
        repository = repositories$repository[[row]],
        query = repositories$path[[row]],
        available = TRUE,
        raw = name_check_download(
          repositories$path[[row]], source_id, timeout_seconds
        )
      )
    }
  }
  list(
    id = source_id,
    repository_manifest = list(
      query = repository_url,
      available = TRUE,
      raw = repository_manifest
    ),
    release_manifests = release_manifests,
    details = details
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
  release_index_url = "https://bioconductor.org/about/release-announcements/"
  release_index = name_check_download(
    release_index_url, "bioconductor-history", timeout_seconds
  )
  versions = name_check_bioc_versions(release_index)
  indexed = versions[as.numeric(versions) >= 1.8]
  if (length(indexed) < 2L) {
    name_check_fail("NAME_SOURCE_MALFORMED_BIOCONDUCTOR_HISTORY")
  }
  repository_url = paste0(
    "https://raw.githubusercontent.com/Bioconductor/",
    "BiocManager/devel/R/repositories.R"
  )
  repository_manifest = name_check_download(
    repository_url, "bioconductor-current", timeout_seconds
  )
  current = name_check_collect_bioc(
    "bioconductor-current", indexed[[1L]], repository_manifest,
    timeout_seconds
  )
  history = name_check_collect_bioc(
    "bioconductor-history", indexed[-1L], repository_manifest,
    timeout_seconds
  )
  collected = c(collected, list(current, history))
  runiverse_query = paste0(
    "https://r-universe.dev/api/search?q=package%3A", encoded,
    "&limit=100"
  )
  runiverse = name_check_collect_pages(
    "r-universe", runiverse_query, timeout_seconds = timeout_seconds
  )
  github_query = paste0(
    "https://api.github.com/search/repositories?q=", encoded,
    "%20in%3Aname&per_page=100"
  )
  github = name_check_collect_pages(
    "github", github_query, timeout_seconds = timeout_seconds
  )
  c(collected, list(
    list(id = "r-universe", pages = runiverse$pages),
    list(id = "github", pages = github$pages)
  ))
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
      '{"results":[{"Package":"', package, '"}],',
      '"skip":0,"limit":100,"total":1}'
    )),
    github = charToRaw(paste0(
      '{"total_count":1,"incomplete_results":false,',
      '"items":[{"full_name":"owner/', package, '"}]}'
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
      "GEModelR", c("gemodelr", "GEModelRtools")
    ),
    "gemodelr"
  ))
  name_check_expect_failure(
    name_check_exact_matches("GEModelR", "GЕModelR"),
    "NAME_CANDIDATES_INVALID"
  )
  clean = name_check_evaluate_fixture(
    "GEModelR", name_check_test_fixture(), checked_at = "2026-08-25T00:00:00Z"
  )
  stopifnot(
    identical(clean$overall_result, "NAME_AVAILABLE_NO_EXACT_COLLISION"),
    identical(clean$sources$source_id, name_check_source_ids())
  )
  collision = name_check_test_fixture()
  collision[[6L]]$raw = charToRaw(paste0(
    '{"total_count":1,"incomplete_results":false,',
    '"items":[{"full_name":"owner/gemodelr"}]}'
  ))
  name_check_expect_failure(
    name_check_evaluate_fixture("GEModelR", collision),
    "NAME_EXACT_COLLISION"
  )
  incomplete = name_check_test_fixture()
  incomplete[[6L]]$raw = charToRaw(paste0(
    '{"total_count":2,"incomplete_results":false,',
    '"items":[{"full_name":"owner/AnotherPackage"}]}'
  ))
  name_check_expect_failure(
    name_check_evaluate_fixture("GEModelR", incomplete),
    "NAME_SOURCE_INCOMPLETE_GITHUB"
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
