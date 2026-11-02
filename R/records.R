#' Start an AI-use log in a project
#'
#' Creates an `ai-log/` folder at the root of a project. Records are plain
#' JSON files, one per record, meant to be kept under version control with
#' the project's code and data.
#'
#' @param path Root folder of the project.
#' @param title Title of the project, used in disclosures and reports.
#' @param prompt_store Default way of storing prompts and responses:
#'   `"hash"` (only a fingerprint, the default), `"excerpt"` (the first 200
#'   characters), `"full"` or `"none"`. Prompts often contain unpublished data
#'   or personal data, so storing them in full is an explicit choice.
#'
#' @return The path of the `ai-log/` folder, invisibly.
#' @export
#'
#' @examples
#' project <- file.path(tempdir(), "my-study")
#' ait_init(project, title = "Attitudes to open data")
ait_init <- function(path = ".", title = NULL,
                     prompt_store = c("hash", "excerpt", "full", "none")) {
  prompt_store <- match.arg(prompt_store)
  check_string(title, "title", null_ok = TRUE)
  dir <- log_dir(path)
  if (file.exists(file.path(dir, "config.json"))) {
    message("An AI-use log already exists in ", normalizePath(dir), ".")
    return(invisible(dir))
  }
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  config <- list(
    schema_version = "0.1.0",
    title = title %||% basename(normalizePath(path, mustWork = FALSE)),
    prompt_store = prompt_store,
    created = utc_now()
  )
  jsonlite::write_json(config, file.path(dir, "config.json"), auto_unbox = TRUE,
                       pretty = TRUE, null = "null")
  writeLines(c(
    "# AI-use log",
    "",
    "This folder records how AI tools were used in this project. It is managed",
    "with the aitrail R package (https://pablosancheznunez.com/aitrail/).",
    "Keep it under version control; do not edit the files by hand."
  ), file.path(dir, "README.md"))
  invisible(dir)
}

#' Register an AI tool
#'
#' @param name Name of the tool, such as `"ChatGPT"` or `"Elicit"`.
#' @param provider Organisation that provides it.
#' @param model Model used, if known, such as `"GPT-4o"`.
#' @param version Version, release date or snapshot of the model, if known.
#' @param access How it was accessed: see `ait_vocabulary("access")`.
#' @param data_retention Optional note on the provider's data retention or
#'   training terms for the plan used.
#' @param notes Optional free-text notes.
#' @param path Root folder of the project.
#'
#' @return The identifier of the tool record.
#' @export
#'
#' @examples
#' project <- file.path(tempdir(), "tool-example")
#' ait_init(project)
#' ait_tool("ChatGPT", provider = "OpenAI", model = "GPT-4o",
#'          version = "2024-08-06", access = "web", path = project)
ait_tool <- function(name, provider, model = NULL, version = NULL,
                     access = "web", data_retention = NULL, notes = NULL,
                     path = ".") {
  check_string(name, "name")
  check_string(provider, "provider")
  check_string(model, "model", null_ok = TRUE)
  check_string(version, "version", null_ok = TRUE)
  check_choice(access, "access", "access")
  write_record(path, "tool", list(
    name = name, provider = provider, model = model, version = version,
    access = access, data_retention = data_retention, notes = notes
  ))
}

