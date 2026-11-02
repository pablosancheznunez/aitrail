title <- "Exaggeration in health related science news"

routes <- list(
  "api.crossref.org/works/10.1000/real" =
    list(status = 200L, body = crossref_body(title, 2014, "Sumner", "10.1000/real")),
  "api.crossref.org/works/10.5281/data" = list(status = 404L, body = "{}"),
  "api.datacite.org/dois/10.5281/data" = list(status = 200L, body = jsonlite::toJSON(list(
    data = list(attributes = list(doi = "10.5281/data", titles = list(list(title = "A dataset")),
                                  publicationYear = 2021,
                                  creators = list(list(familyName = "Lopez"))))), auto_unbox = TRUE)),
  "api.crossref.org/works/10.1000/down" = list(status = 503L, body = ""),
  "query.bibliographic" = list(status = 200L, body = jsonlite::toJSON(list(message = list(items = list(list(
    DOI = "10.1000/real", title = list(title), issued = list(`date-parts` = list(list(2014))),
    author = list(list(family = "Sumner")))))), auto_unbox = TRUE))
)

check <- function(x) {
  old <- options(aitrail.fetch = fake_fetch(routes))
  on.exit(options(old))
  ait_check_references(x)
}

test_that("each status is assigned correctly", {
  refs <- data.frame(
    doi = c("https://doi.org/10.1000/REAL", "10.1000/real", "10.1000/real", "10.1000/fake",
            "10.5281/data", "10.1000/down", NA),
    title = c(title, "Something else entirely", NA, "Invented", "A dataset", "x", title),
    year = c(2014, 2014, NA, NA, 2021, NA, NA),
    author = c("Sumner", "Sumner", NA, NA, "Lopez", NA, NA)
  )
  r <- check(refs)
  expect_s3_class(r, "ait_references")
  expect_equal(r$status, c("verified", "mismatch", "found", "not_found", "verified",
                           "unchecked", "no_identifier"))
  expect_equal(r$doi[1], "10.1000/real")
  expect_equal(r$source[5], "datacite")
  expect_equal(r$candidate_doi[7], "10.1000/real")
})

test_that("a wrong year or first author is a mismatch", {
  r <- check(data.frame(doi = c("10.1000/real", "10.1000/real"), title = c(title, title),
                        year = c(2019, 2014), author = c("Sumner", "Smith")))
  expect_equal(r$status, c("mismatch", "mismatch"))
  expect_match(r$detail[1], "year")
  expect_match(r$detail[2], "first author")
})

test_that("DOIs are extracted from citation strings", {
  r <- check(c("Sumner P et al. BMJ 2014. doi:10.1000/real.", "no identifier here"))
  expect_equal(r$doi, c("10.1000/real", NA))
  expect_equal(r$status, c("found", "no_identifier"))
})

test_that("BibTeX files are read", {
  bib <- tempfile(fileext = ".bib")
  writeLines(c(
    "@article{sumner2014,",
    "  title = {Exaggeration in health related {science} news},",
    "  author = {Sumner, Petroc and Vivian-Griffiths, Solveiga},",
    "  year = {2014},",
    "  doi = {10.1000/real},",
    "}",
    "",
    "@book{nodoi,",
    "  title = \"A book without a DOI\",",
    "  author = {Ana Garcia},",
    "  year = 2020",
    "}"
  ), bib)
  r <- check(bib)
  expect_equal(r$ref, c("sumner2014", "nodoi"))
  expect_equal(r$status[1], "verified")
  expect_equal(r$status[2], "no_identifier")
})

test_that("title similarity ignores case, accents and punctuation", {
  expect_equal(aitrail:::title_similarity("Évaluation: A study!", "evaluation a study"), 1)
  expect_lt(aitrail:::title_similarity("cats and dogs", "quantum fields"), 0.2)
})
