nativeOpenmpExpectation = function(
    expectation = Sys.getenv("GEModelR_EXPECT_OPENMP", unset = ""),
    ci = tolower(Sys.getenv("CI", unset = "")) %in% c("true", "1") ||
      tolower(Sys.getenv("GITHUB_ACTIONS", unset = "")) == "true" ||
      nzchar(Sys.getenv("GEModelR_TEST_LIBRARY", unset = ""))) {
  if (identical(expectation, "") && !ci) return(NULL)
  if (!expectation %in% c("required", "forbidden")) {
    stop(
      "GEModelR_EXPECT_OPENMP must be explicitly set to required or forbidden",
      call. = FALSE
    )
  }
  expectation
}

nativeOpenmpCapabilities = function(
    capabilities = .GEModelR_schur_cpp_capabilities(),
    expectation = nativeOpenmpExpectation()) {
  if (identical(expectation, "forbidden")) {
    expect_identical(capabilities$openmp, FALSE)
    expect_identical(capabilities$max_threads, 1L)
  } else {
    expect_identical(capabilities$openmp, TRUE)
    expect_gte(capabilities$max_threads, 2L)
  }
  capabilities
}
