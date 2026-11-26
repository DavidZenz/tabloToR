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

test_that("zero right-hand sides still require a nonsingular closure", {
  variables = c("variable (change) a;", "variable (change) b;",
                "variable (change) x;", "variable (change) y;")
  singular = c(variables, "equation first x + y = a + b;",
               "equation second 2 * x + 2 * y = 2 * a + 2 * b;")
  identified = c(variables, "equation first x = a + b;",
                 "equation second y = 2 * a + 2 * b;")
  for (engine in c("sparse", "legacy")) {
    for (offset in c(0, 1)) {
      shocks = c("a[]" = offset, "b[]" = -offset)
      expect_error(solve_from_tablo(singular, c("a", "b"), shocks, engine),
                   "singular|factorization")
      model = solve_from_tablo(identified, c("a", "b"), shocks, engine)
      expect_equal(model$solution, c("x[]" = 0, "y[]" = 0))
    }
  }
})

test_that("optional reads do not change the timing of ordinary formulas", {
  base = c("coefficient stock;", "formula (initial) stock = 2;")
  equations = c("variable (change) a;", "variable (change) x;",
                'equation outcome x = weight("north") * a;',
                "update (change) stock = a;")
  lines = c("set reg (north,south);", base,
            "coefficient (all,r,reg) weight(r);",
            'formula (initial) weight("south") = 3;',
            'formula weight("north") = stock;',
            'read (ifheaderexists) weight("south") from file basedata header "WGHT";',
            equations)
  for (engine in c("sparse", "legacy")) {
    for (present in c(FALSE, TRUE)) {
      input = list(basedata = if (present) list(wght = 8) else list())
      model = solve_from_tablo(lines, "a", c("a[]" = 4), engine, input, steps = 2L)
      expect_equal(model$solution, c("x[]" = 12))
      expect_equal(as.numeric(model$data$weight), c(6, if (present) 8 else 3))
    }
    scalar = c(base, "coefficient weight;", "formula weight = stock;",
               'read (ifheaderexists) weight from file basedata header "WGHT";',
               sub('weight\\("north"\\)', "weight", equations))
    missing = solve_from_tablo(scalar, "a", c("a[]" = 4), engine,
                                list(basedata = list()), steps = 2L)
    expect_equal(missing$solution, c("x[]" = 12))
    supplied = solve_from_tablo(scalar, "a", c("a[]" = 4), engine,
                                 list(basedata = list(wght = 7)), steps = 2L)
    expect_equal(supplied$solution, c("x[]" = 28))
  }
})

test_that("integer coefficient formulas default to INITIAL", {
  lines = c("coefficient stock;", "formula (initial) stock = 2;",
            "coefficient (integer) count;", "formula (default = always);",
            "formula count = stock;", "coefficient refreshed;",
            "formula refreshed = stock;", "variable (change) a;",
            "variable (change) x;", "equation outcome x = count * a;",
            "update (change) stock = a;")
  for (engine in c("sparse", "legacy")) {
    model = solve_from_tablo(lines, "a", c("a[]" = 4), engine, steps = 2L)
    expect_equal(model$solution, c("x[]" = 8))
    expect_equal(model$data$count, 2)
    expect_equal(model$data$refreshed, 6)
  }
})

test_that("shock selectors must match the variable's declared indices", {
  scalar = c("variable (change) a;", "variable (change) x;",
             "equation outcome x = a;")
  indexed = c("set reg (north,south);", "variable (change)(all,r,reg) a(r);",
              "variable (change)(all,r,reg) x(r);",
              "equation outcome (all,r,reg) x(r) = a(r);")
  for (engine in c("sparse", "legacy")) {
    for (label in c('a["south"]', "a[1]", "a[,]")) {
      expect_error(solve_from_tablo(scalar, "a", setNames(5, label), engine),
                   "shock label|expects 0 indices")
    }
    for (label in c("a[south,]", "a[,south]", 'a["2"]', "a[1.9]")) {
      expect_error(solve_from_tablo(indexed, "a", setNames(5, label), engine),
                   "shock label|Cannot resolve index")
    }
    valid = solve_from_tablo(indexed, "a", c('a["south"]' = 5), engine)
    expect_equal(valid$solution, c('x["north"]' = 0, 'x["south"]' = 5))
  }
  positional = solve_from_tablo(indexed, "a", c("a[2]" = 5))
  expect_equal(positional$solution, c('x["north"]' = 0, 'x["south"]' = 5))
})

test_that("malformed equations and product updates cannot produce a solution", {
  lines = c("set reg (north,south);", "coefficient (all,r,reg) weight(r);",
            'read weight from file basedata header "WGHT";',
            "coefficient stock;", "formula (initial) stock = 100;",
            "variable a;", "variable (change) b;", "variable x;")
  for (equation in c("equation outcome x = weight * a;",
                     'equation outcome x = a("north");')) {
    expect_error(load_from_tablo(c(lines, equation), "a"),
                 "Equation outcome: .* expects [01] indices")
  }
  for (product in c("a * 2", 'a * weight("north")', "a + a", "a * b")) {
    model = c(lines, 'equation outcome x = weight("north") * a;',
              sprintf("update (product) stock = %s;", product))
    expect_error(load_from_tablo(model, "a"),
                 "UPDATE \\(PRODUCT\\) requires percentage-change variable factors")
  }
})

