processReadStatement = function(s) {
  if (grepl(".* from file .* header \"*\"",
            s$command)) {
  if (grepl("^\\(ifheaderexists\\)", s$command, ignore.case = TRUE)) {
    words = strsplit(s$command, " ")[[1]]
    return(sprintf(
      "%s[] = %s$`%s`", words[2], words[5],
      gsub("\"", "", words[7])
    ))
  }
    words = strsplit(s$command, " ")[[1]]

    return(sprintf('%s[] = %s$`%s`', words[1], words[4], gsub("\"", "", words[6])))
  }

}
