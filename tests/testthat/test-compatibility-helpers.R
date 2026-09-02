test_that("structural descriptors distinguish empty singleton and NULL values", {
  expect_identical(
    describeCompatibilityStructure(numeric()),
    list(
      class = "numeric",
      type = "double",
      length = 0L,
      names = NULL,
      dim = NULL,
      dimnames = NULL,
      missing = logical(),
      encoding = character()
    )
  )
  expect_identical(
    describeCompatibilityStructure(c(item = 7)),
    list(
      class = "numeric",
      type = "double",
      length = 1L,
      names = "item",
      dim = NULL,
      dimnames = NULL,
      missing = FALSE,
      encoding = character()
    )
  )
  expect_identical(
    describeCompatibilityStructure(NULL),
    list(
      class = "NULL",
      type = "NULL",
      length = 0L,
      names = NULL,
      dim = NULL,
      dimnames = NULL,
      missing = logical(),
      encoding = character()
    )
  )
})

test_that("structural descriptors preserve indexed array metadata", {
  indexed = array(
    c(1, NA, 3, 4),
    dim = c(2L, 2L),
    dimnames = list(
      region = c("r1", "r2"),
      commodity = c("c1", "c2")
    )
  )
  descriptor = describeCompatibilityStructure(indexed)

  expect_identical(descriptor$class, c("matrix", "array"))
  expect_identical(descriptor$type, "double")
  expect_identical(descriptor$length, 4L)
  expect_null(descriptor$names)
  expect_identical(descriptor$dim, c(2L, 2L))
  expect_identical(descriptor$dimnames, dimnames(indexed))
  expect_identical(descriptor$missing, c(FALSE, TRUE, FALSE, FALSE))
  expect_identical(descriptor$encoding, character())
})

test_that("selectors preserve dimensions and omitted selection is identity", {
  indexed = array(
    1:4,
    dim = c(2L, 2L),
    dimnames = list(
      region = c("r1", "r2"),
      commodity = c("c1", "c2")
    )
  )
  selected = sparse_subset_output(
    indexed,
    list(region = "r2", commodity = "c1")
  )

  expect_identical(dim(selected), c(1L, 1L))
  expect_identical(
    dimnames(selected),
    list(region = "r2", commodity = "c1")
  )
  expect_identical(as.integer(selected), 2L)
  expect_identical(sparse_subset_output(indexed, NULL), indexed)
  expect_identical(sparse_subset_output(indexed, list()), indexed)
})

test_that("character equality can require exact encoding metadata", {
  utf8 = "\u00e9"
  Encoding(utf8) = "UTF-8"
  latin1 = iconv(utf8, from = "UTF-8", to = "latin1")
  Encoding(latin1) = "latin1"
  values = c(utf8 = utf8, latin1 = latin1)

  expect_identical(
    describeCompatibilityStructure(values)$encoding,
    c("UTF-8", "latin1")
  )
  expect_true(compatibilityValuesEqual(utf8, latin1, check_encoding = FALSE))
  expect_false(compatibilityValuesEqual(utf8, latin1, check_encoding = TRUE))
  expect_true(compatibilityValuesEqual(NULL, NULL))
})

test_that("omitted defaults match their explicit compatibility values", {
  expect_true(compatibilityDefaultEquivalent(
    "loadData", "engine", "legacy"
  ))
  expect_true(compatibilityDefaultEquivalent(
    "solveModel", "engine", "legacy"
  ))
  expect_true(compatibilityDefaultEquivalent(
    "solveModel", "backend", "Matrix"
  ))
  expect_true(compatibilityDefaultEquivalent(
    "solveModel", "output", "full"
  ))
  expect_true(compatibilityDefaultEquivalent(
    "solveModel", "reduction", "auto"
  ))
  expect_true(compatibilityDefaultEquivalent(
    "solveModel", "steps", c(1, 3)
  ))
  expect_true(compatibilityDefaultEquivalent(
    "solveModel", "variables", NULL
  ))
  expect_false(compatibilityDefaultEquivalent(
    "solveModel", "backend", "SparseM"
  ))
})
