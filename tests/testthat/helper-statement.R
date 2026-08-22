make_statement <- function(class, equation, elements = character()) {
  list(
    class = class,
    parsed = list(
      equation = equation,
      elements = elements,
      equationName = equation
    )
  )
}
