makeFirstSimulationFixture = function(directory = tempfile("gemodelr-first-simulation-")) {
  dir.create(directory, recursive = TRUE)
  tabloPath = file.path(directory, "three-region.tab")
  writeLines(
    c(
      "set reg (north,south,east);",
      "coefficient (all,r,reg) weight(r);",
      "read weight from file basedata header \"WEIGHT\";",
      "coefficient (all,r,reg) stock(r);",
      "read stock from file basedata header \"STOCK\";",
      "coefficient (all,r,reg) reported(r);",
      "formula (all,r,reg) reported(r) = stock(r);",
      "variable (all,r,reg)(change) q(r);",
      "variable (all,r,reg) tax(r);",
      "equation market (all,r,reg) q(r) = weight(r) * tax(r);",
      "update (all,r,reg)(change) stock(r) = q(r);"
    ),
    con = tabloPath,
    useBytes = TRUE
  )

  regions = c("north", "south", "east")
  inputData = list(
    basedata = list(
      weight = array(
        c(1, 1.5, 2),
        dim = 3L,
        dimnames = list(reg = regions)
      ),
      stock = array(
        c(100, 200, 300),
        dim = 3L,
        dimnames = list(reg = regions)
      )
    )
  )

  list(tabloPath = tabloPath, inputData = inputData, regions = regions)
}