test_that("loaded formula and read order governs every first Euler step", {
  for (engine in c("sparse", "legacy")) {
    for (later in c('read weight from file basedata header "WGHT";',
                    "formula (initial) weight = 2;")) {
      lines = c(
        "coefficient weight;", "formula (always) weight = 5;", later,
        "assertion (always) # weight at this point # weight eq 2;",
        "variable (change) a;", "variable (change) x;",
        "equation outcome x = weight * a;"
      )
      model = solve_from_tablo(lines, "a", c("a[]" = 3), engine,
                               input = list(basedata = list(wght = 2)),
                               iter = 2L, steps = c(1L, 3L))
      expect_equal(model$solution, c("x[]" = 6))
      expect_equal(model$data$weight, 2)
    }
  }
})

test_that("later partial reads pick up updated values from the same slice", {
  lines = c(
    "set reg (north,south);", "coefficient (all,r,reg) stock(r);",
    "formula (always)(all,r,reg) stock(r) = 5;",
    'read stock("north") from file basedata header "STOK";',
    "variable (change) a;", "variable (change) x;",
    'equation outcome x = stock("north") * a;',
    'update (change) stock("north") = a;'
  )
  for (engine in c("sparse", "legacy")) {
    model = solve_from_tablo(lines, "a", c("a[]" = 4), engine,
                             input = list(basedata = list(stok = 2)), steps = 2L)
    expect_equal(model$solution, c("x[]" = 12))
    expect_equal(as.numeric(model$data$stock), c(6, 5))
  }
})

test_that("PostSim never replays ordinary formulas used in the solve", {
  lines = c(
    "coefficient weight;", "formula (initial) weight = 2;",
    "formula (always) weight = weight + 1;",
    "variable (change) a;", "variable (change) x;",
    "equation outcome x = weight * a;"
  )
  for (engine in c("sparse", "legacy")) {
    for (postsim in c(FALSE, TRUE)) {
      model = load_from_tablo(lines, "a", engine)
      model$setShocks(c("a[]" = 1))
      suppressMessages(model$solveModel(iter = 1, steps = 1, engine = engine,
                                        postsim = postsim))
      expect_equal(model$solution, c("x[]" = 3))
      suppressMessages(model$solveModel(iter = 1, steps = 1, engine = engine,
                                        postsim = FALSE))
      expect_equal(model$solution, c("x[]" = 5))
    }
  }
})

test_that("missing set members and non-finite shocks fail before a solve", {
  lines = c(
    'set reg read elements from file basedata header "REGS";',
    "variable (change) a;", "variable (change)(all,r,reg) x(r);",
    "equation outcome (all,r,reg) x(r) = a;"
  )
  for (engine in c("sparse", "legacy")) {
    for (missing in c(NA_character_, "", "  ")) {
      input = list(basedata = list(regs = c("north", missing, "south")))
      expect_error(load_from_tablo(lines, "a", engine, input),
                   "SET reg has missing or blank members")
    }
    model = load_from_tablo(lines, "a", engine,
                            list(basedata = list(regs = c("north", "south"))))
    model$setShocks(c("a[]" = 7))
    expect_error(model$setShocks(setNames(c(Inf, -Inf, 7), rep("a[]", 3L))),
                 "Shock values must be finite")
    expect_error(model$setShocks(setNames(c(1e308, 1e308), rep("a[]", 2L))),
                 "Combined shock values must be finite")
    expect_identical(model$shocks, c("a[]" = 7))
    suppressMessages(model$solveModel(iter = 1, steps = 1, engine = engine))
    expect_equal(model$solution, c('x["north"]' = 7, 'x["south"]' = 7))
  }
})

test_that("explicit PERCENT_CHANGE variables compound like the default", {
  for (engine in c("sparse", "legacy")) {
    for (qualifier in c("", "(percent_change)")) {
      lines = c(
        "coefficient stock;", "formula (initial) stock = 100;",
        paste("variable", qualifier, "a;"), paste("variable", qualifier, "x;"),
        "equation outcome x = 2 * a;", "update (product) stock = a;"
      )
      model = solve_from_tablo(lines, "a", c("a[]" = 20), engine, steps = 2L)
      expect_equal(model$data$stock, 120)
      expect_equal(model$solution, c("x[]" = 460 / 11))
    }
  }
})

