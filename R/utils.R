`%||%` <- function(a, b) if (is.null(a)) b else a

# Directory names inside ai-log/, one per record type.
record_dirs <- c(
  tool = "tools",
  use = "uses",
  interaction = "interactions",
  verification = "verifications",
  reference_check = "reference-checks"
)

log_dir <- function(path) file.path(path, "ai-log")

check_log <- function(path) {
  if (!file.exists(file.path(log_dir(path), "config.json"))) {
    stop("No AI-use log found in '", normalizePath(path, mustWork = FALSE),
         "'. Create one with ait_init().", call. = FALSE)
  }
  invisible(path)
}

read_extdata <- function(file) {
  jsonlite::read_json(system.file("extdata", file, package = "aitrail"))
}

check_string <- function(x, name, null_ok = FALSE) {
  if (is.null(x) && null_ok) return(invisible(x))
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(x)) {
    stop("`", name, "` must be a single non-empty string.", call. = FALSE)
  }
  invisible(x)
}

check_choice <- function(x, vocabulary, name) {
  ids <- ait_vocabulary(vocabulary)$id
  if (!is.character(x) || length(x) != 1L || !x %in% ids) {
    stop("`", name, "` must be one of: ", paste(ids, collapse = ", "), ".",
         call. = FALSE)
  }
  invisible(x)
}

as_date_string <- function(x, name) {
  d <- tryCatch(as.Date(x), error = function(e) NA)
  if (length(d) != 1L || is.na(d)) {
    stop("`", name, "` must be a date, such as \"2026-03-15\".", call. = FALSE)
  }
  format(d, "%Y-%m-%d")
}

utc_now <- function() format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

md5_string <- function(x) {
  f <- tempfile()
  on.exit(unlink(f))
  writeBin(charToRaw(enc2utf8(x)), f)
  unname(tools::md5sum(f))
}

# Fill {placeholders} in a template.
fill <- function(template, values) {
  for (n in names(values)) {
    template <- gsub(paste0("{", n, "}"), values[[n]], template, fixed = TRUE)
  }
  template
}

# "a, b and c"
enumerate <- function(x, and = "and") {
  x <- unique(x)
  if (length(x) <= 1L) return(paste(x, collapse = ""))
  paste(paste(x[-length(x)], collapse = ", "), and, x[length(x)])
}

html_escape <- function(x) {
  x <- gsub("&", "&amp;", as.character(x), fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  gsub("\"", "&quot;", x, fixed = TRUE)
}

strings <- function(lang) {
  lang <- match.arg(lang, c("en", "es"))
  read_extdata("i18n.json")[[lang]]
}
