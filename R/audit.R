#' Rules applied by the audit
#'
#' Each rule has a stable identifier, so that findings can be cited and
#' tracked across versions of the package.
#'
#' @return A data frame with columns `rule`, `severity` and `description`.
#' @export
#'
#' @examples
#' ait_audit_rules()
ait_audit_rules <- function() {
  data.frame(
    rule = sprintf("R%02d", 1:9),
    severity = c("warn", "warn", "info", "warn", "warn", "warn", "warn", "warn", "warn"),
    description = c(
      "A use has no recorded verification.",
      "AI output was used substantially in analysis, interpretation or writing without an expert review.",
      "A tool has no model or version recorded.",
      "AI was used in the literature review, but no reference check is recorded.",
      "AI was used in peer review, which many journals and funders do not allow.",
      "Prompts are stored in full although the project's policy is not to.",
      "A prompt stored in full may contain personal data.",
      "A use refers to a tool that is not in the log.",
      "A verification or interaction refers to a use that is not in the log."
    ),
    stringsAsFactors = FALSE
  )
}

#' Audit an AI-use log
#'
#' Checks the log for gaps in human oversight and documentation, using the
#' rules listed by [ait_audit_rules()]. The audit describes findings one by
#' one; it does not compute a score.
#'
#' @param path Root folder of the project, or an `ait_log` object.
#'
#' @return A data frame of class `ait_audit`, one row per finding, with
#'   columns `rule`, `severity`, `record` and `message`.
#' @export
#'
#' @examples
#' ait_audit(ait_example())
ait_audit <- function(path = ".") {
  log <- if (inherits(path, "ait_log")) path else ait_log(path)
  uses <- log$uses
  vers <- log$verifications
  tools <- log$tools
  ints <- log$interactions
  findings <- list()
  add <- function(rule, record, message) {
    findings[[length(findings) + 1L]] <<- data.frame(
      rule = rule, record = record, message = message, stringsAsFactors = FALSE)
  }
  describe <- function(i) sprintf("%s (%s)", uses$task[i], label(uses$phase[i], "phases"))

  for (i in seq_len(nrow(uses))) {
    v <- vers[vers$use == uses$id[i], , drop = FALSE]
    if (!nrow(v)) add("R01", uses$id[i], paste("Not verified:", describe(i)))
    if (uses$output_used[i] == "substantial" &&
        uses$phase[i] %in% c("analysis", "interpretation", "writing") &&
        !"expert_review" %in% v$method) {
      add("R02", uses$id[i], paste("Substantial use without expert review:", describe(i)))
    }
    if (uses$phase[i] == "peer_review") {
      add("R05", uses$id[i], paste("AI used in peer review:", describe(i),
                                   "- check the journal's or funder's policy"))
    }
    if (!uses$tool[i] %in% tools$id) {
      add("R08", uses$id[i], paste("Unknown tool", uses$tool[i], "in", describe(i)))
    }
  }
  for (i in seq_len(nrow(tools))) {
    missing <- c("model", "version")[is.na(c(tools$model[i], tools$version[i]))]
    if (length(missing)) {
      add("R03", tools$id[i], sprintf("%s has no %s recorded", tools$name[i],
                                      paste(missing, collapse = " or ")))
    }
  }
  if (any(uses$phase == "literature_review") && !nrow(log$reference_checks)) {
    add("R04", NA_character_,
        "Literature review used AI, but no reference check is recorded; run ait_check_references(path = ...)")
  }
  full <- ints[ints$store == "full", , drop = FALSE]
  policy <- log$config$prompt_store %||% "hash"
  if (nrow(full) && policy != "full") {
    add("R06", NA_character_, sprintf("%d interaction(s) stored in full; the project's policy is '%s'",
                                      nrow(full), policy))
  }
  for (i in seq_len(nrow(full))) {
    found <- detect_personal_data(full$prompt[i] %||% "")
    if (length(found)) {
      add("R07", full$id[i], paste("Possible personal data in a stored prompt:",
                                   paste(found, collapse = ", ")))
    }
  }
  orphan <- function(df) df$id[!is.na(df$use) & !df$use %in% uses$id]
  for (id in c(orphan(vers), orphan(ints))) add("R09", id, "Refers to a use that is not in the log")

  out <- if (length(findings)) do.call(rbind, findings) else
    data.frame(rule = character(0), record = character(0), message = character(0))
  rules <- ait_audit_rules()
  out$severity <- rules$severity[match(out$rule, rules$rule)]
  out <- out[order(out$rule), c("rule", "severity", "record", "message"), drop = FALSE]
  rownames(out) <- NULL
  structure(out, class = c("ait_audit", "data.frame"), n_uses = nrow(uses))
}

#' @export
print.ait_audit <- function(x, ...) {
  if (!all(c("rule", "severity", "message") %in% names(x))) return(NextMethod())
  cat("<ait_audit: ", attr(x, "n_uses"), " uses, ", nrow(x), " finding(s)>\n", sep = "")
  if (!nrow(x)) {
    cat("  No findings: every rule passed.\n")
    return(invisible(x))
  }
  for (i in seq_len(nrow(x))) {
    cat(sprintf("  %s [%s] %s\n", x$rule[i], x$severity[i], x$message[i]))
  }
  invisible(x)
}
