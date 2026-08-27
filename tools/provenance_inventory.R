#!/usr/bin/env Rscript

provenance_columns <- c(
  "path", "symbol", "language", "classification",
  "upstream_repository", "upstream_commit", "upstream_path",
  "first_local_commit", "expression_hash", "contributors",
  "copyright_holder", "license_basis", "evidence", "reviewer",
  "review_date", "status", "notes"
)

provenance_abort <- function(code, detail = NULL) {
  message <- if (is.null(detail) || !nzchar(detail)) {
    code
  } else {
    paste(code, detail)
  }
  stop(message, call. = FALSE)
}

provenance_hash_text <- function(text) {
  path <- tempfile("tabloToR-provenance-hash-")
  on.exit(unlink(path), add = TRUE)
  writeLines(enc2utf8(text), path, useBytes = TRUE)
  unname(tools::md5sum(path)[[1L]])
}

provenance_relative_path <- function(path, root) {
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  substring(path, nchar(root) + 2L)
}

provenance_source_files <- function(root) {
  collect <- function(directory, pattern) {
    path <- file.path(root, directory)
    if (!dir.exists(path)) return(character())
    list.files(
      path, pattern = pattern, recursive = TRUE, full.names = TRUE,
      all.files = FALSE, no.. = TRUE, ignore.case = TRUE
    )
  }
  files <- c(
    collect("R", "\\.R$"),
    collect("src", "\\.(c|cc|cpp|cxx|h|hpp)$"),
    collect(file.path("inst", "cpp"), "\\.(c|cc|cpp|cxx|h|hpp)$")
  )
  if (!length(files)) return(character())
  files <- files[!file.info(files)[["isdir"]]]
  sort(unique(normalizePath(files, winslash = "/", mustWork = TRUE)))
}

provenance_srcref_lines <- function(value, fallback_start = 1L,
                                    fallback_end = fallback_start) {
  reference <- if (inherits(value, "srcref")) value else
    attr(value, "srcref", exact = TRUE)
  if (is.null(reference) || length(reference) < 3L) {
    return(c(as.integer(fallback_start), as.integer(fallback_end)))
  }
  c(as.integer(reference[[1L]]), as.integer(reference[[3L]]))
}

provenance_call_name <- function(value) {
  if (is.symbol(value)) return(as.character(value))
  if (is.call(value) && length(value) == 3L &&
      as.character(value[[1L]]) %in% c("::", ":::")) {
    return(paste(as.character(value[[2L]]), as.character(value[[3L]]),
                 sep = "::"))
  }
  ""
}


provenance_normalize_r <- function(value) {
  if (is.call(value)) {
    normalized <- as.list(value)
    normalized <- lapply(normalized, provenance_normalize_r)
    if (is.symbol(normalized[[1L]]) &&
        identical(as.character(normalized[[1L]]), "=")) {
      normalized[[1L]] <- as.name("<-")
    }
    return(as.call(normalized))
  }
  if (is.pairlist(value)) {
    normalized <- lapply(value, provenance_normalize_r)
    return(as.pairlist(normalized))
  }
  value
}


provenance_method_lines <- function(parse_data, method_name, fallback) {
  hits <- parse_data[
    parse_data[["token"]] == "SYMBOL_SUB" &
      parse_data[["text"]] == method_name &
      parse_data[["line1"]] >= fallback[[1L]] &
      parse_data[["line2"]] <= fallback[[2L]],
    , drop = FALSE
  ]
  if (!nrow(hits)) return(fallback)
  for (id in seq_len(nrow(hits))) {
    candidates <- parse_data[
      parse_data[["parent"]] == hits[["parent"]][[id]] &
        parse_data[["token"]] == "expr" &
        parse_data[["line1"]] == hits[["line1"]][[id]] &
        parse_data[["line2"]] >= hits[["line2"]][[id]],
      , drop = FALSE
    ]
    if (nrow(candidates)) {
      candidate <- candidates[which.max(candidates[["line2"]]), , drop = FALSE]
      return(c(as.integer(candidate[["line1"]][[1L]]),
               as.integer(candidate[["line2"]][[1L]])))
    }
  }
  fallback
}

