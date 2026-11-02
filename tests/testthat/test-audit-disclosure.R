rules_found <- function(p) unique(ait_audit(p)$rule)

test_that("the example project triggers the expected rules", {
  expect_setequal(rules_found(ait_example()), c("R01", "R02", "R03", "R04"))
})

test_that("an empty log has no findings", {
  a <- ait_audit(new_project())
  expect_s3_class(a, "ait_audit")
  expect_equal(nrow(a), 0)
  expect_output(print(a), "every rule passed")
})

test_that("each rule fires on its own fixture", {
  p <- new_project()
  t <- ait_tool("X", "Y", model = "m", version = "1", path = p)
  u <- ait_register_use("peer_review", "Summarise a manuscript", t, "Speed", path = p)
  expect_true(all(c("R01", "R05") %in% rules_found(p)))

  p <- new_project()
  t <- ait_tool("X", "Y", model = "m", version = "1", path = p)
  u <- ait_register_use("writing", "Draft results", t, "Speed", output_used = "substantial", path = p)
  ait_verify(u, "source_check", verifier = "A", path = p)
  expect_true("R02" %in% rules_found(p))
  ait_verify(u, "expert_review", verifier = "B", path = p)
  expect_false("R02" %in% rules_found(p))

  p <- new_project()
  t <- ait_tool("X", "Y", path = p)
  expect_true("R03" %in% rules_found(p))

  p <- new_project()
  t <- ait_tool("X", "Y", model = "m", version = "1", path = p)
  u <- ait_register_use("analysis", "Code", t, "Speed", path = p)
  ait_verify(u, "rerun_analysis", verifier = "A", path = p)
  suppressWarnings(ait_log_interaction(u, "call me on 600 123 456", store = "full", path = p))
  expect_true(all(c("R06", "R07") %in% rules_found(p)))
})

test_that("R04 clears once a reference check is recorded", {
  p <- new_project()
  t <- ait_tool("X", "Y", model = "m", version = "1", path = p)
  u <- ait_register_use("literature_review", "Find studies", t, "Coverage", path = p)
  ait_verify(u, "reference_check", verifier = "A", path = p)
  expect_true("R04" %in% rules_found(p))
  withr_fetch <- fake_fetch(list("api.crossref.org/works/10.1000/abc" =
    list(status = 200L, body = crossref_body("A title", 2020, "Doe", "10.1000/abc"))))
  old <- options(aitrail.fetch = withr_fetch)
  on.exit(options(old))
  ait_check_references("10.1000/abc", path = p)
  expect_false("R04" %in% rules_found(p))
})

test_that("orphan records are reported", {
  p <- new_project()
  t <- ait_tool("X", "Y", model = "m", version = "1", path = p)
  u <- ait_register_use("analysis", "Code", t, "Speed", path = p)
  ait_verify(u, "rerun_analysis", verifier = "A", path = p)
  unlink(file.path(p, "ai-log", "uses", paste0(u, ".json")))
  expect_true("R09" %in% rules_found(p))
})

test_that("the short disclosure reflects the log in both languages", {
  p <- ait_example()
  en <- ait_disclosure(p)
  expect_s3_class(en, "ait_disclosure")
  expect_match(en, "4 of the 5 recorded uses were verified")
  expect_match(en, "literature review; analysis and code; writing; translation and editing", fixed = TRUE)
  es <- ait_disclosure(p, lang = "es")
  expect_match(es, "verific")
  expect_match(es, "revisión bibliográfica")
})

test_that("an empty log does not claim that no AI was used", {
  d <- ait_disclosure(new_project())
  expect_match(d, "No use of AI tools was recorded")
})

test_that("full and JSON disclosures are complete", {
  p <- ait_example()
  full <- ait_disclosure(p, style = "full")
  expect_match(full, "| Phase | Task |", fixed = TRUE)
  expect_match(full, "not verified")
  js <- jsonlite::fromJSON(ait_disclosure(p, style = "json"))
  expect_equal(nrow(js$uses), 5)
  f <- tempfile(fileext = ".md")
  ait_disclosure(p, style = "full", file = f)
  expect_true(file.exists(f))
})

test_that("the HTML report is self-contained", {
  f <- tempfile(fileext = ".html")
  ait_report(ait_example(), f)
  html <- paste(readLines(f, encoding = "UTF-8"), collapse = "\n")
  expect_match(html, "<!doctype html>", fixed = TRUE)
  expect_false(grepl("<script src|<link rel=\"stylesheet\"", html))
  expect_match(html, "R04")
  f_es <- tempfile(fileext = ".html")
  ait_report(ait_example(), f_es, lang = "es")
  expect_match(paste(readLines(f_es, encoding = "UTF-8"), collapse = ""), "Informe de uso de IA")
})
