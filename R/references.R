#' Check that references exist and match their metadata
#'
#' Language models can produce references that look plausible but do not
#' exist, or attach a real DOI to the wrong paper. This function looks up each
#' reference in Crossref and, if needed, DataCite, and compares the title,
#' year and first author with what was cited.
#'
#' | Status | Meaning |
#' |---|---|
#' | `verified` | The DOI exists and its title, year and first author match |
#' | `found` | The DOI exists; no title was given to compare |
#' | `mismatch` | The DOI exists, but its metadata do not match the citation |
#' | `not_found` | The DOI is in neither Crossref nor DataCite. This does **not** prove the reference is invented: some DOIs are registered elsewhere |
#' | `no_identifier` | No DOI. If a title was given, the closest Crossref match is reported as `candidate_doi`, for a person to check |
#' | `unchecked` | No connection, the service failed, or the curl package is not installed |
#'
#' @param x References to check: a character vector of DOIs or citation
#'   strings containing DOIs, the path of a BibTeX (`.bib`) file, or a data
#'   frame with a `doi` column and, optionally, `title`, `year` and `author`
#'   (first author's family name).
#' @param path Optional root folder of a project with an AI-use log. If given,
#'   a summary of the check is saved in the log, so that [ait_audit()] can
#'   see that references were checked.
#' @param mailto Optional e-mail address sent to Crossref, which gives
#'   faster, more reliable service to identified users.
#' @param timeout Seconds to wait for each request.
#'
#' @return A data frame of class `ait_references`, one row per reference, with
#'   columns `ref`, `doi`, `title`, `status`, `source`, `found_title`,
#'   `found_year`, `similarity`, `candidate_doi` and `detail`.
#' @export
#'
#' @examples
#' refs <- data.frame(
#'   doi = "10.1136/bmj.g7015",
#'   title = paste("The association between exaggeration in health related",
#'                 "science news and academic press releases"),
#'   year = 2014, author = "Sumner"
#' )
#' \donttest{
#' if (requireNamespace("curl", quietly = TRUE)) ait_check_references(refs)
#' }
ait_check_references <- function(x, path = NULL, mailto = NULL, timeout = 20) {
  refs <- as_reference_table(x)
  fetch <- getOption("aitrail.fetch", default_fetch)
  if (identical(fetch, default_fetch) && !requireNamespace("curl", quietly = TRUE)) {
    message("Install the curl package to check references; all are marked 'unchecked'.")
    fetch <- function(url, timeout) list(status = NA_integer_, body = NULL)
  }
  rows <- lapply(seq_len(nrow(refs)), function(i) {
    check_one(refs[i, , drop = FALSE], fetch, mailto, timeout)
  })
  out <- do.call(rbind, rows)
  out <- cbind(ref = refs$ref, out, stringsAsFactors = FALSE)
  class(out) <- c("ait_references", "data.frame")

  if (!is.null(path)) {
    counts <- as.list(table(factor(out$status, levels = reference_statuses)))
    write_record(path, "reference_check", c(
      list(date = format(Sys.Date()), n = nrow(out)),
      counts,
      list(results = lapply(seq_len(nrow(out)), function(i) {
        list(ref = out$ref[i], doi = value_or_null(out$doi[i]),
             status = out$status[i], detail = value_or_null(out$detail[i]))
      }))
    ))
  }
  out
}

reference_statuses <- c("verified", "found", "mismatch", "not_found",
                        "no_identifier", "unchecked")

value_or_null <- function(x) if (length(x) == 0L || is.na(x)) NULL else x

#' @export
print.ait_references <- function(x, ...) {
  if (!all(c("ref", "status", "detail") %in% names(x))) return(NextMethod())
  counts <- table(factor(x$status, levels = reference_statuses))
  cat("<ait_references: ", nrow(x), " checked>\n", sep = "")
  for (s in names(counts)[counts > 0]) cat(sprintf("  %-14s %d\n", s, counts[[s]]))
  flagged <- x[x$status %in% c("mismatch", "not_found"), , drop = FALSE]
  if (nrow(flagged)) {
    cat("\nTo check by hand:\n")
    for (i in seq_len(nrow(flagged))) {
      cat(sprintf("  [%s] %s: %s\n", flagged$status[i], flagged$ref[i], flagged$detail[i]))
    }
  }
  invisible(x)
}

doi_pattern <- "10\\.[0-9]{4,9}/[^[:space:]\"<>{}]+"

extract_doi <- function(x) {
  m <- regmatches(x, regexpr(doi_pattern, x, perl = TRUE))
  out <- rep(NA_character_, length(x))
  out[grepl(doi_pattern, x, perl = TRUE)] <- sub("[.,;)]+$", "", m)
  tolower(out)
}