provenance_r_rows <- function(path, relative) {
  expressions <- tryCatch(
    parse(path, keep.source = TRUE),
    error = function(error) provenance_abort(
      "PROVENANCE_R_PARSE_FAILED", relative
    )
  )
  references <- attr(expressions, "srcref", exact = TRUE)
  parse_data <- utils::getParseData(expressions)
  rows <- list()
  add_row <- function(symbol, expression, range) {
    normalized <- paste(
      deparse(provenance_normalize_r(expression), width.cutoff = 500L),
      collapse = "\n"
    )
    rows[[length(rows) + 1L]] <<- data.frame(
      path = relative,
      symbol = symbol,
      language = "R",
      line_start = as.integer(range[[1L]]),
      line_end = as.integer(range[[2L]]),
      expression_hash = provenance_hash_text(normalized),
      generated_from = "",
      stringsAsFactors = FALSE
    )
  }
  for (expression_id in seq_along(expressions)) {
    expression <- expressions[[expression_id]]
    if (!is.call(expression) || length(expression) < 3L ||
        !as.character(expression[[1L]]) %in% c("<-", "=")) next
    target <- expression[[2L]]
    value <- expression[[3L]]
    if (!is.symbol(target)) next
    symbol <- as.character(target)
    range <- if (!is.null(references)) {
      provenance_srcref_lines(references[[expression_id]])
    } else {
      provenance_srcref_lines(expression)
    }
    if (is.call(value) && identical(as.character(value[[1L]]), "function")) {
      add_row(symbol, value, range)
      next
    }
    call_name <- provenance_call_name(if (is.call(value)) value[[1L]] else NULL)
    if (!call_name %in% c("setRefClass", "methods::setRefClass")) next
    arguments <- as.list(value)[-1L]
    argument_names <- names(arguments)
    method_id <- which(argument_names == "methods")
    if (!length(method_id)) next
    methods <- arguments[[method_id[[1L]]]]
    if (!is.call(methods) || !identical(as.character(methods[[1L]]), "list")) next
    method_values <- as.list(methods)[-1L]
    method_names <- names(method_values)
    for (id in seq_along(method_values)) {
      method <- method_values[[id]]
      method_name <- method_names[[id]]
      if (!nzchar(method_name) || !is.call(method) ||
          !identical(as.character(method[[1L]]), "function")) next
      method_range <- provenance_method_lines(parse_data, method_name, range)
      add_row(paste0(symbol, "$", method_name), method, method_range)
    }
  }
  if (!length(rows)) return(NULL)
  do.call(rbind, rows)
}

provenance_mask_native <- function(text) {
  characters <- strsplit(text, "", fixed = TRUE)[[1L]]
  masked <- characters
  state <- "code"
  escaped <- FALSE
  id <- 1L
  while (id <= length(characters)) {
    current <- characters[[id]]
    following <- if (id < length(characters)) characters[[id + 1L]] else ""
    if (state == "line-comment") {
      if (current == "\n") state <- "code" else masked[[id]] <- " "
    } else if (state == "block-comment") {
      if (current == "*" && following == "/") {
        masked[[id]] <- " "
        masked[[id + 1L]] <- " "
        state <- "code"
        id <- id + 1L
      } else if (current != "\n") {
        masked[[id]] <- " "
      }
    } else if (state %in% c("string", "character")) {
      if (current != "\n") masked[[id]] <- " "
      quote <- if (state == "string") "\"" else "'"
      if (!escaped && current == quote) state <- "code"
      if (current == "\\" && !escaped) escaped <- TRUE else escaped <- FALSE
    } else if (current == "/" && following == "/") {
      masked[[id]] <- " "
      masked[[id + 1L]] <- " "
      state <- "line-comment"
      id <- id + 1L
    } else if (current == "/" && following == "*") {
      masked[[id]] <- " "
      masked[[id + 1L]] <- " "
      state <- "block-comment"
      id <- id + 1L
    } else if (current == "\"") {
      masked[[id]] <- " "
      state <- "string"
      escaped <- FALSE
    } else if (current == "'") {
      masked[[id]] <- " "
      state <- "character"
      escaped <- FALSE
    }
    id <- id + 1L
  }
  masked <- paste(masked, collapse = "")
  lines <- strsplit(masked, "\n", fixed = TRUE)[[1L]]
  preprocessor <- grepl("^[[:space:]]*#", lines)
  lines[preprocessor] <- gsub("[^\r]", " ", lines[preprocessor])
  paste(lines, collapse = "\n")
}

