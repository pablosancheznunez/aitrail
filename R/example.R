#' Copy the example project to a temporary folder
#'
#' The package includes the AI-use log of a fictitious study (synthetic
#' data): a survey on attitudes to open data in which AI was used for the
#' literature review, analysis code, writing and translation. Some uses are
#' deliberately left unverified so that the audit has something to find.
#'
#' @param dest Folder to copy the example project into. A new temporary
#'   folder by default, so the original is never modified.
#'
#' @return The path of the copied project, to pass to the other functions.
#' @export
#'
#' @examples
#' project <- ait_example()
#' ait_log(project)
ait_example <- function(dest = tempfile("aitrail-example-")) {
  src <- system.file("extdata", "demo-project", package = "aitrail")
  dir.create(dest, recursive = TRUE, showWarnings = FALSE)
  file.copy(file.path(src, "ai-log"), dest, recursive = TRUE)
  dest
}
