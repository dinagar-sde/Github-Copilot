# PMMCWJC-12: Opportunity Data Quality Automation

## Requirement Summary

Salesforce must validate and standardize Opportunity records when they are created or updated so that sales data remains accurate and consistent ([PMMCWJC-12](https://dinagar4r.atlassian.net/browse/PMMCWJC-12)). The automation applies to the standard `Opportunity` object and uses the related `Account` name. The confirmed fields and relationship are documented in [Salesforce Opportunity Data Quality Automation: Objects, Fields, and Relationships](https://dinagar4r.atlassian.net/wiki/spaces/SD/pages/15466497/Salesforce+Opportunity+Data+Quality+Automation+Objects+Fields+and+Relationships).

## Acceptance Criteria

- On Opportunity create or update, reject a `CloseDate` in the past with `Close Date cannot be in the past.` ([PMMCWJC-12](https://dinagar4r.atlassian.net/browse/PMMCWJC-12)).
- On Opportunity create or update, set `Name` to `Account Name - Original Opportunity Name` ([PMMCWJC-12](https://dinagar4r.atlassian.net/browse/PMMCWJC-12)).
- Set `Probability` from `StageName`: Prospecting `10%`, Qualification `25%`, Proposal/Price Quote `50%`, Negotiation/Review `75%`, Closed Won `100%`, and Closed Lost `0%` ([PMMCWJC-12](https://dinagar4r.atlassian.net/browse/PMMCWJC-12)).
- On Opportunity create or update, reject an `Amount` that is not greater than zero with `Amount must be greater than zero.` ([PMMCWJC-12](https://dinagar4r.atlassian.net/browse/PMMCWJC-12)).
- If `Description` is blank, populate it as `Opportunity created for Account Name` ([PMMCWJC-12](https://dinagar4r.atlassian.net/browse/PMMCWJC-12)).
- Processing must support both insert and update events and multiple records per transaction ([PMMCWJC-12](https://dinagar4r.atlassian.net/browse/PMMCWJC-12); [Design Pattern for Apex Solution Design](https://dinagar4r.atlassian.net/wiki/spaces/SD/pages/15630337/Design+Pattern+for+Apex+Solution+Design)).

## Technical Design

- Add a `before insert, before update` trigger on `Opportunity` under `force-app/main/default/triggers/`. The trigger only delegates `Trigger.new` and, where needed, `Trigger.oldMap` to a handler, following the linked Apex design pattern.
- Add an Opportunity handler under `force-app/main/default/classes/` as the central controller. Its orchestration method invokes focused processing methods in a deterministic order: load Account names, validate dates and amounts, standardize names, set probability, then populate descriptions.
- Query all referenced Accounts once using the distinct `AccountId` values from `Trigger.new`, and store results in a map. This keeps processing bulk-safe and supports the required Account-to-many-Opportunity relationship ([Salesforce Opportunity Data Quality Automation: Objects, Fields, and Relationships](https://dinagar4r.atlassian.net/wiki/spaces/SD/pages/15466497/Salesforce+Opportunity+Data+Quality+Automation+Objects+Fields+and+Relationships)).
- Use `addError` on the individual Opportunity record for the two confirmed validation messages. A validation error prevents the transaction from saving and is surfaced to the user.
- Use a stage-to-probability map for the six confirmed stage values. Do not issue DML from the trigger path; before-save field changes are written by Salesforce.
- For name standardization, retain the incoming value as the original name for the current transaction and construct the requested `Account Name - Original Opportunity Name` value. **Assumption:** update behavior must be made idempotent by removing an existing recognized Account prefix before reapplying it; this needs confirmation in the open questions.
- Populate `Description` only when it is blank, using the related Account name. **Assumption:** a missing Account relationship is not expected because the story requires an Account name; the implementation should avoid a null dereference and leave the dependent fields unchanged until the expected behavior is confirmed.
- No request, response, event, or persisted payload shape changes apply. The design updates standard Opportunity fields only: `Name`, `Probability`, and `Description`, and validates `CloseDate` and `Amount` ([Salesforce Opportunity Data Quality Automation: Objects, Fields, and Relationships](https://dinagar4r.atlassian.net/wiki/spaces/SD/pages/15466497/Salesforce+Opportunity+Data+Quality+Automation+Objects+Fields+and+Relationships)).
- Implement against the repository's Salesforce DX package at `force-app/main/default/`, using the configured source API version `67.0` ([sfdx-project.json](sfdx-project.json)).

## Error Handling

- Use the exact Jira-specified messages for invalid Close Date and Amount ([PMMCWJC-12](https://dinagar4r.atlassian.net/browse/PMMCWJC-12)).
- Validate each record independently so one invalid record receives a record-level error and all errors are reported together by Salesforce bulk processing.
- Avoid SOQL and DML inside record loops, and handle an empty Account result without throwing an unhandled exception. The exact behavior for an Opportunity without an Account is unresolved.
- The repository contains no existing Apex error-handling or logging convention: `force-app/main/default/classes/` and `force-app/main/default/triggers/` are currently empty (repository inspection, 2026-09-04).

## Security

- Use standard Salesforce object and field permissions through the normal transaction context; no requirement authorizes bypassing sharing, CRUD, or FLS controls ([PMMCWJC-12](https://dinagar4r.atlassian.net/browse/PMMCWJC-12)).
- Query only the Account fields needed for this automation (`Id`, `Name`) and update only the standard Opportunity fields named in the story ([Salesforce Opportunity Data Quality Automation: Objects, Fields, and Relationships](https://dinagar4r.atlassian.net/wiki/spaces/SD/pages/15466497/Salesforce+Opportunity+Data+Quality+Automation+Objects+Fields+and+Relationships)).
- No external integrations, credentials, secrets, or new data storage are introduced. Whether explicit CRUD/FLS checks are required for Apex in this org is an open question.

## Unit Testing Notes

- Add an Apex test class under `force-app/main/default/classes/` covering insert and update paths, with bulk inputs containing valid and invalid records.
- Assert the exact Close Date and Amount error messages, including that invalid records are not saved.
- Assert each of the six stage-to-probability mappings.
- Assert Account-prefixed names and blank-description population for an Account with a representative name such as `Acme Corp`.
- Assert that a nonblank Description is preserved.
- Assert bulk behavior with multiple Opportunities related to multiple Accounts and confirm only one Account query is needed where query-count assertions are practical.
- Add tests for null or missing Account handling and repeated updates once the expected behavior is confirmed.
- The package provides Salesforce DX and LWC Jest scripts, but no Apex test implementation currently exists in the repository ([package.json](package.json)).

## Open Questions

- On update, how should the automation distinguish the original Opportunity name from a name previously standardized by this automation? This determines the idempotent prefix-handling rule.
- What should happen when `AccountId` is null or the referenced Account cannot be found: add an error, leave dependent fields unchanged, or use another source name?
- Does a null `CloseDate` pass validation, or must Close Date be required by this automation?
- Does a null `Amount` count as invalid, and should zero and negative values share the same error behavior?
- Should blank Description mean only `null`/empty text, or also whitespace-only text?
- Should Probability be overwritten on every update when `StageName` is one of the six mapped values, including when a user intentionally sets a different probability?
- Are the six stage labels guaranteed to match the org's Opportunity stage picklist exactly, and should unmapped stages retain their existing Probability?
- Are explicit CRUD/FLS checks required by the project's Salesforce security standards?

## Sources

- Jira story: [PMMCWJC-12](https://dinagar4r.atlassian.net/browse/PMMCWJC-12), including its description, acceptance requirements, and current metadata. No comments or directly linked Jira issues were present.
- Linked Confluence page: [Salesforce Opportunity Data Quality Automation: Objects, Fields, and Relationships](https://dinagar4r.atlassian.net/wiki/spaces/SD/pages/15466497/Salesforce+Opportunity+Data+Quality+Automation+Objects+Fields+and+Relationships).
- Linked Confluence page: [Design Pattern for Apex Solution Design](https://dinagar4r.atlassian.net/wiki/spaces/SD/pages/15630337/Design+Pattern+for+Apex+Solution+Design).
- Repository context: [sfdx-project.json](sfdx-project.json), [package.json](package.json), and empty `force-app/main/default/classes/` and `force-app/main/default/triggers/` directories.