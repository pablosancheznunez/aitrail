#' Controlled vocabularies of the AI-use log
#'
#' The log uses fixed vocabularies so that records from different projects
#' can be compared and summarised. Each term has an identifier, labels in
#' English and Spanish, and a description.
#'
#' @param which Which vocabulary: `"phases"` of a research project,
#'   `"output_used"` (how much of the AI output was kept), verification
#'   `"methods"`, verification `"outcomes"`, or tool `"access"`.
#'
#' @return A data frame with columns `id`, `en`, `es` and `description`.
#' @export
#'
#' @examples
#' ait_vocabulary("phases")
#' ait_vocabulary("methods")
ait_vocabulary <- function(which = c("phases", "output_used", "methods",
                                     "outcomes", "access")) {
  which <- match.arg(which)
  terms <- read_extdata("vocabulary.json")[[which]]
  data.frame(
    id = vapply(terms, `[[`, "", "id"),
    en = vapply(terms, `[[`, "", "en"),
    es = vapply(terms, `[[`, "", "es"),
    description = vapply(terms, `[[`, "", "description"),
    stringsAsFactors = FALSE
  )
}

label <- function(ids, which, lang = "en") {
  v <- ait_vocabulary(which)
  out <- v[[lang]][match(ids, v$id)]
  ifelse(is.na(out), ids, out)
}
