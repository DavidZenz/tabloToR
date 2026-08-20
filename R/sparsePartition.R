# Integer block labels for sparse Schur partitioning.
#
# The labels are derived from TABLO domain positions, not from character
# labels.  A zero component denotes an equation or variable that is not
# indexed by the selected set.

sparse_block_value_sequence = function(domains, index, selected_sets, n,
                                       variable = FALSE) {
  n = as.integer(n)
  if (!n || !length(domains)) return(integer(n))
  lengths = vapply(domains, function(domain) {
    length(index$sets[[domain$set]]$values)
  }, integer(1))
  values = lapply(selected_sets, function(set_name) {
    position = which(vapply(domains, function(domain) {
      identical(domain$set, set_name)
    }, logical(1)))
    if (!length(position)) return(integer(n))
    position = position[[1L]]
    before = if (position == 1L) 1 else {
      prod(lengths[seq_len(position - 1L)])
    }
    after = if (position == length(lengths)) 1 else {
      prod(lengths[(position + 1L):length(lengths)])
    }
    if (variable) {
      as.integer(rep(
        rep(seq_len(lengths[[position]]), each = before), times = after
      ))
    } else {
      as.integer(rep(
        rep(seq_len(lengths[[position]]), each = after), times = before
      ))
    }
  })
  code = numeric(n)
  multiplier = 1
  for (id in seq_along(selected_sets)) {
    code = code + values[[id]] * multiplier
    multiplier = multiplier * (
      length(index$sets[[selected_sets[[id]]]]$values) + 1
    )
  }
  as.integer(code)
}

sparse_block_binding_code = function(domains, bindings, index,
                                     selected_sets) {
  code = 0
  multiplier = 1
  for (set_name in selected_sets) {
    position = which(vapply(domains, function(domain) {
      identical(domain$set, set_name)
    }, logical(1)))
    value = if (length(position)) {
      bindings[[domains[[position[[1L]]]]$index]]
    } else 0
    code = code + as.numeric(value) * multiplier
    multiplier = multiplier * (
      length(index$sets[[set_name]]$values) + 1
    )
  }
  as.integer(code)
}

sparse_equation_block_sequence = function(equation, index, state,
                                          selected_sets) {
  domains = equation$domains
  if (!length(domains) ||
      all(vapply(domains, function(domain) {
        is.null(domain$predicate)
      }, logical(1)))) {
    return(sparse_block_value_sequence(
      domains, index, selected_sets, equation$n, variable = FALSE
    ))
  }
  groups = integer(equation$n)
  cursor = 0L
  sparse_for_each_domain(
    domains, state, index, callback = function(bindings) {
      cursor <<- cursor + 1L
      if (cursor <= equation$n) {
        groups[[cursor]] <<- sparse_block_binding_code(
          domains, bindings, index, selected_sets
        )
      }
    }
  )
  if (cursor != equation$n) {
    stop(sprintf(
      "Conditional equation %s generated %s rows; expected %s",
      equation$name, cursor, equation$n
    ), call. = FALSE)
  }
  groups
}

sparse_structured_block_partition = function(index, state, sets = NULL) {
  if (is.null(sets)) {
    sets = intersect(c("comm", "reg"), names(index$sets))
  }
  if (is.null(index$column_order) ||
      length(index$column_order) != index$endogenous_count) {
    stop("Structured sparse partition requires a complete column order",
         call. = FALSE)
  }
  sets = unique(tolower(as.character(sets)))
  sets = sets[nzchar(sets)]
  if (!length(sets) || any(!sets %in% names(index$sets))) {
    stop("Structured sparse partition received unknown index sets",
         call. = FALSE)
  }

  row_group = integer(index$equation_count)
  for (equation in index$equations) {
    rows = seq.int(equation$row_start, equation$row_end)
    row_group[rows] = sparse_equation_block_sequence(
      equation, index, state, sets
    )
  }

  variable_group = integer(index$endogenous_count)
  for (variable in index$variables) {
    if (isTRUE(variable$exogenous)) next
    positions = seq.int(variable$endo_start, length.out = variable$n)
    variable_group[positions] = sparse_block_value_sequence(
      variable$domains, index, sets, variable$n, variable = TRUE
    )
  }
  column_group = variable_group[index$column_order]
  codes = sort(unique(c(row_group, column_group)))
  row_group = as.integer(match(row_group, codes) - 1L)
  column_group = as.integer(match(column_group, codes) - 1L)
  list(
    sets = sets,
    codes = codes,
    row_group = row_group,
    column_group = column_group,
    block_count = length(codes),
    row_sizes = tabulate(row_group + 1L, nbins = length(codes)),
    column_sizes = tabulate(column_group + 1L, nbins = length(codes))
  )
}
