# aitrail 0.1.0

* First release.
* AI-use log per project in `ai-log/`, one JSON file per record, with a published JSON Schema: `ait_init()`, `ait_tool()`, `ait_register_use()`, `ait_log_interaction()`, `ait_verify()`, `ait_log()`.
* Controlled vocabularies of project phases, verification methods and outcomes, in English and Spanish: `ait_vocabulary()`.
* Reference checks against Crossref and DataCite: `ait_check_references()`.
* Audit of gaps in human oversight with documented rules: `ait_audit()`, `ait_audit_rules()`.
* Disclosure statements in English and Spanish and a self-contained HTML report: `ait_disclosure()`, `ait_report()`.
