test_that("ait_init creates the log and does not overwrite it", {
  p <- new_project()
  expect_true(file.exists(file.path(p, "ai-log", "config.json")))
  expect_message(ait_init(p), "already exists")
  expect_equal(ait_log(p)$config$prompt_store, "hash")
})

test_that("functions refuse to work without a log", {
  expect_error(ait_log(tempfile()), "No AI-use log")
})

test_that("records get stable identifiers and are not duplicated", {
  p <- new_project()
  t1 <- ait_tool("ChatGPT", "OpenAI", model = "GPT-4o", path = p)
  expect_match(t1, "^tool-[0-9a-f]{10}$")
  expect_message(t2 <- ait_tool("ChatGPT", "OpenAI", model = "GPT-4o", path = p), "already")
  expect_identical(t1, t2)
  expect_equal(nrow(ait_log(p)$tools), 1)
})

test_that("uses validate their inputs", {
  p <- new_project()
  t <- ait_tool("Claude", "Anthropic", path = p)
  expect_error(ait_register_use("drafting", "x", t, "y", path = p), "phase")
  expect_error(ait_register_use("writing", "x", "tool-0000000000", "y", path = p), "not in the log")
  expect_error(ait_register_use("writing", "x", t, "y", date = "soon", path = p), "date")
  u <- ait_register_use("writing", "Edit intro", t, "Clarity", output_used = "partial",
                        files = "intro.qmd", date = "2026-01-05", path = p)
  log <- ait_log(p)
  expect_equal(log$uses$phase, "writing")
  expect_equal(log$uses$files, "intro.qmd")
})

test_that("single-element lists stay JSON arrays", {
  p <- new_project()
  t <- ait_tool("Claude", "Anthropic", path = p)
  u <- ait_register_use("writing", "Edit", t, "Clarity", risks = "one risk", path = p)
  rec <- jsonlite::read_json(file.path(p, "ai-log", "uses", paste0(u, ".json")))
  expect_type(rec$risks, "list")
  expect_length(rec$risks, 1)
})

test_that("prompts follow the storage policy", {
  p <- new_project()
  t <- ait_tool("Claude", "Anthropic", path = p)
  u <- ait_register_use("analysis", "Code", t, "Speed", path = p)
  long <- paste(rep("word", 100), collapse = " ")
  i_hash <- ait_log_interaction(u, long, path = p)
  i_ex <- ait_log_interaction(u, paste(long, "b"), store = "excerpt", path = p)
  i_none <- ait_log_interaction(u, paste(long, "c"), store = "none", path = p)
  ints <- ait_log(p)$interactions
  row <- function(id) ints[ints$id == id, ]
  expect_true(is.na(row(i_hash)$prompt))
  expect_equal(nchar(row(i_hash)$prompt_md5), 32)
  expect_equal(nchar(row(i_ex)$prompt), 200)
  expect_true(is.na(row(i_none)$prompt_md5))
})

test_that("personal data in full prompts triggers a warning", {
  p <- new_project()
  t <- ait_tool("Claude", "Anthropic", path = p)
  u <- ait_register_use("analysis", "Code", t, "Speed", path = p)
  expect_warning(ait_log_interaction(u, "Write to ana@example.org", store = "full", path = p),
                 "personal data")
  expect_silent(ait_log_interaction(u, "See 10.1136/bmj.g7015 and 0000-0001-7845-9506",
                                    store = "full", path = p))
})

test_that("verifications attach to existing uses", {
  p <- new_project()
  t <- ait_tool("Claude", "Anthropic", path = p)
  u <- ait_register_use("analysis", "Code", t, "Speed", path = p)
  expect_error(ait_verify("use-0000000000", "expert_review", verifier = "X", path = p), "not in the log")
  expect_error(ait_verify(u, "vibes", verifier = "X", path = p), "method")
  ait_verify(u, "rerun_analysis", "modified", verifier = "X", path = p)
  expect_equal(ait_log(p)$verifications$outcome, "modified")
})

test_that("the vocabulary has labels in English and Spanish", {
  for (v in c("phases", "output_used", "methods", "outcomes", "access")) {
    voc <- ait_vocabulary(v)
    expect_false(anyNA(voc$en))
    expect_false(anyNA(voc$es))
    expect_false(anyDuplicated(voc$id) > 0)
  }
})

test_that("the JSON Schema matches the vocabulary", {
  schema <- jsonlite::read_json(system.file("schema", "ai-log.schema.json", package = "aitrail"))
  phases <- unlist(schema$`$defs`$use$properties$phase$enum)
  expect_setequal(phases, ait_vocabulary("phases")$id)
  methods <- unlist(schema$`$defs`$verification$properties$method$enum)
  expect_setequal(methods, ait_vocabulary("methods")$id)
})

test_that("records written by the package have the schema's required fields", {
  schema <- jsonlite::read_json(system.file("schema", "ai-log.schema.json", package = "aitrail"))
  p <- ait_example()
  for (type in c("tool", "use", "interaction", "verification")) {
    required <- unlist(schema$`$defs`[[type]]$required)
    dir <- file.path(p, "ai-log", aitrail:::record_dirs[[type]])
    for (f in list.files(dir, full.names = TRUE)) {
      expect_true(all(required %in% names(jsonlite::read_json(f))), info = f)
    }
  }
})