provenance_native_needs_separator <- function(left, right) {
  if (!nzchar(left) || !nzchar(right) || left == "\n") return(FALSE)
  word <- function(value) grepl("^[A-Za-z0-9_$]$", value)
  operator <- function(value) grepl("^[!%&*+./:<=>?^|-]$", value)
  quote <- function(value) value %in% c("\"", "'")
  (word(left) && word(right)) ||
    (word(left) && quote(right)) ||
    (quote(left) && word(right)) ||
    (operator(left) && operator(right)) ||
    (left == "." && grepl("^[0-9]$", right)) ||
    (grepl("^[0-9]$", left) && right == ".")
}

provenance_normalize_native <- function(text) {
  text <- paste(as.character(text), collapse = "\n")
  text <- gsub("\r\n?", "\n", text)
  characters <- strsplit(text, "", fixed = TRUE)[[1L]]
  if (!length(characters)) return("")
  output <- character()
  state <- "code"
  escaped <- FALSE
  pending_space <- FALSE
  line_start <- TRUE
  preprocessor <- FALSE
  append_character <- function(value) {
    output[[length(output) + 1L]] <<- value
  }
  end_line <- function() {
    if (preprocessor &&
        (!length(output) || output[[length(output)]] != "\n")) {
      append_character("\n")
    } else if (!preprocessor) {
      pending_space <<- TRUE
    }
    line_start <<- TRUE
    preprocessor <<- FALSE
  }

  id <- 1L
  while (id <= length(characters)) {
    current <- characters[[id]]
    following <- if (id < length(characters)) characters[[id + 1L]] else ""
    if (state == "line-comment") {
      if (current == "\n") {
        state <- "code"
        end_line()
      }
    } else if (state == "block-comment") {
      if (current == "*" && following == "/") {
        state <- "code"
        pending_space <- TRUE
        id <- id + 1L
      } else if (current == "\n") {
        end_line()
      }
    } else if (state %in% c("string", "character")) {
      was_escaped <- escaped
      append_character(current)
      quote <- if (state == "string") "\"" else "'"
      if (!was_escaped && current == quote) state <- "code"
      escaped <- current == "\\" && !was_escaped
      line_start <- FALSE
    } else if (current == "/" && following == "/") {
      state <- "line-comment"
      pending_space <- TRUE
      id <- id + 1L
    } else if (current == "/" && following == "*") {
      state <- "block-comment"
      pending_space <- TRUE
      id <- id + 1L
    } else if (current %in% c(" ", "\t", "\f", "\v")) {
      pending_space <- TRUE
    } else if (current == "\n") {
      end_line()
    } else {
      if (line_start && current == "#") {
        if (length(output) && output[[length(output)]] != "\n") {
          append_character("\n")
        }
        preprocessor <- TRUE
      }
      if (pending_space && length(output)) {
        left <- output[[length(output)]]
        if (provenance_native_needs_separator(left, current)) {
          append_character(" ")
        }
      }
      pending_space <- FALSE
      append_character(current)
      line_start <- FALSE
      if (current == "\"") {
        state <- "string"
        escaped <- FALSE
      } else if (current == "'") {
        state <- "character"
        escaped <- FALSE
      }
    }
    id <- id + 1L
  }
  sub("\n+$", "", paste(output, collapse = ""))
}