test_that("index equality compares labels across different sets", {
  lines = c(
    "set parent (xx,aa,bb);", "set child (aa,bb);",
    "subset child is subset of parent;",
    'assertion (initial) # label in a sum # sum(i,parent: "bb" eq i,1) eq 1;',
    "variable (change)(all,j,child) a(j);",
    "variable (change)(all,i,parent) x(i);",
    "variable (change)(all,i,parent) y(i);",
    "variable (change)(all,j,child) z(j);",
    "equation match (all,i,parent) x(i) = sum(j,child: i eq j,a(j));",
    "equation other (all,i,parent) y(i) = sum(j,child: i ne j,a(j));",
    'equation quoted (all,j,child) z(j) = IF(j eq "bb", a(j));'
  )
  expected = c('x["xx"]' = 0, 'x["aa"]' = 11, 'x["bb"]' = 7,
               'y["xx"]' = 18, 'y["aa"]' = 7, 'y["bb"]' = 11,
               'z["aa"]' = 0, 'z["bb"]' = 7)
  for (engine in c("sparse", "legacy")) {
    for (vectorized in if (engine == "sparse") c(FALSE, TRUE) else TRUE) {
      withr::local_options(list(GEModelR.sparse.vectorized = vectorized))
      model = solve_from_tablo(lines, "a", c('a["aa"]' = 11, 'a["bb"]' = 7),
                               engine)
      expect_equal(model$solution[names(expected)], expected)
    }
  }
})

test_that("ordinary assertions run between formulas on each simulation pass", {
  lines = c(
    "coefficient stock;", "formula (initial) stock = 10;",
    "coefficient observed;", "formula (always) observed = stock;",
    "assertion (always) # positive stock at this point # observed gt 0;",
    "formula (always) observed = -1;",
    "variable (change) a;", "variable (change) x;", "equation outcome x = a;",
    "update (change) stock = a;"
  )
  for (engine in c("sparse", "legacy")) {
    model = solve_from_tablo(lines, "a", c("a[]" = 1), engine, steps = c(1L, 2L))
    expect_equal(model$data$stock, 11)
    expect_equal(model$data$observed, -1)
    expect_error(solve_from_tablo(lines, "a", c("a[]" = -11), engine),
                 'assertion "positive stock at this point" failed')
  }
})

test_that("named singleton labels are checked when HAR dimensions collapse", {
  lines = c(
    "set yr (y2021);", "set reg (north,south);",
    "coefficient (all,y,yr)(all,r,reg) stock(y,r);",
    'read stock from file basedata header "STOK";',
    "variable (change) a;", "variable (change) x;",
    'equation outcome x = stock("y2021","north") * a;'
  )
  header = function(value) list(basedata = list(stok = value))
  positional = array(c(100, 200), c(2L, 1L))
  labeled = array(c(100, 200), c(2L, 1L),
                  list(reg = c("north", "south"), yr = "y2021"))
  padded = array(c(100, 200), c(1L, 2L, 1L),
                 list(padding = NULL, reg = c("north", "south"), yr = "y2021"))
  for (engine in c("sparse", "legacy")) {
    for (values in list(positional, labeled, padded)) {
      model = solve_from_tablo(lines, "a", c("a[]" = 1), engine, header(values))
      expect_equal(model$solution, c("x[]" = 100))
    }
    for (values in list(labeled, padded)) {
      dimnames(values)$yr = "y2020"
      expect_error(load_from_tablo(lines, "a", engine, header(values)),
                   "incompatible labels on dimension 1")
    }
  }
})

test_that("Euler extrapolation preserves small final coefficient levels", {
  lines = c(
    "coefficient stock;", "formula (initial) stock = 1e16;",
    "variable (change) a;", "variable (change) x;", "equation outcome x = a;",
    "update (explicit) stock = 1;"
  )
  for (engine in c("sparse", "legacy")) {
    for (steps in list(1L, 2L, c(1L, 2L), c(1L, 2L, 4L))) {
      model = solve_from_tablo(lines, "a", c("a[]" = 1), engine, steps = steps)
      expect_identical(model$data$stock, 1)
    }
  }
})

test_that("set positions use the bound or explicitly named set", {
  lines = c(
    "set parent (p1,p2,p3);", "set child (p2,p3);", "set other (p3,p2);",
    "subset child is subset of parent;",
    "set active = (all,c,child: $pos(c,parent) gt 2);",
    "coefficient (all,c,child)(all,j,other) rank(c,j);",
    "formula (initial) (all,c,child)(all,j,other) rank(c,j) = $pos(c);",
    "variable (change) a;", "variable (change)(all,c,child) x(c);",
    "variable (change)(all,c,active) y(c);",
    paste0('equation positions (all,c,child) x(c) = 10 * rank(c,"p3") * a',
           ' + $pos(c,parent) * a + $pos("p2",parent) * a;'),
    "equation selection (all,c,active) y(c) = $pos(c) * a;"
  )
  for (engine in c("sparse", "legacy")) {
    for (vectorized in if (engine == "sparse") c(FALSE, TRUE) else TRUE) {
      withr::local_options(list(GEModelR.sparse.vectorized = vectorized))
      model = solve_from_tablo(lines, "a", c("a[]" = 1), engine)
      expect_identical(model$data$active, "p3")
      expected = c('x["p2"]' = 14, 'x["p3"]' = 25, 'y["p3"]' = 1)
      expect_equal(model$solution[names(expected)], expected)
    }
  }
})

