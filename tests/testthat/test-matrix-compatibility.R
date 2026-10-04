matrixCompatibilityVersion = function(version) {
  if (length(version) != 1L || is.na(version) ||
      !grepl("^[0-9]+([.-][0-9]+)+$", version)) {
    stop("Expected a numeric Matrix version", call. = FALSE)
  }
  as.character(package_version(version))
}

matrixCompatibilityMinimum = function(imports) {
  declarations = trimws(strsplit(imports, ",", fixed = TRUE)[[1L]])
  declaration = declarations[grepl("^Matrix($|[[:space:](])", declarations)]
  if (length(declaration) != 1L) {
    stop("Expected one Matrix Imports declaration", call. = FALSE)
  }
  if (identical(declaration, "Matrix")) return(NULL)
  match = regexec(
    "^Matrix[[:space:]]*\\([[:space:]]*>=[[:space:]]*([0-9]+([.-][0-9]+)+)[[:space:]]*\\)$",
    declaration
  )
  fields = regmatches(declaration, match)[[1L]]
  if (!length(fields)) {
    stop("Expected a Matrix >= minimum declaration", call. = FALSE)
  }
  matrixCompatibilityVersion(fields[[2L]])
}

test_that("installed Matrix matches the requested compatibility endpoint", {
  expected = Sys.getenv("GEModelR_EXPECT_MATRIX_VERSION", unset = "installed")
  installed = as.character(packageVersion("Matrix"))
  if (!identical(expected, "installed")) {
    expect_identical(
      installed, matrixCompatibilityVersion(expected),
      info = paste("Requested Matrix endpoint:", expected)
    )
  } else {
    expect_true(nzchar(installed))
  }
})

test_that("installed Matrix satisfies any declared GEModelR minimum", {
  imports = packageDescription("GEModelR", fields = "Imports")
  minimum = matrixCompatibilityMinimum(imports)
  if (is.null(minimum)) {
    # Endpoint evidence precedes the floor declaration in plan 05-07.
    expect_null(minimum)
  } else {
    expect_true(
      packageVersion("Matrix") >= package_version(minimum),
      info = paste("GEModelR declares Matrix >=", minimum)
    )
  }
})

test_that("Matrix endpoint spelling and conditional floor parsing are exact", {
  expect_identical(matrixCompatibilityVersion("1.6-5"), "1.6.5")
  expect_false(identical(matrixCompatibilityVersion("1.6-5"), "1.6.3"))
  expect_error(matrixCompatibilityVersion(""), "numeric Matrix version")
  expect_error(matrixCompatibilityVersion("latest"), "numeric Matrix version")
  expect_null(matrixCompatibilityMinimum("Matrix, Rcpp, methods"))
  minimum = matrixCompatibilityMinimum("Rcpp, Matrix (>= 1.6-5), methods")
  expect_identical(minimum, "1.6.5")
  expect_true(package_version("1.6.5") >= package_version(minimum))
  expect_false(package_version("1.6.3") >= package_version(minimum))
  expect_error(matrixCompatibilityMinimum("Matrix (>= latest)"), "minimum")
  expect_error(matrixCompatibilityMinimum("Matrix, Matrix"), "one Matrix")
})