as_reference_table <- function(x) {
  if (is.data.frame(x)) {
    if (!"doi" %in% names(x) && !"title" %in% names(x)) {
      stop("A data frame of references needs a `doi` or a `title` column.", call. = FALSE)
    }
    n <- nrow(x)
    col <- function(name) if (name %in% names(x)) as.character(x[[name]]) else rep(NA_character_, n)
    doi <- col("doi")
    doi[!is.na(doi)] <- extract_doi(doi[!is.na(doi)])
    return(data.frame(
      ref = if ("ref" %in% names(x)) as.character(x$ref) else as.character(seq_len(n)),
      doi = doi, title = col("title"), year = col("year"), author = col("author"),
      stringsAsFactors = FALSE
    ))
  }
  if (is.character(x) && length(x) == 1L && grepl("\\.bib$", x, ignore.case = TRUE)) {
    if (!file.exists(x)) stop("File not found: ", x, call. = FALSE)
    return(read_bib(x))
  }
  if (is.character(x)) {
    return(data.frame(ref = as.character(seq_along(x)), doi = extract_doi(x),
                      title = NA_character_, year = NA_character_,
                      author = NA_character_, stringsAsFactors = FALSE))
  }
  stop("`x` must be DOIs, a .bib file or a data frame.", call. = FALSE)
}

