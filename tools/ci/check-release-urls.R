#!/usr/bin/env Rscript
# GEModelR_RELEASE_URL_CHECK: separate evidence; a clean R check is not a URL pass.
check = function() {
  controls = tolower(Sys.getenv(c("_R_CHECK_CRAN_INCOMING_", "_R_CHECK_CRAN_INCOMING_REMOTE_"), unset = ""))
  skip = tolower(Sys.getenv("_R_CHECK_CRAN_INCOMING_SKIP_URL_CHECKS_IF_REMOTE_", unset = ""))
  if (any(controls %in% c("false", "f", "0", "no")) || skip %in% c("true", "t", "1", "yes"))
    return(list(status = "unavailable", reason = "URL_CHECK_DISABLED"))
  if (!capabilities("libcurl")) return(list(status = "unavailable", reason = "URL_CHECK_NO_LIBCURL"))
  collect = getFromNamespace("url_db_from_package_sources", "tools")
  validate = getFromNamespace("check_url_db", "tools")
  urls = withCallingHandlers(collect(commandArgs(TRUE)[[1L]]), warning = function(w) stop("URL_CHECK_WARNING"))
  if (!NROW(urls)) return(list(status = "not_applicable", reason = "NO_URLS"))
  bad = withCallingHandlers(validate(urls, remote = TRUE), warning = function(w) stop("URL_CHECK_WARNING"))
  if (NROW(bad)) list(status = "failed", reason = "URLS_INVALID")
  else list(status = "passed", reason = "URLS_VALIDATED")
}
result = tryCatch(check(), error = function(e) list(status = "unavailable", reason = "URL_CHECK_UNAVAILABLE"))
cat(sprintf('{"status":"%s","reason":"%s"}', result$status, result$reason))

if (!result$status %in% c("passed", "not_applicable")) quit(status = 1L)
