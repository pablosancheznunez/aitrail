new_project <- function() {
  p <- tempfile("aitrail-test-")
  ait_init(p, title = "Test project")
  p
}

# A fake web service: maps URL patterns to recorded responses.
fake_fetch <- function(routes) {
  function(url, timeout) {
    for (pattern in names(routes)) {
      if (grepl(pattern, url, fixed = TRUE)) return(routes[[pattern]])
    }
    list(status = 404L, body = "{}")
  }
}

crossref_body <- function(title, year, family, doi) {
  jsonlite::toJSON(list(message = list(
    DOI = doi, title = list(title),
    issued = list(`date-parts` = list(list(year))),
    author = list(list(family = family))
  )), auto_unbox = TRUE)
}
