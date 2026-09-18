test_that("current sparse state preserves exact double leaves", {
  model = make_three_region_model("sparse")
  state_file = tempfile(fileext = ".rds")
  on.exit(unlink(state_file), add = TRUE)

  model$saveState(state_file)
  payload = readRDS(state_file)
  expect_true(is.double(payload$levels$basedata$stock))

  restored = GEModel$new()
  returned = restored$loadState(state_file)

  expect_identical(returned, restored)
  expect_identical(restored$loadedEngine, "sparse")
  restored_levels = sparse_state_data(restored$sparseState)
  expect_true(is.double(restored_levels$basedata$stock))
  expect_identical(
    dimnames(restored_levels$basedata$stock),
    dimnames(payload$levels$basedata$stock)
  )
})

test_that("logical-for-double sparse state is rejected before receiver mutation", {
  model = make_three_region_model("sparse")
  state_file = tempfile(fileext = ".rds")
  bad_file = tempfile(fileext = ".rds")
  on.exit(unlink(c(state_file, bad_file)), add = TRUE)

  model$saveState(state_file)
  payload = readRDS(state_file)
  stock = payload$levels$basedata$stock
  expect_true(is.double(stock))
  payload$levels$basedata$stock = array(
    as.logical(stock), dim = dim(stock), dimnames = dimnames(stock)
  )
  writeSerializationPayload(payload, bad_file)

  receiver = GEModel$new()
  receiver$closure = "receiver-sentinel"
  receiver$memoryBudget = 4096
  before = serialize(
    serializationReceiverSnapshot(receiver), NULL, version = 3L
  )

  expect_error(
    receiver$loadState(bad_file),
    "levels\\$basedata\\$stock type does not match"
  )
  after = serialize(
    serializationReceiverSnapshot(receiver), NULL, version = 3L
  )
  expect_identical(after, before)
})
