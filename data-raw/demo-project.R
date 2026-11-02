# Builds inst/extdata/demo-project: the AI-use log of a fictitious study.
# All people, tasks and dates are invented. Run from the package root:
#   Rscript data-raw/demo-project.R
devtools::load_all(".")

out <- "inst/extdata/demo-project"
unlink(out, recursive = TRUE)
dir.create(out, recursive = TRUE)
ait_init(out, title = "Attitudes to open data among early-career researchers (synthetic example)")

gpt <- ait_tool("ChatGPT", provider = "OpenAI", model = "GPT-4o", version = "2024-08-06",
                access = "web", data_retention = "Team plan; conversations not used for training",
                path = out)
claude <- ait_tool("Claude", provider = "Anthropic", model = "Claude Sonnet 4",
                   access = "web", path = out)
deepl <- ait_tool("DeepL", provider = "DeepL SE", access = "integrated", path = out)

screen <- ait_register_use("literature_review", "Summarise 60 abstracts for first-pass screening",
  tool = gpt, purpose = "Speed up title and abstract screening",
  output_used = "partial", person = "A. Researcher", date = "2026-02-10",
  risks = "summaries may omit exclusion criteria", path = out)
suggest <- ait_register_use("literature_review", "Suggest further studies on data-sharing attitudes",
  tool = gpt, purpose = "Find studies missed by the database search",
  output_used = "none", person = "A. Researcher", date = "2026-02-12",
  risks = "possible invented citations", path = out)
code <- ait_register_use("analysis", "Draft R code for the ordinal regression models",
  tool = claude, purpose = "Write analysis code faster",
  output_used = "substantial", person = "A. Researcher", date = "2026-04-03",
  files = c("analysis/02-models.R"), path = out)
discussion <- ait_register_use("writing", "Improve the clarity of the discussion section",
  tool = gpt, purpose = "Language and structure suggestions",
  output_used = "partial", person = "A. Researcher", date = "2026-05-20",
  files = "manuscript/discussion.qmd", path = out)
abstract <- ait_register_use("translation_editing", "Translate the abstract into Spanish",
  tool = deepl, purpose = "Spanish abstract required by the journal",
  output_used = "substantial", person = "A. Researcher", date = "2026-06-01", path = out)

ait_log_interaction(screen, prompt = "Summarise each abstract in two sentences, noting population and design: ...",
  summary = "60 two-sentence summaries", timestamp = as.POSIXct("2026-02-10 10:15", tz = "UTC"), path = out)
ait_log_interaction(code, prompt = "Write R code to fit a cumulative link model of attitude (5 levels) on career stage and discipline, with random intercepts for institution.",
  summary = "Code using ordinal::clmm()", store = "excerpt",
  timestamp = as.POSIXct("2026-04-03 16:40", tz = "UTC"), path = out)

ait_verify(screen, "source_check", "modified", verifier = "A. Researcher",
  notes = "Checked all 60 against the abstracts; 7 summaries corrected", date = "2026-02-11", path = out)
ait_verify(code, "rerun_analysis", "modified", verifier = "A. Researcher",
  notes = "Reran on the data; fixed the link function and the reference level", date = "2026-04-04", path = out)
ait_verify(discussion, "expert_review", "modified", verifier = "B. Supervisor",
  notes = "Two suggested sentences overstated the findings and were removed", date = "2026-05-25", path = out)
ait_verify(abstract, "expert_review", "accepted", verifier = "C. Co-author",
  date = "2026-06-02", path = out)

# Fixed creation times, so the example does not change each time it is built.
for (f in list.files(file.path(out, "ai-log"), pattern = "\\.json$", recursive = TRUE, full.names = TRUE)) {
  rec <- jsonlite::read_json(f)
  rec$created <- "2026-06-15T09:00:00Z"
  jsonlite::write_json(rec, f, auto_unbox = TRUE, pretty = TRUE, null = "null", na = "null", digits = NA)
}