provenance_native_signature <- function(header) {
  header <- trimws(header)
  if (!nzchar(header) || !grepl("\\)", header)) return(NULL)
  close <- max(gregexpr("\\)", header)[[1L]])
  before_close <- substr(header, 1L, close)
  depth <- 0L
  open <- NA_integer_
  characters <- strsplit(before_close, "", fixed = TRUE)[[1L]]
  for (id in seq.int(length(characters), 1L)) {
    if (characters[[id]] == ")") depth <- depth + 1L
    if (characters[[id]] == "(") {
      depth <- depth - 1L
      if (depth == 0L) {
        open <- id
        break
      }
    }
  }
  if (is.na(open)) return(NULL)
  prefix <- trimws(substr(header, 1L, open - 1L))
  match <- regexec("([A-Za-z_~][A-Za-z0-9_:~]*)[[:space:]]*$", prefix)
  parts <- regmatches(prefix, match)[[1L]]
  if (length(parts) < 2L) return(NULL)
  name <- parts[[2L]]
  bare <- sub("^.*::", "", name)
  if (bare %in% c("if", "for", "while", "switch", "catch")) return(NULL)
  prefix_without_name <- trimws(sub(
    "([A-Za-z_~][A-Za-z0-9_:~]*)[[:space:]]*$", "", prefix
  ))
  if (!nzchar(prefix_without_name) ||
      grepl("(^|[^=!<>])=[^=]", prefix_without_name) ||
      grepl("\\]$", prefix_without_name)) return(NULL)
  name
}

provenance_native_rows <- function(path, relative) {
  original <- paste(readLines(path, warn = FALSE, encoding = "UTF-8"),
                    collapse = "\n")
  masked <- provenance_mask_native(original)
  characters <- strsplit(masked, "", fixed = TRUE)[[1L]]
  original_characters <- strsplit(original, "", fixed = TRUE)[[1L]]
  depth <- 0L
  start <- 1L
  active <- NULL
  rows <- list()
  line_at <- function(position) {
    if (position <= 1L) return(1L)
    1L + sum(characters[seq_len(position - 1L)] == "\n")
  }
  for (id in seq_along(characters)) {
    current <- characters[[id]]
    if (current == "{" && depth == 0L) {
      header <- paste(characters[seq.int(start, id - 1L)], collapse = "")
      name <- provenance_native_signature(header)
      if (!is.null(name)) {
        header_start <- start
        while (header_start < id &&
               characters[[header_start]] %in% c(" ", "\t", "\r", "\n")) {
          header_start <- header_start + 1L
        }
        active <- list(name = name, start = header_start, open = id)
      } else {
        active <- NULL
      }
      depth <- 1L
    } else if (current == "{" && depth > 0L) {
      depth <- depth + 1L
    } else if (current == "}" && depth > 0L) {
      depth <- depth - 1L
      if (depth == 0L) {
        if (!is.null(active)) {
          expression <- paste(
            original_characters[seq.int(active$start, id)], collapse = ""
          )
          normalized <- provenance_normalize_native(expression)
          rows[[length(rows) + 1L]] <- data.frame(
            path = relative,
            symbol = active$name,
            language = "C/C++",
            line_start = as.integer(line_at(active$start)),
            line_end = as.integer(line_at(id)),
            expression_hash = provenance_hash_text(normalized),
            generated_from = "",
            stringsAsFactors = FALSE
          )
        }
        active <- NULL
        start <- id + 1L
      }
    } else if (current == ";" && depth == 0L) {
      start <- id + 1L
    }
  }
  if (!length(rows)) return(NULL)
  do.call(rbind, rows)
}

provenance_rcpp_generators <- function(inventory, root) {
  candidates <- inventory[
    inventory$language == "C/C++" & !inventory$symbol %in% c("@file", "@generated"),
    , drop = FALSE
  ]
  if (!nrow(candidates)) return(character())
  keys <- character()
  for (id in seq_len(nrow(candidates))) {
    path <- file.path(root, candidates$path[[id]])
    lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
    start <- candidates$line_start[[id]]
    before <- if (start > 1L) seq_len(start - 1L) else integer()
    substantive <- before[nzchar(trimws(lines[before]))]
    annotation <- if (length(substantive)) lines[max(substantive)] else ""
    if (grepl("\\[\\[Rcpp::export", annotation, fixed = FALSE)) {
      keys <- c(keys, paste(candidates$path[[id]], candidates$symbol[[id]], sep = "::"))
    }
  }
  sort(unique(keys))
}


