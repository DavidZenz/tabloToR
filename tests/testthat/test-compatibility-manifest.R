test_that("compatibility manifest covers the observed package surface", {
  manifest = loadCompatibilityManifest()
  observed = observedCompatibilitySurface()

  expect_identical(
    sort(manifest$name[
      manifest$kind == "export" & manifest$tier == "supported"
    ]),
    observed$exports
  )
  expect_identical(
    sort(manifest$name[manifest$kind == "field"]),
    observed$fields
  )
  expect_identical(
    sort(manifest$name[manifest$kind == "method"]),
    observed$methods
  )
  expect_identical(
    sort(manifest$name[manifest$kind == "backend"]),
    observed$backends
  )
})

test_that("compatibility manifest is tiered and duplicate free", {
  manifest = loadCompatibilityManifest()
  keys = paste(manifest$kind, manifest$name, sep = ":")

  expect_false(anyDuplicated(keys) > 0L)
  expect_true(all(manifest$tier %in% c(
    "supported", "compatibility-only", "internal"
  )))
  expect_true(all(nzchar(manifest$type)))
  expect_true(all(vapply(
    manifest[c("COMP_01", "COMP_02", "COMP_03")],
    is.logical,
    logical(1)
  )))
  expect_true(all(rowSums(manifest[c("COMP_01", "COMP_02", "COMP_03")]) > 0L))
})

test_that("method signatures and source defaults are exact", {
  manifest = loadCompatibilityManifest()
  expected = compatibilityMethodContract()
  recorded = manifest[manifest$kind == "method",
                      c("name", "signature", "defaults")]
  recorded = recorded[order(recorded$name), , drop = FALSE]
  rownames(recorded) = NULL

  expect_identical(recorded, expected)
  expect_identical(
    expected$defaults[expected$name == "loadData"],
    "inputData=<required>;engine=c(\"legacy\", \"sparse\")"
  )
  expect_identical(
    expected$defaults[expected$name == "solveModel"],
    paste0(
      "iter=3;steps=c(1, 3);engine=c(\"legacy\", \"sparse\");",
      "postsim=TRUE;diagnostics=FALSE;",
      "output=c(\"full\", \"compact\");variables=NULL;dimensions=NULL;",
      "backend=\"Matrix\";reduction=c(\"auto\", \"off\", \"on\");",
      "memory_budget=NULL"
    )
  )
})

test_that("serialization and numerical authority remain explicitly scoped", {
  manifest = loadCompatibilityManifest()
  raw = manifest[
    manifest$kind == "serialization" &
      manifest$name == "raw-saveRDS-model",
    ,
    drop = FALSE
  ]
  authority = manifest[manifest$kind == "authority",
                       c("name", "tier", "output")]

  expect_equal(nrow(raw), 1L)
  expect_identical(raw$tier, "compatibility-only")
  expect_identical(raw$serialization, "same-version-best-effort")
  expect_identical(
    authority$name[authority$output == "compatibility-smoke"],
    "legacy"
  )
  expect_setequal(
    authority$name[authority$output == "numerical-reference"],
    c("Matrix", "StructuredSchurFGMRES")
  )
})
