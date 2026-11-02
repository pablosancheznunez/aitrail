# Reading and writing records. Each record is one JSON file, so that
# changes show as clean diffs in version control and team members do not
# overwrite each other's work.

# Fields that describe a record's content; `id` and `created` are excluded,
# so the same content always gets the same identifier.
record_id <- function(type, fields) {
  content <- jsonlite::toJSON(fields, auto_unbox = TRUE, null = "null",
                              na = "null", digits = NA)
  prefix <- c(tool = "tool", use = "use", interaction = "int",
              verification = "ver", reference_check = "ref")[[type]]
  paste0(prefix, "-", substr(md5_string(paste(type, content)), 1, 10))
}

write_record <- function(path, type, fields) {
  check_log(path)
  id <- record_id(type, fields)
  dir <- file.path(log_dir(path), record_dirs[[type]])
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  file <- file.path(dir, paste0(id, ".json"))
  if (file.exists(file)) {
    message("This ", gsub("_", " ", type), " is already in the log as ", id, ".")
    return(id)
  }
  rec <- c(list(id = id, record = type), fields, list(created = utc_now()))
  jsonlite::write_json(rec, file, auto_unbox = TRUE, pretty = TRUE,
                       null = "null", na = "null", digits = NA)
  id
}

read_records <- function(path, type) {
  dir <- file.path(log_dir(path), record_dirs[[type]])
  files <- sort(list.files(dir, pattern = "\\.json$", full.names = TRUE))
  lapply(files, jsonlite::read_json)
}

record_exists <- function(path, type, id) {
  file.exists(file.path(log_dir(path), record_dirs[[type]], paste0(id, ".json")))
}

read_config <- function(path) {
  jsonlite::read_json(file.path(log_dir(path), "config.json"))
}

# A list field stored as a JSON array, even with one element.
as_array <- function(x) {
  if (is.null(x) || length(x) == 0L) return(I(character(0)))
  I(as.character(x))
}

collapse <- function(x) {
  if (is.null(x) || length(x) == 0L) return(NA_character_)
  paste(unlist(x), collapse = "; ")
}

value <- function(x) if (is.null(x)) NA_character_ else as.character(x)