provenance_git_executable <- function() {
  candidates <- unique(c("/usr/bin/git", unname(Sys.which("git"))))
  candidates <- candidates[nzchar(candidates) & file.exists(candidates)]
  for (candidate in candidates) {
    status <- suppressWarnings(system2(
      candidate, "--version", stdout = FALSE, stderr = FALSE
    ))
    if (identical(as.integer(status), 0L)) return(candidate)
  }
  provenance_abort("PROVENANCE_GIT_UNAVAILABLE")
}

provenance_git_lines <- function(root, arguments) {
  output <- suppressWarnings(system2(
    provenance_git_executable(), c("-C", shQuote(root), arguments), stdout = TRUE, stderr = FALSE
  ))
  status <- attr(output, "status")
  if (!is.null(status) && !identical(as.integer(status), 0L)) character() else output
}

provenance_add_git_evidence <- function(inventory, root, include_git) {
  if (!isTRUE(include_git)) {
    inventory[["first_local_commit"]] <- "not-evaluated"
    inventory[["contributors"]] <- "not-evaluated"
    return(inventory)
  }
  inside <- provenance_git_lines(root, c("rev-parse", "--is-inside-work-tree"))
  if (!length(inside) || !identical(inside[[1L]], "true")) {
    provenance_abort("PROVENANCE_GIT_UNAVAILABLE")
  }
  first_commit <- character(nrow(inventory))
  contributors <- character(nrow(inventory))
  aggregate_symbols <- paste0(intToUtf8(64L), c("file", "generated"))
  for (id in seq_len(nrow(inventory))) {
    path <- inventory[["path"]][[id]]
    symbol <- inventory[["symbol"]][[id]]
    metadata <- character()
    if (!symbol %in% aggregate_symbols) {
      range <- sprintf("%d,%d:%s", inventory[["line_start"]][[id]],
                       inventory[["line_end"]][[id]], path)
      trace <- provenance_git_lines(
        root, c("log", "--format=GSD:%H__AUTHOR__%aN", "-L", range)
      )
      metadata <- trace[startsWith(trace, "GSD:")]
    }
    if (length(metadata)) {
      values <- strsplit(sub("^GSD:", "", metadata), "__AUTHOR__", fixed = TRUE)
      hashes <- vapply(values, function(value) value[[1L]], character(1))
      authors <- vapply(values, function(value) value[[2L]], character(1))
      first_commit[[id]] <- utils::tail(hashes, 1L)
      contributors[[id]] <- paste(sort(unique(authors)), collapse = "; ")
    } else {
      commits <- provenance_git_lines(
        root, c("log", "--follow", "--format=%H", "--reverse", "--", path)
      )
      authors <- provenance_git_lines(
        root, c("log", "--follow", "--format=%aN", "--", path)
      )
      first_commit[[id]] <- if (length(commits)) commits[[1L]] else "uncommitted"
      contributors[[id]] <- if (length(authors)) {
        paste(sort(unique(authors[nzchar(authors)])), collapse = "; ")
      } else {
        "uncommitted"
      }
    }
  }
  inventory[["first_local_commit"]] <- first_commit
  inventory[["contributors"]] <- contributors
  inventory
}