# A small BibTeX reader: enough for key, doi, title, year and first author.
read_bib <- function(file) {
  text <- paste(readLines(file, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  entries <- strsplit(text, "\n?@", perl = TRUE)[[1]]
  entries <- entries[grepl("^[[:alpha:]]+[[:space:]]*\\{", entries)]
  field <- function(entry, name) {
    re <- paste0("(?is)\\b", name, "[[:space:]]*=[[:space:]]*[{\"](.*?)[}\"][[:space:]]*,?[[:space:]]*\n")
    m <- regmatches(entry, regexec(re, paste0(entry, "\n"), perl = TRUE))[[1]]
    if (length(m) < 2) return(NA_character_)
    trimws(gsub("[{}]", "", gsub("[[:space:]]+", " ", m[2])))
  }
  rows <- lapply(entries, function(e) {
    key <- sub("^[[:alpha:]]+[[:space:]]*\\{[[:space:]]*([^,]+),.*$", "\\1", e)
    author <- field(e, "author")
    first <- if (is.na(author)) NA_character_ else {
      a <- trimws(strsplit(author, " and ", fixed = TRUE)[[1]][1])
      if (grepl(",", a)) trimws(sub(",.*$", "", a)) else utils::tail(strsplit(a, " ")[[1]], 1)
    }
    doi <- field(e, "doi")
    data.frame(ref = trimws(key),
               doi = if (is.na(doi)) NA_character_ else extract_doi(doi),
               title = field(e, "title"), year = field(e, "year"), author = first,
               stringsAsFactors = FALSE)
  })
  if (!length(rows)) stop("No BibTeX entries found in ", file, call. = FALSE)
  do.call(rbind, rows)
}

default_fetch <- function(url, timeout) {
  h <- curl::new_handle(timeout = timeout,
                        useragent = paste0("aitrail/", utils::packageVersion("aitrail"),
                                           " (https://pablosancheznunez.com/aitrail/)"))
  res <- tryCatch(curl::curl_fetch_memory(url, handle = h), error = function(e) NULL)
  if (is.null(res)) return(list(status = NA_integer_, body = NULL))
  list(status = res$status_code, body = rawToChar(res$content))
}

encode_doi <- function(doi) gsub("%2F", "/", utils::URLencode(doi, reserved = TRUE), fixed = TRUE)

with_mailto <- function(url, mailto) {
  if (is.null(mailto)) return(url)
  paste0(url, if (grepl("?", url, fixed = TRUE)) "&" else "?",
         "mailto=", utils::URLencode(mailto, reserved = TRUE))
}

parse_json <- function(body) tryCatch(jsonlite::fromJSON(body, simplifyVector = FALSE),
                                      error = function(e) NULL)

crossref_meta <- function(m) {
  year <- tryCatch(m$issued$`date-parts`[[1]][[1]], error = function(e) NULL)
  list(title = value(m$title[[1]] %||% NULL),
       year = value(year),
       author = value(if (length(m$author)) m$author[[1]]$family else NULL),
       doi = tolower(value(m$DOI)))
}

datacite_meta <- function(d) {
  a <- d$data$attributes
  creator <- if (length(a$creators)) a$creators[[1]] else NULL
  list(title = value(if (length(a$titles)) a$titles[[1]]$title else NULL),
       year = value(a$publicationYear),
       author = value(creator$familyName %||% creator$name),
       doi = tolower(value(a$doi)))
}

normalise_title <- function(x) {
  x <- tolower(iconv(x, to = "ASCII//TRANSLIT", sub = ""))
  words <- strsplit(gsub("[^a-z0-9 ]", " ", x), "[[:space:]]+")[[1]]
  words[nchar(words) > 0]
}

title_similarity <- function(a, b) {
  if (is.na(a) || is.na(b)) return(NA_real_)
  wa <- unique(normalise_title(a))
  wb <- unique(normalise_title(b))
  if (!length(wa) || !length(wb)) return(NA_real_)
  length(intersect(wa, wb)) / length(union(wa, wb))
}

result <- function(doi, title, status, source = NA_character_, meta = NULL,
                   similarity = NA_real_, candidate = NA_character_, detail = NA_character_) {
  data.frame(doi = doi, title = title, status = status, source = source,
             found_title = if (is.null(meta)) NA_character_ else meta$title,
             found_year = if (is.null(meta)) NA_character_ else meta$year,
             similarity = round(similarity, 2), candidate_doi = candidate,
             detail = detail, stringsAsFactors = FALSE)
}

check_one <- function(ref, fetch, mailto, timeout) {
  doi <- ref$doi
  title <- ref$title
  if (is.na(doi)) {
    if (is.na(title)) {
      return(result(doi, title, "no_identifier", detail = "No DOI or title given"))
    }
    url <- with_mailto(paste0("https://api.crossref.org/works?rows=1&query.bibliographic=",
                              utils::URLencode(title, reserved = TRUE)), mailto)
    res <- fetch(url, timeout)
    if (!identical(as.integer(res$status), 200L)) {
      return(result(doi, title, "unchecked", detail = "Crossref search unavailable"))
    }
    items <- parse_json(res$body)$message$items
    if (!length(items)) return(result(doi, title, "no_identifier", detail = "No DOI; no close match found"))
    meta <- crossref_meta(items[[1]])
    sim <- title_similarity(title, meta$title)
    strong <- !is.na(sim) && sim >= 0.9
    return(result(doi, title, "no_identifier", "crossref", meta, sim,
                  candidate = if (strong) meta$doi else NA_character_,
                  detail = if (strong) "No DOI; a close match was found, check it by hand"
                           else "No DOI; no close match found"))
  }

  meta <- NULL
  source <- NA_character_
  cr <- fetch(with_mailto(paste0("https://api.crossref.org/works/", encode_doi(doi)), mailto), timeout)
  if (identical(as.integer(cr$status), 200L)) {
    meta <- crossref_meta(parse_json(cr$body)$message)
    source <- "crossref"
  } else if (identical(as.integer(cr$status), 404L)) {
    dc <- fetch(paste0("https://api.datacite.org/dois/", encode_doi(doi)), timeout)
    if (identical(as.integer(dc$status), 200L)) {
      meta <- datacite_meta(parse_json(dc$body))
      source <- "datacite"
    } else if (identical(as.integer(dc$status), 404L)) {
      return(result(doi, title, "not_found",
                    detail = "DOI not registered in Crossref or DataCite"))
    } else {
      return(result(doi, title, "unchecked", detail = "DataCite unavailable"))
    }
  } else {
    return(result(doi, title, "unchecked", detail = "Crossref unavailable"))
  }

  if (is.na(title)) {
    return(result(doi, title, "found", source, meta, detail = "DOI exists; no title given to compare"))
  }
  sim <- title_similarity(title, meta$title)
  problems <- character(0)
  if (is.na(sim) || sim < 0.8) problems <- c(problems, "title differs")
  if (!is.na(ref$year) && !is.na(meta$year) &&
      abs(suppressWarnings(as.numeric(ref$year)) - as.numeric(meta$year)) > 1) {
    problems <- c(problems, paste0("year ", ref$year, " vs ", meta$year))
  }
  if (!is.na(ref$author) && !is.na(meta$author) &&
      !identical(normalise_title(ref$author), normalise_title(meta$author))) {
    problems <- c(problems, paste0("first author ", ref$author, " vs ", meta$author))
  }
  if (length(problems)) {
    return(result(doi, title, "mismatch", source, meta, sim,
                  detail = paste0(paste(problems, collapse = "; "),
                                  if (!is.na(meta$title)) paste0(" (registered title: \"", meta$title, "\")"))))
  }
  result(doi, title, "verified", source, meta, sim, detail = "Metadata match")
}
