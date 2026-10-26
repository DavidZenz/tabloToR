test_that("formula mapping preserves symbols, constants, and ordinary calls", {
  expect_identical(sumToMap(quote(stock)), quote(stock))
  expect_identical(sumToMap(4), 4)
  ordinary = quote(2 * stock + 3)
  expect_identical(sumToMap(ordinary), ordinary)
})

test_that("formula mapping evaluates indexed and nested sums correctly", {
  regions = c("north", "south", "east")
  products = c("goods", "services")
  inputs = list2env(list(
    reg = regions,
    prod = products,
    offset = stats::setNames(c(1, -2, 3), regions),
    flow = array(1:6, dim = c(2L, 3L),
                 dimnames = list(products, regions))
  ))
  indexed = sumToMap(quote(sum(r, reg, offset[r])))
  expect_equal(eval(indexed, inputs), sum(inputs$offset), tolerance = 0)
  nested = sumToMap(quote(
    sum(r, reg, offset[r] + sum(j, prod, flow[j, r]))
  ))
  expect_equal(eval(nested, inputs), sum(inputs$offset) + sum(inputs$flow),
               tolerance = 0)
})
