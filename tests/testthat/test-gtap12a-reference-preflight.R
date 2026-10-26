test_that("sourced preflight identifies its own file rather than the caller", {
  preflight = gtap12a_preflight_source()
  expect_identical(preflight$preflight_script_file, normalizePath(
    testthat::test_path("..", "..", "benchmarks",
                       "preflight_gtap12a_reference.R"), mustWork = TRUE
  ))
  expect_true(is.function(preflight$benchmark_signature))
})

test_that("reference preflight accepts complete matched synthetic evidence", {
  preflight = gtap12a_preflight_source()
  fixture = gtap12a_preflight_fixture(preflight)
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)
  fixture$options$output = file.path(fixture$root, "preflight-report.dcf")
  before = tools::md5sum(list.files(
    fixture$reference_dir, full.names = TRUE, recursive = TRUE
  ))

  result = preflight$preflight_gtap12a_reference(
    fixture$options, repo_root = testthat::test_path("..", "..")
  )

  expect_identical(result$reference_preflight_status, "eligible",
                   info = paste(result$reason_codes, collapse = ", "))
  expect_true(length(result$reason_codes) == 0L,
              info = paste(result$reason_codes, collapse = ", "))
  expect_equal(result$reference_csv_count, 4L)
  expect_equal(result$reference_solution_count, 3L)
  expect_equal(result$measured_repetitions, 3L)
  expect_equal(result$warmup_count, 1L)
  expect_true(file.exists(fixture$options$output))
  report = readLines(fixture$options$output, warn = FALSE)
  expect_false(any(grepl(fixture$root, report, fixed = TRUE)))
  expect_false(any(grepl("basedata.har", report, fixed = TRUE)))
  expect_identical(before, tools::md5sum(list.files(
    fixture$reference_dir, full.names = TRUE, recursive = TRUE
  )))
})

test_that("reference preflight identifies missing raw solution evidence", {
  preflight = gtap12a_preflight_source()
  fixture = gtap12a_preflight_fixture(preflight)
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)
  unlink(file.path(fixture$reference_dir, "measured-03.rds"))

  result = preflight$preflight_gtap12a_reference(
    fixture$options, repo_root = testthat::test_path("..", "..")
  )

  expect_identical(result$reference_preflight_status, "blocked")
  expect_true("reference_solution_missing" %in% result$reason_codes)
})

test_that("reference preflight identifies missing CSV metadata", {
  preflight = gtap12a_preflight_source()
  fixture = gtap12a_preflight_fixture(preflight)
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)
  path = file.path(fixture$reference_dir, "warmup-01.csv")
  frame = read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  frame$installed_package_signature = NULL
  write.csv(frame, path, row.names = FALSE)

  result = preflight$preflight_gtap12a_reference(
    fixture$options, repo_root = testthat::test_path("..", "..")
  )

  expect_identical(result$reference_preflight_status, "blocked")
  expect_true("reference_csv_metadata_missing" %in% result$reason_codes)
})

test_that("reference preflight rejects stale CSV runtime metadata", {
  preflight = gtap12a_preflight_source()
  fixture = gtap12a_preflight_fixture(preflight)
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)
  paths = list.files(fixture$reference_dir, pattern = "[.]csv$",
                     full.names = TRUE)
  for (path in paths) {
    frame = read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
    frame$matrix_version = "stale-matrix-version"
    write.csv(frame, path, row.names = FALSE)
  }

  result = preflight$preflight_gtap12a_reference(
    fixture$options, repo_root = testthat::test_path("..", "..")
  )

  expect_identical(result$reference_preflight_status, "blocked")
  expect_true(any(grepl("reference_metadata_mismatch_matrix_version",
                        result$reason_codes)))
})

test_that("reference preflight rejects mismatched local input fingerprints", {
  preflight = gtap12a_preflight_source()
  fixture = gtap12a_preflight_fixture(preflight)
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)
  writeLines("changed synthetic data", file.path(fixture$data_dir, "basedata.har"))

  result = preflight$preflight_gtap12a_reference(
    fixture$options, repo_root = testthat::test_path("..", "..")
  )

  expect_identical(result$reference_preflight_status, "blocked")
  expect_true("input_model_signature_mismatch" %in% result$reason_codes)
})