test_that("initial formula defaults and reordered qualifiers survive updates", {
  initial = list(
    c("formula (default = initial);", "formula stock = 100;"),
    'formula (initial, write updated value to file basedata header "STOK") stock = 100;',
    'formula (write updated value to file basedata header "STOK", initial) stock = 100;'
  )
  for (engine in c("sparse", "legacy")) {
    for (directives in initial) {
      lines = c(
        "file (new, for_updates) basedata;", "coefficient stock;", directives,
        "coefficient refreshed;", "formula (always) refreshed = stock;",
        "variable (change) a;", "variable (change) x;",
        "equation outcome x = a;", "update (change) stock = a;"
      )
      model = solve_from_tablo(lines, "a", c("a[]" = 10), engine,
                               steps = c(1L, 2L))
      expect_equal(model$data$stock, 110)
      expect_equal(model$data$refreshed, 110)
    }
  }
})

test_that("sets read from headers reject duplicate members", {
  lines = c(
    'set reg read elements from file basedata header "REGS";',
    "variable (change)(all,r,reg) a(r);", "variable (change)(all,r,reg) x(r);",
    "equation outcome (all,r,reg) x(r) = a(r);"
  )
  for (engine in c("sparse", "legacy")) {
    for (duplicate in c("north", "NORTH")) {
      expect_error(
        load_from_tablo(lines, "a", engine, list(basedata = list(
          regs = c("north", duplicate, "south")
        ))),
        "SET reg has duplicate members: north"
      )
    }
    valid = list(basedata = list(regs = c("north", "south")))
    model = solve_from_tablo(lines, "a", c('a["north"]' = 5), engine, valid)
    expect_equal(model$solution, c('x["north"]' = 5, 'x["south"]' = 0))
  }
})

test_that("PostSim runs reads, sets and formulas in order on final levels", {
  lines = c(
    "set reg (north,south);", "coefficient (all,r,reg) stock(r);",
    'read stock from file basedata header "STOK";',
    "variable (change)(all,r,reg) a(r);", "variable (change)(all,r,reg) x(r);",
    "equation outcome (all,r,reg) x(r) = a(r);",
    "update (change)(all,r,reg) stock(r) = a(r);",
    "postsim (begin);", "file (old) reportfile;", "coefficient cutoff;",
    'read cutoff from file reportfile header "CUT";',
    "set winners = (all,r,reg: stock(r) gt cutoff);",
    "coefficient (all,w,winners) report(w);",
    "formula (all,w,winners) report(w) = stock(w);",
    "assertion (all,w,winners) report(w) gt cutoff;",
    "postsim (end);"
  )
  input = list(basedata = list(stok = c(5, 12)))
  for (engine in c("sparse", "legacy")) {
    model = load_from_tablo(lines, "a", engine, input)
    expect_null(model$data$winners)
    model$setShocks(c('a["north"]' = 10))
    suppressMessages(model$solveModel(iter = 1, steps = 1, engine = engine,
                                      postsim = FALSE))
    expect_equal(model$solution, c('x["north"]' = 10, 'x["south"]' = 0))
    expect_null(model$data$report)

    model = load_from_tablo(lines, "a", engine,
                            c(input, list(reportfile = list(cut = 10))))
    model$setShocks(c('a["north"]' = 10))
    if (engine == "sparse") {
      model$solveModel(iter = 1, steps = 1, engine = engine, output = "compact",
                       variables = "report", dimensions = list(winners = "north"))
      expect_equal(as.numeric(model$compactOutput$report), 15)
      expect_identical(dimnames(model$compactOutput$report)$winners, "north")
    } else {
      suppressMessages(model$solveModel(iter = 1, steps = 1, engine = engine))
    }
    expect_identical(model$data$winners, c("north", "south"))
    expect_equal(as.numeric(model$data$report), c(15, 12))
    saved = withr::local_tempfile()
    model$saveState(saved)
    restored = GEModel$new()
    restored$loadState(saved)
    expect_identical(restored$data$report, model$data$report)
    expect_identical(restored$compactOutput, model$compactOutput)
  }
})

test_that("checkpoints after a closure change retain numerical levels", {
  lines = c(
    "variable (change) a;", "variable (change) x;", "equation outcome x = a;"
  )
  for (engine in c("sparse", "legacy")) {
    model = solve_from_tablo(lines, "a", c("a[]" = 4), engine)
    model$setClosure("x")
    expect_length(model$solution, 0)
    saved = withr::local_tempfile()
    model$saveState(saved)
    restored = GEModel$new()
    restored$loadState(saved)
    expect_identical(restored$closure, "x")
    expect_equal(restored$data$a, 4)
    expect_equal(restored$data$x, 4)
    expect_length(restored$explicitShocks$labels, 0)
    restored$setShocks(c("x[]" = 3))
    suppressMessages(restored$solveModel(iter = 1, steps = 1, engine = engine))
    expect_equal(restored$solution, c("a[]" = 3))
  }
})

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

