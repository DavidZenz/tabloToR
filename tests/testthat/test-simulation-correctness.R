solve_from_tablo = function(lines, closure, shocks, engine = "sparse",
                            input = list(), iter = 1L, steps = 1L) {
  path = tempfile(fileext = ".tab")
  on.exit(unlink(path))
  writeLines(lines, path)
  model = GEModel$new()
  model$loadTablo(path)
  model$setClosure(closure)
  model$loadData(input, engine = engine)
  model$setShocks(shocks)
  suppressMessages(model$solveModel(iter = iter, steps = steps, engine = engine))
  model
}

test_that("ordinary and percentage shocks retain their units across steps", {
  lines = c(
    "set reg (r1,r2);",
    "variable (all,r,reg)(change) amount(r);",
    "variable (all,r,reg)(change) quantity(r);",
    "variable (all,r,reg) rate(r);",
    "variable (all,r,reg) price(r);",
    "equation quantities (all,r,reg) quantity(r) = amount(r);",
    "equation prices (all,r,reg) price(r) = rate(r);"
  )
  shocks = c('amount["r1"]' = -200, 'amount["r2"]' = 20, 'rate["r2"]' = 30)
  expected = c('quantity["r1"]' = -200, 'quantity["r2"]' = 20,
               'price["r1"]' = 0, 'price["r2"]' = 30)
  for (engine in c("sparse", "legacy")) {
    model = solve_from_tablo(lines, c("amount", "rate"), shocks,
                            engine = engine, iter = 2L, steps = c(1L, 2L))
    expect_equal(model$solution[names(expected)], expected, tolerance = 1e-12)
  }
})

test_that("quoted numeric indices select labels and numeric indices select positions", {
  lines = c(
    'set reg read elements from file basedata header "REGN";',
    "coefficient (all,r,reg) weight(r);",
    'read weight from file basedata header "WGHT";',
    "variable (all,r,reg) a(r);",
    "variable x;",
    'equation example x = weight("1") * a("1") + a(1);'
  )
  input = list(basedata = list(regn = c("2", "1"), wght = c(5, 2)))
  shocks = c('a["2"]' = 3, 'a["1"]' = 9)
  for (vectorized in c(FALSE, TRUE)) {
    withr::local_options(list(GEModelR.sparse.vectorized = vectorized))
    model = solve_from_tablo(lines, "a", shocks, input = input)
    expect_equal(model$solution, c("x[]" = 21))
    expect_error(
      solve_from_tablo(
        c(lines[-length(lines)], 'equation example x = a("1");'),
        "a", c('a["2"]' = 3),
        input = list(basedata = list(regn = c("2", "4"), wght = c(5, 2)))
      ),
      "Cannot resolve index|Sparse vectorized index failure"
    )
  }
})

test_that("equation sums include sets used only as summation domains", {
  lines = c(
    "set members (aa,bb);",
    "coefficient (all,r,members) weight(r);",
    'read weight from file basedata header "WGHT";',
    "variable a;",
    "variable x;",
    "equation example x = sum(r,members,weight(r) * a);"
  )
  input = list(basedata = list(wght = c(2, 3)))
  for (vectorized in c(FALSE, TRUE)) {
    withr::local_options(list(GEModelR.sparse.vectorized = vectorized))
    model = solve_from_tablo(lines, "a", c("a[]" = 4), input = input)
    expect_equal(model$solution, c("x[]" = 20))
  }
})

test_that("formulas referenced only by equation guards are initialized", {
  lines = c(
    "set reg (r1,r2);",
    "coefficient (all,r,reg) flag(r);",
    "formula (all,r,reg) flag(r) = 1;",
    "variable (all,r,reg) a(r);",
    "variable (all,r,reg) x(r);",
    "equation example (all,r,reg) x(r) = IF(flag(r) gt 0, a(r));"
  )
  model = solve_from_tablo(lines, "a", c('a["r2"]' = 4))
  expect_equal(model$solution, c('x["r1"]' = 0, 'x["r2"]' = 4))
})

test_that("optional reads preserve defaults and retain supplied headers", {
  lines = c(
    "set reg (r1,r2);",
    "coefficient base;",
    "formula (initial) base = 2;",
    "coefficient (all,r,reg) weight(r);",
    "formula (all,r,reg) weight(r) = base;",
    "coefficient (all,r,reg) before(r);",
    "formula (initial)(all,r,reg) before(r) = weight(r);",
    'read (ifheaderexists) weight from file basedata header "WGHT";',
    "variable (all,r,reg)(change) a(r);",
    "variable (all,r,reg)(change) x(r);",
    "equation example (all,r,reg) x(r) = (weight(r) + before(r)) * a(r);"
  )
  for (engine in c("sparse", "legacy")) {
    for (present in c(FALSE, TRUE)) {
      input = list(basedata = if (present) list(wght = c(3, 5)) else
                     list(wght_extra = c(3, 5)))
      model = solve_from_tablo(lines, "a", c('a["r2"]' = 4), input = input,
                              engine = engine, iter = 2L, steps = 2L)
      expected = if (present) 28 else 16
      expect_equal(model$solution, c('x["r1"]' = 0, 'x["r2"]' = expected))
      expect_equal(as.numeric(model$data$before), c(2, 2))
      expect_equal(as.numeric(model$data$weight),
                   if (present) c(3, 5) else c(2, 2))
    }
  }
})