provenance_collect_sources <- function(root = ".", include_git = TRUE) {
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  files <- provenance_source_files(root)
  if (!length(files)) provenance_abort("PROVENANCE_SOURCE_EMPTY")
  generated_paths <- c("R/RcppExports.R", "src/RcppExports.cpp")
  rows <- list()
  generated <- character()
  for (path in files) {
    relative <- provenance_relative_path(path, root)
    line_count <- max(1L, length(readLines(path, warn = FALSE)))
    if (relative %in% generated_paths) {
      generated <- c(generated, relative)
      next
    }
    extracted <- if (grepl("\\.R$", relative, ignore.case = TRUE)) {
      provenance_r_rows(path, relative)
    } else {
      provenance_native_rows(path, relative)
    }
    if (is.null(extracted) || !nrow(extracted)) {
      language <- if (grepl("\\.R$", relative, ignore.case = TRUE)) "R" else "C/C++"
      extracted <- data.frame(
        path = relative,
        symbol = "@file",
        language = language,
        line_start = 1L,
        line_end = as.integer(line_count),
        expression_hash = provenance_hash_text(
          paste(readLines(path, warn = FALSE), collapse = "\n")
        ),
        generated_from = "",
        stringsAsFactors = FALSE
      )
    }
    rows[[length(rows) + 1L]] <- extracted
  }
  inventory <- if (length(rows)) do.call(rbind, rows) else data.frame(
    path = character(), symbol = character(), language = character(),
    line_start = integer(), line_end = integer(), expression_hash = character(),
    generated_from = character(), stringsAsFactors = FALSE
  )
  generators <- provenance_rcpp_generators(inventory, root)
  if (length(generated)) {
    generated_rows <- lapply(generated, function(relative) {
      path <- file.path(root, relative)
      line_count <- max(1L, length(readLines(path, warn = FALSE)))
      data.frame(
        path = relative,
        symbol = "@generated",
        language = if (grepl("\\.R$", relative)) "R" else "C/C++",
        line_start = 1L,
        line_end = as.integer(line_count),
        expression_hash = provenance_hash_text(
          paste(readLines(path, warn = FALSE), collapse = "\n")
        ),
        generated_from = paste(generators, collapse = ";"),
        stringsAsFactors = FALSE
      )
    })
    inventory <- rbind(inventory, do.call(rbind, generated_rows))
  }
  if (!nrow(inventory)) provenance_abort("PROVENANCE_SOURCE_EMPTY")
  order_id <- order(inventory$path, inventory$symbol, method = "radix")
  inventory <- inventory[order_id, , drop = FALSE]
  rownames(inventory) <- NULL
  provenance_add_git_evidence(inventory, root, include_git)
}

provenance_key_frame <- function(frame) {
  if (!all(c("path", "symbol") %in% names(frame))) {
    provenance_abort("PROVENANCE_COLUMNS_MISSING", "path,symbol")
  }
  paste(as.character(frame$path), as.character(frame$symbol), sep = "::")
}

provenance_validate_keys <- function(actual, expected) {
  actual_keys <- provenance_key_frame(actual)
  expected_keys <- provenance_key_frame(expected)
  if (anyDuplicated(actual_keys) || anyDuplicated(expected_keys)) {
    provenance_abort("PROVENANCE_DUPLICATE_KEY")
  }
  missing <- setdiff(expected_keys, actual_keys)
  extra <- setdiff(actual_keys, expected_keys)
  if (length(missing) || length(extra)) {
    rekeyed <- length(actual_keys) == length(expected_keys) &&
      length(missing) == length(extra)
    provenance_abort(
      "PROVENANCE_KEY_MISMATCH",
      sprintf("missing=%d extra=%d rekeyed=%s",
              length(missing), length(extra), toupper(as.character(rekeyed)))
    )
  }
  TRUE
}