test_that("product updates linearize all factors within each substep", {
  lines = c(
    "coefficient stock;",
    'read stock from file basedata header "STOK";',
    "variable a;", "variable b;", "variable c;", "variable x;",
    "equation example x = stock * a;"
  )
  input = list(basedata = list(stok = 100))
  closure = c("a", "b", "c")
  shocks = c("a[]" = 10, "b[]" = 20, "c[]" = 30)
  for (engine in c("sparse", "legacy")) {
    for (product in c("a * b * c", "a * (b * c)")) {
      model_lines = c(lines, sprintf("update (product) stock = %s;", product))
      model = solve_from_tablo(model_lines, closure, shocks, engine, input)
      expect_equal(as.numeric(model$data$stock), 160, tolerance = 1e-12)
      two_steps = solve_from_tablo(model_lines, closure, shocks, engine, input,
                                   steps = 2L)
      first = unname(shocks) / 2
      second = first / (1 + first / 100)
      expected = 100 * (1 + sum(first) / 100) * (1 + sum(second) / 100)
      expect_equal(as.numeric(two_steps$data$stock), expected)

      model = solve_from_tablo(model_lines, closure, shocks, engine, input,
                                iter = 2L, steps = 2L)
      reference = solve_from_tablo(
        c(lines, "update (change) stock = (stock / 100) * (a + b + c);"),
        closure, shocks, engine, input, iter = 2L, steps = 2L
      )
      expect_equal(model$data$stock, reference$data$stock)
      expect_equal(model$solution, reference$solution)
    }
  }
})

