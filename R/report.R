#' Write a self-contained HTML report of AI use
#'
#' The report gathers the disclosure statement, the tools, every use by
#' phase with its verifications, the reference checks and the audit
#' findings in a single HTML file with no external resources, suitable for
#' supervisors, co-authors, ethics committees or journal editors.
#'
#' @param path Root folder of the project, or an `ait_log` object.
#' @param file Output HTML file.
#' @param lang Language: `"en"` or `"es"`.
#'
#' @return The path of the report, invisibly.
#' @export
#'
#' @examples
#' out <- file.path(tempdir(), "ai-use-report.html")
#' ait_report(ait_example(), out)
ait_report <- function(path = ".", file = "ai-use-report.html", lang = c("en", "es")) {
  lang <- match.arg(lang)
  s <- strings(lang)
  log <- if (inherits(path, "ait_log")) path else ait_log(path)
  audit <- ait_audit(log)
  uses <- log$uses
  phase_order <- ait_vocabulary("phases")$id
  uses <- uses[order(match(uses$phase, phase_order), uses$date), , drop = FALSE]

  table_html <- function(df) {
    if (!nrow(df)) return("")
    head <- paste0("<tr>", paste0("<th>", html_escape(names(df)), "</th>", collapse = ""), "</tr>")
    body <- apply(df, 1, function(r) {
      paste0("<tr>", paste0("<td>", html_escape(ifelse(is.na(r), "", r)), "</td>", collapse = ""), "</tr>")
    })
    paste0('<div class="scroll"><table><thead>', head, "</thead><tbody>",
           paste(body, collapse = ""), "</tbody></table></div>")
  }

  stat <- function(n, what) sprintf('<div class="stat"><b>%d</b><span>%s</span></div>', n, html_escape(what))
  tools <- log$tools[order(log$tools$name), , drop = FALSE]
  tools_df <- data.frame(tools$name, tools$provider, tools$model, tools$version,
                         label(tools$access, "access", lang))
  names(tools_df) <- c(s$tool, s$provider, s$model, s$version, s$access)
  uses_df <- data.frame(uses$date, label(uses$phase, "phases", lang), uses$task,
                        tools$name[match(uses$tool, tools$id)],
                        label(uses$output_used, "output_used", lang),
                        verification_text(log, uses$id, lang))
  names(uses_df) <- c(s$date, s$phase, s$task, s$tool, s$output_used, s$verification)
  refs <- log$reference_checks
  refs_df <- if (nrow(refs)) {
    totals <- vapply(reference_statuses, function(st) sum(as.integer(refs[[st]]), na.rm = TRUE), numeric(1))
    df <- data.frame(names(totals), as.integer(totals))
    names(df) <- c(s$status, s$count)
    df[df[[2]] > 0, , drop = FALSE]
  } else NULL
  audit_df <- as.data.frame(unclass(audit))[, c("rule", "severity", "message"), drop = FALSE]
  names(audit_df) <- c(s$rule, s$severity, s$message)

  css <- paste(
    ":root{--ink:#1b2430;--muted:#5b6575;--bg:#fbfbfa;--card:#fff;--line:#e2e4e8;--accent:#1f5f5b;--warn:#a35200}",
    "@media (prefers-color-scheme:dark){:root{--ink:#e7eaee;--muted:#a7afbb;--bg:#14181d;--card:#1c2229;--line:#2d3540;--accent:#6cc2bb;--warn:#f0a35c}}",
    "body{margin:0;background:var(--bg);color:var(--ink);font:16px/1.55 system-ui,-apple-system,Segoe UI,sans-serif}",
    "main{max-width:1000px;margin:0 auto;padding:32px 16px 64px}",
    "h1{font-family:Georgia,serif;font-weight:normal;margin:0 0 4px}h2{margin:40px 0 12px;font-size:1.2em;color:var(--accent)}",
    ".muted{color:var(--muted)}.stats{display:flex;flex-wrap:wrap;gap:12px;margin:20px 0}",
    ".stat{background:var(--card);border:1px solid var(--line);border-radius:8px;padding:10px 16px;min-width:110px}",
    ".stat b{display:block;font-size:1.6em}.stat span{color:var(--muted);font-size:.9em}",
    ".statement{background:var(--card);border-left:4px solid var(--accent);padding:12px 16px;border-radius:4px}",
    ".scroll{overflow-x:auto}table{border-collapse:collapse;width:100%;font-size:.92em;background:var(--card)}",
    "th,td{border-bottom:1px solid var(--line);padding:8px;text-align:left;vertical-align:top}th{color:var(--muted);font-weight:600}",
    "td:nth-child(2){white-space:nowrap}.warn{color:var(--warn)}footer{margin-top:48px;color:var(--muted);font-size:.85em}"
  )
  html <- c(
    "<!doctype html>", sprintf('<html lang="%s"><head><meta charset="utf-8">', lang),
    '<meta name="viewport" content="width=device-width, initial-scale=1">',
    sprintf("<title>%s: %s</title>", html_escape(s$report_title), html_escape(log$config$title)),
    "<style>", css, "</style></head><body><main>",
    sprintf("<h1>%s</h1>", html_escape(log$config$title)),
    sprintf('<p class="muted">%s</p>', html_escape(s$report_title)),
    '<div class="stats">',
    stat(nrow(log$tools), s$n_tools), stat(nrow(log$uses), s$n_uses),
    stat(nrow(log$interactions), s$n_interactions), stat(nrow(log$verifications), s$n_verifications),
    "</div>",
    sprintf("<h2>%s</h2>", html_escape(s$statement)),
    sprintf('<p class="statement">%s</p>', html_escape(disclosure_short(log, lang))),
    sprintf("<h2>%s</h2>", html_escape(s$tools)), table_html(tools_df),
    sprintf("<h2>%s</h2>", html_escape(s$uses)), table_html(uses_df),
    if (!is.null(refs_df)) c(sprintf("<h2>%s</h2>", html_escape(s$references)), table_html(refs_df)),
    sprintf("<h2>%s</h2>", html_escape(s$audit)),
    if (nrow(audit)) table_html(audit_df) else sprintf("<p>%s</p>", html_escape(s$no_findings)),
    sprintf('<footer><p>%s</p><p>%s %s.</p></footer>', html_escape(s$note), html_escape(s$generated),
            format(Sys.Date())),
    "</main></body></html>"
  )
  writeLines(enc2utf8(html), file, useBytes = TRUE)
  invisible(normalizePath(file))
}
