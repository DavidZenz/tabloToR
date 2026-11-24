load_from_tablo = function(lines, closure, engine = "sparse", input = list()) {
  path = tempfile(fileext = ".tab")
  on.exit(unlink(path))
  writeLines(lines, path)
  model = GEModel$new()
  model$loadTablo(path)
  model$setClosure(closure)
  model$loadData(input, engine = engine)
  model
}

solve_from_tablo = function(lines, closure, shocks, engine = "sparse",
                            input = list(), iter = 1L, steps = 1L) {
  model = load_from_tablo(lines, closure, engine, input)
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

test_that("data-dependent sets see optional reads in declaration order", {
  lines = c(
    "set reg (r1,r2,r3);",
    "coefficient base;",
    "formula (initial) base = 2;",
    "coefficient (all,r,reg) weight(r);",
    "formula (initial)(all,r,reg) weight(r) = base;",
    "coefficient (all,r,reg) before(r);",
    "formula (initial)(all,r,reg) before(r) = weight(r);",
    'read (ifheaderexists) weight from file basedata header "WGHT";',
    "set active = (all,r,reg: weight(r) gt 0);",
    "variable a;",
    "variable (all,r,active) x(r);",
    "equation example (all,r,active) x(r) = before(r) * a;"
  )
  for (engine in c("sparse", "legacy")) {
    for (present in c(TRUE, FALSE)) {
      headers = if (present) list(wght = c(2, 3, -1)) else list()
      model = solve_from_tablo(lines, "a", c("a[]" = 4), engine,
                                input = list(basedata = headers))
      active = if (present) c("r1", "r2") else c("r1", "r2", "r3")
      expect_identical(model$data$active, active)
      expect_equal(model$solution, setNames(rep(8, length(active)),
                                            sprintf('x["%s"]', active)))
      expect_equal(as.numeric(model$data$before), rep(2, 3))
    }
  }
})

test_that("product updates convert every factor to a percentage multiplier", {
  lines = c(
    "coefficient stock;",
    'read stock from file basedata header "STOK";',
    "variable a;", "variable b;", "variable c;", "variable x;",
    "equation example x = a;"
  )
  input = list(basedata = list(stok = 100))
  shocks = c("a[]" = 10, "b[]" = 20, "c[]" = 30)
  for (engine in c("sparse", "legacy")) {
    for (product in c("a * b * c", "a * (b * c)")) {
      model = solve_from_tablo(
        c(lines, sprintf("update (product) stock = %s;", product)),
        c("a", "b", "c"), shocks, engine, input, iter = 2L, steps = 2L
      )
      expect_equal(as.numeric(model$data$stock), 171.6, tolerance = 1e-12)
    }
  }
})

test_that("header reads validate shape and align labelled dimensions", {
  lines = c(
    "set reg (r1,r2,r3);", "set goods (aa,bb);",
    "coefficient (all,r,reg)(all,g,goods) weight(r,g);",
    'read weight from file basedata header "WGHT";',
    "variable a;", "variable x;",
    "equation example x = a;"
  )
  expected = array(as.numeric(1:6), c(3L, 2L),
                   dimnames = list(reg = c("r1", "r2", "r3"),
                                   goods = c("aa", "bb")))
  permuted = expected[c(3L, 1L, 2L), c(2L, 1L)]
  invalid_labels = expected
  dimnames(invalid_labels)[[1L]][[2L]] = "unknown"
  for (engine in c("sparse", "legacy")) {
    load = function(header) {
      load_from_tablo(lines, "a", engine,
                      input = list(basedata = list(wght = header)))
    }
    expect_equal(load(permuted)$data$weight, expected)
    expect_error(load(1:3), "has 3 values, expected 6")
    expect_error(load(1:12), "has 12 values, expected 6")
    expect_error(load(t(expected)), "has dimensions 2 x 3, expected 3 x 2")
    expect_error(load(invalid_labels), "incompatible labels on dimension 1")
  }
})

test_that("TABLO assertions check derived inputs and accepted updates", {
  lines = c(
    "set reg (r1,r2);",
    "coefficient (all,r,reg) stock(r);",
    'read stock from file basedata header "STOK";',
    "coefficient (all,r,reg) checked(r);",
    "formula (initial)(all,r,reg) checked(r) = stock(r);",
    "assertion (initial) # valid starting values # (all,r,reg) checked(r) ge 0;",
    "assertion (initial) # count valid regions # sum(r,reg: stock(r) ge 0,1) = 2;",
    "variable (all,r,reg)(change) a(r);",
    "variable (all,r,reg)(change) x(r);",
    "equation example (all,r,reg) x(r) = a(r);",
    "update (change)(all,r,reg) stock(r) = x(r);"
  )
  for (engine in c("sparse", "legacy")) {
    input = function(values) list(basedata = list(stok = values))
    expect_error(load_from_tablo(lines, "a", engine, input(c(1, -1))),
                 'TABLO assertion "valid starting values" failed')
    model = load_from_tablo(
      c(lines, "assertion # valid remaining stock # (all,r,reg) stock(r) ge 0;"),
      "a", engine, input(c(1, 2))
    )
    model$setShocks(c('a["r1"]' = -2))
    expect_error(suppressMessages(model$solveModel(iter = 1, steps = 1,
                                                  engine = engine)),
                 'TABLO assertion "valid remaining stock" failed')
    expect_equal(as.numeric(model$data$stock), c(1, 2))
    expect_length(model$solution, 0L)
    initial_only = solve_from_tablo(lines, "a", c('a["r1"]' = -2),
                                    engine, input(c(1, 2)))
    expect_equal(as.numeric(initial_only$data$stock), c(-1, 2))
  }
})

test_that("equation conditions choose the correct branch and reject missing data", {
  lines = c(
    "set reg (r1,r2);",
    "coefficient (all,r,reg) weight(r);",
    'read weight from file basedata header "WGHT";',
    "variable (all,r,reg) a(r);",
    "variable (all,r,reg) x(r);",
    "equation example (all,r,reg) x(r) = IF(weight(r) gt 0, a(r), 2 * a(r));"
  )
  shocks = c('a["r1"]' = 4, 'a["r2"]' = 4)
  for (engine in c("sparse", "legacy")) {
    for (vectorized in c(TRUE, FALSE)) {
      withr::local_options(list(GEModelR.sparse.vectorized = vectorized))
      input = function(values) list(basedata = list(wght = values))
      model = solve_from_tablo(lines, "a", shocks, engine, input(c(1, -1)))
      expect_equal(model$solution, c('x["r1"]' = 4, 'x["r2"]' = 8))
      expect_error(solve_from_tablo(lines, "a", shocks, engine, input(c(1, NA))),
                   "Equation example has an indeterminate condition")
    }
  }
})