test_that("coefficient updates share formula values and stage disjoint writes", {
  lines = c(
    "set reg (r1,r2);",
    "coefficient first;",
    "formula (initial) first = 2;",
    "coefficient (all,r,reg) second(r);",
    "formula (initial)(all,r,reg) second(r) = 100;",
    "coefficient factor;",
    "variable (change) shock;", "variable (change) outcome;",
    "equation example outcome = factor * shock;"
  )
  updates = c(
    "update (change) first = shock;",
    'update (change) second("r1") = first * shock;',
    'update (change) second("r2") = factor * shock;'
  )
  for (engine in c("sparse", "legacy")) {
    for (order in list(updates, rev(updates))) {
      model_lines = c(lines, order, "formula (always) factor = 2 * first;")
      model = solve_from_tablo(model_lines, "shock", c("shock[]" = 10), engine)
      expect_equal(model$data$first, 12)
      expect_equal(as.numeric(model$data$second), c(120, 140))
      model = solve_from_tablo(model_lines, "shock", c("shock[]" = 10), engine,
                                steps = 2L)
      expect_equal(model$solution, c("outcome[]" = 90))
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

test_that("equal-sized HAR axes retain distinct set identities", {
  lines = c(
    "set origin (north,south);", "set destination (north,south);",
    "coefficient (all,o,origin)(all,d,destination) weight(o,d);",
    'read weight from file basedata header "WGHT";',
    "variable a;", "variable x;",
    'equation example x = weight("north","south") * a;'
  )
  header = matrix(c(2, 3, 5, 7), nrow = 2L,
                  dimnames = list(origin = c("north", "south"),
                                  destination = c("north", "south")))
  for (engine in c("sparse", "legacy")) {
    solve = function(weight) solve_from_tablo(
      lines, "a", c("a[]" = 4), engine,
      input = list(basedata = list(wght = weight))
    )
    expect_equal(solve(header)$solution, c("x[]" = 20))
    expect_equal(solve(unname(header))$solution, c("x[]" = 20))
    expect_error(solve(t(header)), "named dimensions in the wrong order")
  }
})

test_that("partial reads and initialization formulas execute in TABLO order", {
  lines = c(
    "set reg (r1,r2,r3);", "set active (r2,r3);", "set market (home,world);",
    "coefficient (all,r,reg)(all,m,market) weight(r,m);",
    "formula (initial)(all,r,reg)(all,m,market) weight(r,m) = 2;",
    "coefficient before;",
    'formula (initial) before = weight("r2","home");',
    'read (all,r,active) weight(r,"home") from file basedata header "WGHT";',
    'read (ifheaderexists) weight("r1","world") from file basedata header "OPTN";',
    "coefficient after;",
    'formula (initial) after = weight("r2","home");',
    "coefficient threshold;",
    "formula (initial) threshold = 1;",
    'read threshold from file basedata header "LIMT";',
    "variable a;", "variable x;",
    'equation example x = (before + after + threshold + weight("r1","world")) * a;'
  )
  header = array(c(7, 5), dim = 2L,
                 dimnames = list(active = c("r3", "r2")))
  for (engine in c("sparse", "legacy")) {
    for (present in c(TRUE, FALSE)) {
      basedata = list(wght = header, limt = 9)
      if (present) basedata$optn = 11
      model = solve_from_tablo(lines, "a", c("a[]" = 4), engine,
                                input = list(basedata = basedata))
      expect_equal(model$data$before, 2)
      expect_equal(model$data$after, 5)
      expect_equal(as.numeric(model$data$weight[, "home"]), c(2, 5, 7))
      expected = if (present) 11 else 2
      expect_equal(as.numeric(model$data$weight[, "world"]), c(expected, 2, 2))
      expect_equal(model$solution, c("x[]" = (2 + 5 + 9 + expected) * 4))
    }
    expect_error(
      load_from_tablo(lines, "a", engine,
                      input = list(basedata = list(wght = 1, limt = 9))),
      "READ weight.*has 1 values, expected 2"
    )
  }
})

test_that("undefined names fail in assertions and conditioned equations", {
  inputs = c(
    "set reg (r1,r2);", "set active (r2);",
    "coefficient (all,r,reg) weight(r);",
    "formula (initial)(all,r,reg) weight(r) = 2;",
    "variable (all,r,reg) a(r);", "variable (all,r,reg) x(r);"
  )
  equation = paste("equation example (all,r,reg)",
                   'x(r) = IF(r in active, weight("r1") * a(r), a(r));')
  bad_equation = paste("equation example (all,r,reg)",
                       "x(r) = IF(thresholdd gt 0, a(r), 2 * a(r));")
  shocks = c('a["r1"]' = 4, 'a["r2"]' = 4)
  for (engine in c("sparse", "legacy")) {
    for (vectorized in c(FALSE, TRUE)) {
      withr::local_options(list(GEModelR.sparse.vectorized = vectorized))
      model = solve_from_tablo(
        c(inputs, 'assertion (initial) weight("r1") ge 0;', equation),
        "a", shocks, engine
      )
      expect_equal(model$solution, c('x["r1"]' = 4, 'x["r2"]' = 8))
      expect_error(
        load_from_tablo(c(inputs, "assertion (initial) thresholdd gt 0;",
                          equation), "a", engine),
        "Undefined TABLO name 'thresholdd'"
      )
      expect_error(solve_from_tablo(c(inputs, bad_equation), "a", shocks, engine),
                   "thresholdd")
    }
  }
})

test_that("ZERODIVIDE defaults follow formula scope and type", {
  lines = c(
    "coefficient denominator;", "formula (initial) denominator = 0;",
    "coefficient replacement;", "formula (initial) replacement = 5;",
    "coefficient builtin;", "formula (initial) builtin = 0 / denominator;",
    "zerodivide (nonzero_by_zero) default replacement;",
    "zerodivide default 7;",
    "coefficient share;",
    "formula share = 1 / denominator + 0 / denominator;",
    "zerodivide (nonzero_by_zero) off;", "zerodivide off;",
    "coefficient guarded;",
    "formula guarded = IF(denominator gt 0, 1 / denominator, 2);",
    "variable a;", "variable x;",
    "equation example x = (share + builtin + guarded) * a;",
    "zerodivide default 9;",
    "postsim (begin);",
    "coefficient post;",
    "formula post = 0 / denominator;",
    "postsim (end);", "zerodivide off;"
  )
  for (engine in c("sparse", "legacy")) {
    model = solve_from_tablo(lines, "a", c("a[]" = 4), engine)
    expect_equal(model$solution, c("x[]" = 56))
    expect_equal(model$data$post, 0)
    for (numerator in c(0, 1)) {
      expect_error(
        load_from_tablo(c(
          lines, "coefficient forbidden;",
          sprintf("formula (initial) forbidden = %s / denominator;", numerator)
        ), "a", engine),
        "TABLO division by zero"
      )
    }
  }
})

test_that("division by zero is an error in active equations and updates", {
  lines = c(
    "set reg (r1,r2);",
    "coefficient (all,r,reg) denominator(r);",
    'read denominator from file basedata header "DENM";',
    "coefficient stock;", "formula (initial) stock = 100;",
    "zerodivide default 9;", "zerodivide (nonzero_by_zero) default 8;",
    "variable (all,r,reg) a(r);", "variable (all,r,reg) x(r);"
  )
  equation = "equation example (all,r,reg) x(r) = a(r) / denominator(r);"
  guarded = paste("equation example (all,r,reg) x(r) =",
                  "IF(denominator(r) ne 0, a(r) / denominator(r), a(r));")
  input = list(basedata = list(denm = c(0, 2)))
  shocks = c('a["r1"]' = 4, 'a["r2"]' = 4)
  for (engine in c("sparse", "legacy")) {
    for (vectorized in c(FALSE, TRUE)) {
      withr::local_options(list(GEModelR.sparse.vectorized = vectorized))
      expect_error(
        solve_from_tablo(c(lines, equation), "a", shocks, engine, input),
        "TABLO division by zero"
      )
      model = solve_from_tablo(c(lines, guarded), "a", shocks, engine, input)
      expect_equal(model$solution, c('x["r1"]' = 4, 'x["r2"]' = 2))
      failing = load_from_tablo(
        c(lines, guarded, 'update (change) stock = a("r1") / denominator("r1");'),
        "a", engine, input
      )
      failing$setShocks(shocks)
      expect_error(
        suppressMessages(failing$solveModel(engine = engine, iter = 1, steps = 1)),
        "TABLO division by zero"
      )
      expect_equal(failing$data$stock, 100)
      expect_length(failing$solution, 0L)
    }
  }
})

test_that("sparse coefficient references align subset labels with parent axes", {
  lines = c(
    "set reg (north,south,east);", "set active (south,east);",
    "subset active is subset of reg;",
    "coefficient (all,r,reg) weight(r);",
    'read weight from file basedata header "WGHT";',
    "variable a;", "variable (all,r,active) x(r);",
    "equation outcome (all,r,active) x(r) = weight(r) * a;"
  )
  input = list(basedata = list(wght = c(10, 20, 30)))
  expected = c('x["south"]' = 80, 'x["east"]' = 120)
  for (vectorized in c(FALSE, TRUE)) {
    withr::local_options(list(GEModelR.sparse.vectorized = vectorized))
    sparse = solve_from_tablo(lines, "a", c("a[]" = 4), input = input)
    expect_equal(sparse$solution, expected)
  }
  legacy = solve_from_tablo(lines, "a", c("a[]" = 4), "legacy", input)
  expect_equal(legacy$solution, expected)
})

test_that("Euler extrapolation retains updated coefficients across subintervals", {
  lines = c(
    "coefficient first;", "formula (initial) first = 2;",
    "coefficient second;", "formula (initial) second = 100;",
    "variable (change) a;", "variable (change) x;",
    "equation outcome x = a;",
    "update (change) first = a;", "update (change) second = first * a;"
  )
  for (engine in c("sparse", "legacy")) {
    for (iter in c(1L, 2L)) {
      model = solve_from_tablo(lines, "a", c("a[]" = 10), engine,
                                iter = iter, steps = c(1L, 2L))
      expect_equal(model$solution, c("x[]" = 10))
      expect_equal(model$data$first, 12)
      expect_equal(model$data$second, 170)
    }
  }
})

test_that("three Euler counts extrapolate the solution and updated data", {
  lines = c(
    "coefficient stock;", "formula (initial) stock = 1;",
    "variable (change) a;", "variable (change) x;",
    "equation outcome x = stock * a;", "update (change) stock = x;"
  )
  steps = c(1, 2, 4)
  by_count = (1 + 1 / steps) ^ steps - 1
  expected = sum(c(1 / 3, -2, 8 / 3) * by_count)
  for (engine in c("sparse", "legacy")) {
    for (order in list(steps, rev(steps))) {
      model = solve_from_tablo(lines, "a", c("a[]" = 1), engine, steps = order)
      expect_equal(model$solution, c("x[]" = expected), tolerance = 1e-12)
      expect_equal(model$data$stock, 1 + expected, tolerance = 1e-12)
    }
  }
})

test_that("explicit updates assign the calculated level", {
  lines = c(
    "coefficient stock;", "formula (initial) stock = 100;",
    "variable (change) a;", "variable (change) x;",
    "equation outcome x = a;", "update (explicit) stock = stock + a;"
  )
  for (engine in c("sparse", "legacy")) {
    model = solve_from_tablo(lines, "a", c("a[]" = 10), engine, steps = 2L)
    expect_equal(model$data$stock, 110)
  }
})

test_that("SET ranges expand and header lookup requires the exact name", {
  lines = c(
    "variable a;", "variable (all,r,reg) x(r);",
    "equation outcome (all,r,reg) x(r) = a;"
  )
  expected = c("r01", "r02", "r03", "other")
  for (engine in c("sparse", "legacy")) {
    model = solve_from_tablo(c("set reg (r01-r03,other);", lines),
                            "a", c("a[]" = 4), engine)
    expect_identical(model$data$reg, expected)
    expect_equal(model$solution, setNames(rep(4, 4), sprintf('x["%s"]', expected)))

    for (limit in c("", "maximum size 4 ")) {
      read = sprintf('set reg %sread elements from file basedata header "REGS";',
                     limit)
      expect_error(
        load_from_tablo(c(read, lines), "a", engine,
                        list(basedata = list(regs_backup = expected))),
        'SET reg from file basedata header "regs" is missing'
      )
      model = load_from_tablo(c(read, lines), "a", engine,
                             list(basedata = list(regs = expected)))
      expect_identical(model$data$reg, expected)
    }
  }
})

test_that("a recognizable HAR axis must appear in its declared position", {
  lines = c(
    "set origin (north,south);", "set destination (north,south);",
    "coefficient (all,o,origin)(all,d,destination) weight(o,d);",
    'read weight from file basedata header "WGHT";',
    "variable a;", "variable x;",
    'equation outcome x = weight("north","south") * a;'
  )
  header = matrix(c(2, 3, 5, 7), nrow = 2L,
                  dimnames = list(origin = c("north", "south"),
                                  destination = c("north", "south")))
  swapped = t(header)
  names(dimnames(swapped))[2L] = ""
  names(dimnames(header))[1L] = ""
  for (engine in c("sparse", "legacy")) {
    model = solve_from_tablo(lines, "a", c("a[]" = 4), engine,
                            list(basedata = list(wght = header)))
    expect_equal(model$solution, c("x[]" = 20))
    expect_error(
      load_from_tablo(lines, "a", engine, list(basedata = list(wght = swapped))),
      "named dimensions in the wrong order"
    )
  }
})

test_that("initial assertions run in source order and before a new simulation", {
  equation = c("variable (change) a;", "variable (change) x;",
               "equation outcome x = a;", "update (change) stock = a;")
  before = c("coefficient stock;", "formula (initial) stock = 1;",
             "assertion (initial) # positive stock # stock gt 0;")
  passing = c(before, "formula (initial) stock = -1;", equation)
  failing = c(before[1L], "formula (initial) stock = -1;",
              before[3L], "formula (initial) stock = 1;", equation)
  for (engine in c("sparse", "legacy")) {
    expect_error(load_from_tablo(failing, "a", engine), 'assertion "positive stock"')
    model = solve_from_tablo(passing, "a", c("a[]" = -1), engine)
    expect_equal(model$data$stock, -2)
    saved = withr::local_tempfile()
    model$saveState(saved)
    restored = GEModel$new()
    restored$loadState(saved)
    restored$setShocks(c("a[]" = 3))
    expect_error(
      suppressMessages(restored$solveModel(iter = 1, steps = 1, engine = engine)),
      'assertion "positive stock"'
    )

    model$setClosure("a")
    model$setShocks(c("a[]" = 3))
    expect_error(suppressMessages(model$solveModel(iter = 1, steps = 1, engine = engine)),
                 'assertion "positive stock"')
    expect_equal(model$data$stock, -2)
  }
})

test_that("PostSim assertions observe final values and their source position", {
  lines = c(
    "coefficient stock;", "formula (initial) stock = 100;",
    "variable (change) a;", "variable (change) x;", "equation outcome x = a;",
    "update (change) stock = a;",
    "postsim (begin);",
    "coefficient observed;", "formula observed = stock;",
    "assertion # final stock # observed gt 100;",
    "formula observed = -1;",
    "postsim (end);"
  )
  for (engine in c("sparse", "legacy")) {
    success = solve_from_tablo(lines, "a", c("a[]" = 10), engine)
    expect_equal(success$data$observed, -1)
    expect_error(solve_from_tablo(lines, "a", c("a[]" = -10), engine),
                 'assertion "final stock"')
    skipped = load_from_tablo(lines, "a", engine)
    skipped$setShocks(c("a[]" = -10))
    suppressMessages(skipped$solveModel(iter = 1, steps = 1, engine = engine,
                                       postsim = FALSE))
    expect_equal(skipped$solution, c("x[]" = -10))
  }
})

test_that("invalid coefficient updates leave both engines at their prior state", {
  lines = c(
    "coefficient first;", "formula (initial) first = 2;",
    "coefficient stock;", "formula (initial) stock = 100;",
    "coefficient multiplier;", 'read multiplier from file basedata header "MULT";',
    "variable (change) a;", "variable (change) x;", "equation outcome x = a;",
    "update (change) first = a;", "update (change) stock = multiplier * a;"
  )
  for (engine in c("sparse", "legacy")) {
    for (multiplier in c(NA_real_, 1e308)) {
      model = load_from_tablo(lines, "a", engine,
                             list(basedata = list(mult = multiplier)))
      before = model$data
      model$setShocks(c("a[]" = 4))
      expect_error(
        suppressMessages(model$solveModel(iter = 1, steps = 1, engine = engine)),
        "UPDATE of stock produced a non-finite"
      )
      expect_identical(model$data, before)
      expect_length(model$solution, 0L)
    }
  }
})

test_that("sparse compact output refreshes ordinary formula dependencies", {
  lines = c(
    "coefficient stock;", "formula (initial) stock = 2;",
    "coefficient scaled;", "formula scaled = stock * 2;",
    "coefficient report;", "formula (always) report = scaled * 5;",
    "variable (change) a;", "variable (change) x;", "equation outcome x = a;",
    "update (change) stock = a;"
  )
  model = load_from_tablo(lines, "a")
  model$setShocks(c("a[]" = 4))
  model$solveModel(iter = 1, steps = 1, engine = "sparse", output = "compact",
                   postsim = FALSE, variables = "report")
  expect_equal(model$compactOutput$report, 60)

  saved = withr::local_tempfile()
  model$saveState(saved)
  restored = GEModel$new()
  restored$loadState(saved)
  expect_equal(restored$compactOutput$report, 60)
})