#' Register a use of AI in a phase of the project
#'
#' One record per distinct use: a task in a phase, done with one tool.
#' Repeated conversations for the same task belong to the same use; record
#' them with [ait_log_interaction()].
#'
#' @param phase Phase of the project: see `ait_vocabulary("phases")`.
#' @param task Short description of the task, such as
#'   `"Summarise 40 abstracts for screening"`.
#' @param tool Identifier returned by [ait_tool()].
#' @param purpose Why AI was used for this task.
#' @param output_used How much of the output was kept: `"none"`,
#'   `"partial"` or `"substantial"` (see `ait_vocabulary("output_used")`).
#' @param person Who used the tool: a name or an ORCID iD.
#' @param date Date of the use.
#' @param files Optional paths of project files that contain AI output.
#' @param risks Optional character vector of risks noticed, such as
#'   `"possible invented citations"`.
#' @param notes Optional free-text notes.
#' @param path Root folder of the project.
#'
#' @return The identifier of the use record.
#' @export
#'
#' @examples
#' project <- file.path(tempdir(), "use-example")
#' ait_init(project)
#' gpt <- ait_tool("ChatGPT", "OpenAI", model = "GPT-4o", path = project)
#' ait_register_use("literature_review", "Summarise abstracts for screening",
#'                  tool = gpt, purpose = "Speed up first-pass screening",
#'                  output_used = "partial", person = "A. Researcher",
#'                  date = "2026-03-02", path = project)
ait_register_use <- function(phase, task, tool, purpose,
                             output_used = c("partial", "none", "substantial"),
                             person = NULL, date = Sys.Date(), files = NULL,
                             risks = NULL, notes = NULL, path = ".") {
  check_choice(phase, "phases", "phase")
  check_string(task, "task")
  check_string(tool, "tool")
  check_string(purpose, "purpose")
  output_used <- match.arg(output_used)
  check_log(path)
  if (!record_exists(path, "tool", tool)) {
    stop("Tool '", tool, "' is not in the log. Register it with ait_tool().",
         call. = FALSE)
  }
  write_record(path, "use", list(
    phase = phase, task = task, tool = tool, purpose = purpose,
    output_used = output_used, person = person,
    date = as_date_string(date, "date"), files = as_array(files),
    risks = as_array(risks), notes = notes
  ))
}

