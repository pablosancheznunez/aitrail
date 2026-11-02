#' Generate an AI-use disclosure statement
#'
#' Writes the disclosure from the log, so that it reflects what was recorded
#' during the project rather than what is remembered at the end. Review and
#' adapt it to the policy of the journal, funder or institution: the package
#' does not certify compliance with any particular policy.
#'
#' @param path Root folder of the project, or an `ait_log` object.
#' @param style `"short"`: a paragraph for the methods or acknowledgements
#'   section. `"full"`: a Markdown appendix with tools, uses and
#'   verifications. `"json"`: a machine-readable summary.
#' @param lang Language: `"en"` (English) or `"es"` (Spanish).
#' @param file Optional file to write the statement to.
#'
#' @return An object of class `ait_disclosure` (a character string), printed
#'   as plain text.
#' @export
#'
#' @examples
#' project <- ait_example()
#' ait_disclosure(project)
#' ait_disclosure(project, lang = "es")
#' ait_disclosure(project, style = "full")
ait_disclosure <- function(path = ".", style = c("short", "full", "json"),
                           lang = c("en", "es"), file = NULL) {
  style <- match.arg(style)
  lang <- match.arg(lang)
  log <- if (inherits(path, "ait_log")) path else ait_log(path)
  text <- switch(style,
                 short = disclosure_short(log, lang),
                 full = disclosure_full(log, lang),
                 json = disclosure_json(log))
  if (!is.null(file)) writeLines(text, file, useBytes = TRUE)
  structure(text, class = "ait_disclosure")
}

#' @export
print.ait_disclosure <- function(x, ...) {
  cat(x, "\n", sep = "")
  invisible(x)
}

tool_label <- function(tools, ids) {
  t <- tools[match(ids, tools$id), , drop = FALSE]
  detail <- vapply(seq_len(nrow(t)), function(i) {
    parts <- c(t$provider[i], t$model[i], t$version[i])
    paste(parts[!is.na(parts)], collapse = ", ")
  }, character(1))
  paste0(t$name, " (", detail, ")")
}

disclosure_short <- function(log, lang) {
  s <- strings(lang)
  uses <- log$uses
  if (!nrow(uses)) return(s$short_none)
  phase_order <- ait_vocabulary("phases")$id
  phases <- phase_order[phase_order %in% uses$phase]
  verified <- uses$id %in% log$verifications$use
  methods <- unique(log$verifications$method[log$verifications$use %in% uses$id])
  method_text <- if (length(methods)) enumerate(label(methods, "methods", lang), s$and) else s$no_methods
  values <- list(
    tools = enumerate(tool_label(log$tools, unique(uses$tool)), s$and),
    phases = paste(tolower(label(phases, "phases", lang)), collapse = "; "),
    n_uses = nrow(uses), n_verified = sum(verified), methods = method_text
  )
  substantial <- phase_order[phase_order %in% uses$phase[uses$output_used == "substantial"]]
  verification <- if (all(verified)) s$short_verified_all else
    if (any(verified)) s$short_verified_some else s$short_verified_none
  parts <- c(
    s$short_intro,
    verification,
    if (length(substantial)) fill(s$short_substantial, list(
      substantial = paste(tolower(label(substantial, "phases", lang)), collapse = "; ")))
    else s$short_no_substantial,
    s$short_responsibility
  )
  paste(vapply(parts, fill, "", values = values), collapse = " ")
}

md_table <- function(df) {
  esc <- function(x) gsub("|", "\\|", ifelse(is.na(x), "", as.character(x)), fixed = TRUE)
  c(paste0("| ", paste(names(df), collapse = " | "), " |"),
    paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|"),
    apply(df, 1, function(r) paste0("| ", paste(esc(r), collapse = " | "), " |")))
}

verification_text <- function(log, use_ids, lang) {
  s <- strings(lang)
  vapply(use_ids, function(u) {
    v <- log$verifications[log$verifications$use == u, , drop = FALSE]
    if (!nrow(v)) return(s$not_verified)
    paste(sprintf("%s (%s, %s)", label(v$method, "methods", lang),
                  label(v$outcome, "outcomes", lang), v$verifier), collapse = "; ")
  }, character(1))
}

disclosure_full <- function(log, lang) {
  s <- strings(lang)
  uses <- log$uses
  phase_order <- ait_vocabulary("phases")$id
  uses <- uses[order(match(uses$phase, phase_order), uses$date), , drop = FALSE]
  tools <- log$tools[order(log$tools$name), , drop = FALSE]
  tools_df <- data.frame(tools$name, tools$provider, tools$model, tools$version,
                         label(tools$access, "access", lang))
  names(tools_df) <- c(s$tool, s$provider, s$model, s$version, s$access)
  uses_df <- data.frame(label(uses$phase, "phases", lang), uses$task,
                        tools$name[match(uses$tool, tools$id)], uses$purpose,
                        label(uses$output_used, "output_used", lang),
                        verification_text(log, uses$id, lang))
  names(uses_df) <- c(s$phase, s$task, s$tool, s$purpose, s$output_used, s$verification)
  paste(c(paste("##", s$full_title), "", disclosure_short(log, lang), "",
          paste("###", s$tools), "", md_table(tools_df), "",
          paste("###", s$uses), "", if (nrow(uses)) md_table(uses_df) else s$short_none),
        collapse = "\n")
}

disclosure_json <- function(log) {
  uses <- log$uses
  out <- list(
    project = log$config$title,
    generated = utc_now(),
    generator = paste0("aitrail ", utils::packageVersion("aitrail")),
    tools = lapply(seq_len(nrow(log$tools)), function(i) as.list(log$tools[i, c("id", "name", "provider", "model", "version", "access")])),
    uses = lapply(seq_len(nrow(uses)), function(i) {
      v <- log$verifications[log$verifications$use == uses$id[i], c("method", "outcome", "date"), drop = FALSE]
      c(as.list(uses[i, c("id", "date", "phase", "task", "tool", "purpose", "output_used")]),
        list(verifications = lapply(seq_len(nrow(v)), function(j) as.list(v[j, ]))))
    })
  )
  as.character(jsonlite::toJSON(out, auto_unbox = TRUE, pretty = TRUE, na = "null"))
}
