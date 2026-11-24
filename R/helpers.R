loge = log
# TABLO's membership operator is also used by generated legacy formulas.
isin = function(x, set) x %in% set

.tablo_condition = function(value, context, active = TRUE) {
  logical_value = as.logical(value)
  if (anyNA(logical_value) && anyNA(logical_value[active])) {
    stop(sprintf("%s has an indeterminate condition", context), call. = FALSE)
  }
  logical_value
}

# `%loosein%` = function(a, b) {
#   return(as.logical(apply(do.call(`cbind`,as.list(Map(function(f)grepl(f,a),b))),MARGIN=1,max)))
#   #return(unlist(Map(function(f)as.logical(max(grepl(f,a))),b)))
# }

toVector = function(ar, n) {



  if (length(ar)==1){
    elementNames = c()
  } else{
    dimnames(ar) = Map(function(f)sprintf('"%s"',f), dimnames(ar))
    if (is.null(dimnames(ar))) {
      elementNames = names(ar)
    } else if(length(dimnames(ar))==1) {
      elementNames = dimnames(ar)[[1]]
    } else {
      elementNames = Reduce(function(a, f) {
        outer(a,dimnames(ar)[[f]],paste,sep=",")
      },  2:length(dimnames(ar)), dimnames(ar)[[1]])
    }

  }

  toRet = as.vector(ar)

  if(length(elementNames)==0){
    names(toRet) = sprintf('%s[]',n)
  } else {
    names(toRet) = sprintf('%s[%s]',n,as.vector(elementNames))
  }


  return(toRet)
}

