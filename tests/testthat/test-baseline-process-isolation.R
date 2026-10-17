test_that("source proposals cannot reload the caller's namespace or runtime", {
  root = normalizePath(testthat::test_path("..", ".."), mustWork = TRUE)
  tool_path = file.path(root, "inst", "tools", "refresh_phase02_baselines.R")
  skip_if_not(file.exists(tool_path), "Source baseline tooling is unavailable")
  tool = new.env(parent = globalenv())
  sys.source(tool_path, envir = tool)
  # A sourced tool may inherit --file= from an unrelated outer Rscript.
  tool$phase02_script_path = tempfile("unrelated-caller-", fileext = ".R")
  writeLines("stop('The outer test runner must never be sourced')",
             tool$phase02_script_path)
  on.exit(unlink(tool$phase02_script_path), add = TRUE)
  old_tests = Sys.getenv("R_TESTS", unset = NA_character_)
  on.exit({
    if (is.na(old_tests)) Sys.unsetenv("R_TESTS") else Sys.setenv(R_TESTS = old_tests)
  }, add = TRUE)
  Sys.setenv(R_TESTS = tool$phase02_script_path)
  namespace = asNamespace("GEModelR")
  registry = get(".sparse_backend_registry", namespace)
  runtime = get(".sparse_schur_cpp_runtime", namespace)
  caller_evaluated = FALSE
  tool$phase02_runtime_environment = function(...) {
    caller_evaluated <<- TRUE
    stop("Source evaluation must not execute in the caller")
  }
  output = tempfile("isolated-baseline-")
  on.exit(unlink(output, recursive = TRUE), add = TRUE)
  result = tool$phase02_generate_proposal(output, root = root)
  expect_false(caller_evaluated)
  expect_identical(asNamespace("GEModelR"), namespace)
  expect_identical(get(".sparse_backend_registry", namespace), registry)
  expect_identical(get(".sparse_schur_cpp_runtime", namespace), runtime)
  expect_true(file.exists(file.path(result$output, "expectations.csv")))
})
