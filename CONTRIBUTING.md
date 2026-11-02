# Contributing

Thank you for helping improve aitrail. Bug reports with a small example, new audit rules, translations of the vocabularies and disclosures, and ideas from journals, ethics committees or research offices are welcome.

## Running the tests

- `R CMD build . && R CMD check --as-cran aitrail_*.tar.gz`
- or `devtools::check()`.

The tests never use the network: reference checks run against recorded responses.

## Small changes (welcome as pull requests)

- Documentation, examples and the website.
- Translations and wording of the disclosure statements in `inst/extdata/i18n.json`.
- Compatibility fixes, as long as every test still passes unchanged.

## Changes to discuss in an issue first

- The vocabularies in `inst/extdata/vocabulary.json` and the JSON Schema in `inst/schema/`: logs written by earlier versions must stay readable.
- The audit rules in `R/audit.R` and the matching logic in `R/references.R`.
- New dependencies: aitrail deliberately depends only on base R and jsonlite.

The design notes are in [`dev/DESIGN.md`](dev/DESIGN.md).

Tests are never weakened or deleted to make them pass.