provenance_build_ledger <- function(inventory, existing = NULL) {
  ledger <- data.frame(
    path = inventory$path,
    symbol = inventory$symbol,
    language = inventory$language,
    classification = "unknown",
    upstream_repository = "",
    upstream_commit = "",
    upstream_path = "",
    first_local_commit = inventory$first_local_commit,
    expression_hash = inventory$expression_hash,
    contributors = inventory$contributors,
    copyright_holder = "",
    license_basis = "",
    evidence = sprintf("source-lines:%d-%d; git-history-is-evidence-not-ownership",
                       inventory$line_start, inventory$line_end),
    reviewer = "",
    review_date = "",
    status = "unreviewed",
    notes = ifelse(
      inventory$symbol == "@generated",
      paste0("generated-from:", inventory$generated_from),
      ""
    ),
    stringsAsFactors = FALSE
  )
  if (is.null(existing) || !nrow(existing)) return(ledger)
  if (!identical(names(existing), provenance_columns)) {
    provenance_abort("PROVENANCE_COLUMNS_MISSING")
  }
  new_keys <- provenance_key_frame(ledger)
  old_keys <- provenance_key_frame(existing)
  match_id <- match(new_keys, old_keys)
  preserve <- c(
    "classification", "upstream_repository", "upstream_commit", "upstream_path",
    "contributors", "copyright_holder", "license_basis", "evidence", "reviewer",
    "review_date", "status", "notes"
  )
  found <- !is.na(match_id)
  for (column in preserve) {
    ledger[[column]][found] <- existing[[column]][match_id[found]]
  }
  changed <- found & ledger$expression_hash != existing$expression_hash[match_id]
  ledger$status[changed] <- "hash-changed-review-required"
  ledger
}

provenance_validate_review_fields <- function(ledger) {
  required_columns <- c(
    "classification", "upstream_repository", "upstream_commit",
    "upstream_path", "contributors", "copyright_holder", "license_basis",
    "evidence", "reviewer", "review_date", "status"
  )
  if (!all(required_columns %in% names(ledger))) {
    provenance_abort("PROVENANCE_COLUMNS_MISSING")
  }
  status_by_classification <- c(
    "inherited-identical" = "reviewed-cleared",
    "inherited-modified" = "reviewed-mixed-provisional",
    "new-independent" = "reviewed-provisional",
    "generated" = "reviewed-generated",
    "third-party" = "reviewed-third-party"
  )
  known_classification <- ledger$classification %in%
    names(status_by_classification)
  compatible_status <- rep(FALSE, nrow(ledger))
  compatible_status[known_classification] <-
    ledger$status[known_classification] == unname(status_by_classification[
      ledger$classification[known_classification]
    ])
  parsed_date <- suppressWarnings(as.Date(
    ledger$review_date, format = "%Y-%m-%d"
  ))
  round_trip_date <- rep("", nrow(ledger))
  valid_date <- !is.na(parsed_date)
  round_trip_date[valid_date] <- format(parsed_date[valid_date], "%Y-%m-%d")
  required_review <- c(
    "contributors", "copyright_holder", "license_basis", "evidence",
    "reviewer", "review_date", "status"
  )
  complete_review <- !Reduce(`|`, lapply(required_review, function(column) {
    is.na(ledger[[column]]) | !nzchar(ledger[[column]])
  }))
  third_party <- ledger$classification == "third-party"
  complete_third_party <- !third_party | (
    nzchar(ledger$upstream_repository) &
      nzchar(ledger$upstream_commit) &
      nzchar(ledger$upstream_path)
  )
  blocking <- !known_classification | !compatible_status | !complete_review |
    !valid_date | round_trip_date != ledger$review_date | !complete_third_party
  blocking[is.na(blocking)] <- TRUE
  if (any(blocking)) {
    provenance_abort("PROVENANCE_ROW_BLOCKING", sprintf("rows=%d", sum(blocking)))
  }
  TRUE
}