#' Record an interaction with an AI tool
#'
#' Stores a prompt and, optionally, the response, following the project's
#' privacy policy. With `store = "hash"` only an MD5 fingerprint is kept: it
#' shows that a given text was used without revealing it.
#'
#' @param use Identifier returned by [ait_register_use()].
#' @param prompt The prompt, as text.
#' @param response Optional response, as text.
#' @param summary Optional short human summary of the response.
#' @param store How to store the prompt and response: `"hash"`, `"excerpt"`,
#'   `"full"` or `"none"`. Defaults to the project's policy set in
#'   [ait_init()].
#' @param parameters Optional named list of generation parameters, if known.
#' @param timestamp Time of the interaction.
#' @param path Root folder of the project.
#'
#' @return The identifier of the interaction record.
#' @export
#'
#' @examples
#' project <- ait_example()
#' log <- ait_log(project)
#' ait_log_interaction(log$uses$id[1], prompt = "Summarise this abstract: ...",
#'                     summary = "A three-sentence summary", path = project)
ait_log_interaction <- function(use, prompt, response = NULL, summary = NULL,
                                store = NULL, parameters = NULL,
                                timestamp = Sys.time(), path = ".") {
  check_string(use, "use")
  check_string(prompt, "prompt")
  check_log(path)
  if (!record_exists(path, "use", use)) {
    stop("Use '", use, "' is not in the log. Register it with ait_register_use().",
         call. = FALSE)
  }
  policy <- read_config(path)$prompt_store %||% "hash"
  store <- match.arg(store %||% policy, c("hash", "excerpt", "full", "none"))
  if (store == "full") {
    found <- detect_personal_data(c(prompt, response %||% ""))
    if (length(found)) {
      warning("The prompt or response may contain personal data (",
              paste(found, collapse = ", "), "). It is stored in full because ",
              "store = \"full\".", call. = FALSE)
    }
  }
  keep <- function(text) {
    if (is.null(text)) return(NULL)
    switch(store,
           full = text,
           excerpt = substr(text, 1, 200),
           NULL)
  }
  fingerprint <- function(text) {
    if (is.null(text) || store == "none") NULL else md5_string(text)
  }
  write_record(path, "interaction", list(
    use = use,
    timestamp = format(as.POSIXct(timestamp), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    store = store,
    prompt = keep(prompt), prompt_md5 = fingerprint(prompt),
    response = keep(response), response_md5 = fingerprint(response),
    summary = summary, parameters = parameters
  ))
}

#' Record how a person verified an AI use
#'
#' Human oversight is what makes AI use defensible. Each use can have several
#' verifications, by different people and methods.
#'
#' @param use Identifier returned by [ait_register_use()].
#' @param method How it was verified: see `ait_vocabulary("methods")`.
#' @param outcome Result: `"accepted"`, `"modified"` or `"rejected"`.
#' @param verifier Who verified it: a name or an ORCID iD.
#' @param notes Optional notes, such as what was corrected.
#' @param date Date of the verification.
#' @param path Root folder of the project.
#'
#' @return The identifier of the verification record.
#' @export
#'
#' @examples
#' project <- ait_example()
#' log <- ait_log(project)
#' ait_verify(log$uses$id[1], method = "source_check", outcome = "modified",
#'            verifier = "B. Reviewer", notes = "Two summaries corrected",
#'            path = project)
ait_verify <- function(use, method, outcome = c("accepted", "modified", "rejected"),
                       verifier, notes = NULL, date = Sys.Date(), path = ".") {
  check_string(use, "use")
  check_choice(method, "methods", "method")
  outcome <- match.arg(outcome)
  check_string(verifier, "verifier")
  check_log(path)
  if (!record_exists(path, "use", use)) {
    stop("Use '", use, "' is not in the log.", call. = FALSE)
  }
  write_record(path, "verification", list(
    use = use, method = method, outcome = outcome, verifier = verifier,
    notes = notes, date = as_date_string(date, "date")
  ))
}

# Names, e-mail addresses, phone numbers and Spanish national identity
# numbers are the patterns most likely to leak into prompts.
detect_personal_data <- function(text) {
  text <- paste(text, collapse = "\n")
  # ORCID iDs and DOIs are public identifiers, not personal data to flag.
  text <- gsub("[0-9]{4}-[0-9]{4}-[0-9]{4}-[0-9]{3}[0-9X]", "", text)
  text <- gsub("10\\.[0-9]{4,9}/[^[:space:]]+", "", text)
  patterns <- c(
    "e-mail address" = "[[:alnum:]._%+-]+@[[:alnum:].-]+\\.[[:alpha:]]{2,}",
    "phone number" = "(\\+[0-9]{1,3}[ -]?)?([0-9][ -]?){9,}",
    "DNI/NIE" = "\\b([0-9]{8}|[XYZ][0-9]{7})[A-Z]\\b"
  )
  names(patterns)[vapply(patterns, grepl, logical(1), x = text, perl = TRUE)]
}

#' Read a project's AI-use log
#'
#' @param path Root folder of the project.
#'
#' @return An object of class `ait_log`: a list with the project `config` and
#'   data frames `tools`, `uses`, `interactions`, `verifications` and
#'   `reference_checks`.
#' @export
#'
#' @examples
#' log <- ait_log(ait_example())
#' log
#' log$uses
ait_log <- function(path = ".") {
  check_log(path)
  tools <- read_records(path, "tool")
  uses <- read_records(path, "use")
  ints <- read_records(path, "interaction")
  vers <- read_records(path, "verification")
  refs <- read_records(path, "reference_check")

  df <- function(recs, fields, multi = character(0)) {
    cols <- lapply(fields, function(f) {
      vapply(recs, function(r) if (f %in% multi) collapse(r[[f]]) else value(r[[f]]),
             character(1))
    })
    names(cols) <- fields
    as.data.frame(cols, stringsAsFactors = FALSE)
  }

  structure(list(
    path = normalizePath(path),
    config = read_config(path),
    tools = df(tools, c("id", "name", "provider", "model", "version", "access",
                        "data_retention", "notes")),
    uses = df(uses, c("id", "date", "phase", "task", "tool", "purpose",
                      "output_used", "person", "files", "risks", "notes"),
              multi = c("files", "risks")),
    interactions = df(ints, c("id", "use", "timestamp", "store", "prompt",
                              "prompt_md5", "response_md5", "summary")),
    verifications = df(vers, c("id", "use", "date", "method", "outcome",
                               "verifier", "notes")),
    reference_checks = df(refs, c("id", "date", "n", "verified", "found",
                                  "mismatch", "not_found", "no_identifier",
                                  "unchecked"))
  ), class = "ait_log")
}

#' @export
print.ait_log <- function(x, ...) {
  cat("<ait_log: ", x$config$title, ">\n", sep = "")
  cat("  Tools:         ", nrow(x$tools), "\n", sep = "")
  cat("  Uses:          ", nrow(x$uses), "\n", sep = "")
  cat("  Interactions:  ", nrow(x$interactions), "\n", sep = "")
  cat("  Verifications: ", nrow(x$verifications), "\n", sep = "")
  if (nrow(x$uses)) {
    order <- ait_vocabulary("phases")$id
    phases <- order[order %in% x$uses$phase]
    cat("  Phases:        ", paste(label(phases, "phases"), collapse = "; "), "\n", sep = "")
  }
  cat("  Prompt storage: ", x$config$prompt_store, "\n", sep = "")
  invisible(x)
}