provenance_validate_ledger <- function(ledger, expected, inventory) {
  if (!identical(names(ledger), provenance_columns)) {
    provenance_abort("PROVENANCE_COLUMNS_MISSING")
  }
  provenance_validate_keys(ledger, expected)
  provenance_validate_keys(inventory, expected)
  keys <- provenance_key_frame(ledger)
  inventory_id <- match(keys, provenance_key_frame(inventory))
  if (anyNA(inventory_id) ||
      any(ledger$expression_hash != inventory$expression_hash[inventory_id])) {
    provenance_abort("PROVENANCE_KEY_MISMATCH", "expression-hash")
  }
  provenance_validate_review_fields(ledger)
  allowed <- c(
    "inherited-identical", "inherited-modified", "new-independent",
    "generated", "third-party", "unknown"
  )
  required <- c(
    "classification", "first_local_commit", "expression_hash", "contributors",
    "copyright_holder", "license_basis", "evidence", "reviewer", "review_date",
    "status"
  )
  blocking <- !ledger$classification %in% allowed |
    ledger$classification == "unknown" |
    Reduce(`|`, lapply(required, function(column) !nzchar(ledger[[column]]))) |
    ledger$status %in% c("unreviewed", "hash-changed-review-required", "blocking")
  inherited <- ledger$classification %in% c("inherited-identical", "inherited-modified")
  blocking <- blocking | (inherited & (
    !nzchar(ledger$upstream_repository) |
      !nzchar(ledger$upstream_commit) |
      !nzchar(ledger$upstream_path)
  ))
  independent <- ledger$classification == "new-independent"
  blocking <- blocking | (independent & (
    nzchar(ledger$upstream_repository) |
      nzchar(ledger$upstream_commit) |
      nzchar(ledger$upstream_path)
  ))
  third_party <- ledger[["classification"]] == "third-party"
  blocking <- blocking | (third_party & (
    !nzchar(ledger[["upstream_repository"]]) |
      !nzchar(ledger[["upstream_commit"]]) |
      !nzchar(ledger[["upstream_path"]])
  ))
  generated <- ledger[["classification"]] == "generated"
  blocking <- blocking | (generated & !grepl("generated-from:", ledger$notes,
                                             fixed = TRUE))
  if (any(blocking)) {
    provenance_abort("PROVENANCE_ROW_BLOCKING", sprintf("rows=%d", sum(blocking)))
  }
  TRUE
}

provenance_read_csv <- function(path, columns = NULL) {
  if (!file.exists(path)) provenance_abort("PROVENANCE_FILE_MISSING")
  value <- tryCatch(
    utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE,
             colClasses = "character",
             na.strings = NULL),
    error = function(error) provenance_abort(
      "PROVENANCE_CSV_INVALID", conditionMessage(error)
    )
  )
  value[] <- lapply(value, as.character)
  if (!is.null(columns) && !identical(names(value), columns)) {
    provenance_abort("PROVENANCE_COLUMNS_MISSING")
  }
  value
}

provenance_argument <- function(args, name, default = NULL) {
  exact <- which(args == name)
  if (length(exact)) {
    id <- exact[[1L]]
    if (id == length(args)) provenance_abort("PROVENANCE_ARGUMENT_MISSING", name)
    return(args[[id + 1L]])
  }
  prefix <- paste0(name, "=")
  inline <- args[startsWith(args, prefix)]
  if (length(inline)) return(sub(prefix, "", inline[[1L]], fixed = TRUE))
  default
}

provenance_main <- function(args = commandArgs(trailingOnly = TRUE)) {
  if (!"--check" %in% args) {
    provenance_abort("PROVENANCE_MODE_REQUIRED", "use --check")
  }
  root <- provenance_argument(args, "--root", ".")
  expected_path <- provenance_argument(
    args, "--expected", file.path(root, "docs", "provenance", "EXPECTED-KEYS.csv")
  )
  ledger_path <- provenance_argument(
    args, "--ledger", file.path(root, "docs", "provenance", "PROVENANCE.csv")
  )
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  expected <- provenance_read_csv(expected_path, c("path", "symbol"))
  ledger <- provenance_read_csv(ledger_path, provenance_columns)
  inventory <- provenance_collect_sources(root, include_git = TRUE)
  provenance_validate_ledger(ledger, expected, inventory)
  message(sprintf("provenance_status=reviewed rows=%d expected_keys=%d",
                  nrow(ledger), nrow(expected)))
  invisible(list(inventory = inventory, ledger = ledger, expected = expected))
}

if (sys.nframe() == 0L) {
  tryCatch(
    provenance_main(),
    error = function(error) {
      message(conditionMessage(error))
      quit(save = "no", status = 1L, runLast = FALSE)
    }
  )
}
