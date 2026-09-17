# PMMCWJC-12: Opportunity Data Quality Automation

## Requirement Summary

As a Sales Manager, Salesforce must validate and standardize Opportunity records when they are created or updated, so that sales data is accurate and consistently maintained ([PMMCWJC-12](https://dinagar4r.atlassian.net/browse/PMMCWJC-12), Story, Priority: Medium, Status: To Do).

On Opportunity create or update, the automation must:

1. **Validate Close Date** — must not be in the past (PMMCWJC-12).
2. **Standardize Opportunity Name** — format `Account Name - Original Opportunity Name`, e.g. `Acme Corp - Renewal Opportunity` (PMMCWJC-12).
3. **Update Probability based on Stage** — fixed stage-to-probability mapping (PMMCWJC-12).
4. **Validate Amount** — must be greater than zero (PMMCWJC-12).
5. **Auto-populate Description** — when blank, set to `Opportunity created for <Account Name>`, e.g. `Opportunity created for Acme Corp` (PMMCWJC-12).

Data model (Confluence: [Salesforce Opportunity Data Quality Automation: Objects, Fields, and Relationships](https://dinagar4r.atlassian.net/wiki/spaces/SD/pages/15466497/Salesforce+Opportunity+Data+Quality+Automation+Objects+Fields+and+Relationships)):

- `Account`: `Name` (Text), `Id`.
- `Opportunity`: `Name`, `Id`, `AccountId` (Lookup to Account), `StageName` (Picklist), `CloseDate` (Date), `Amount` (Currency), `Probability` (Percent), `Description` (Long Text Area).
- Relationship: Account (1) → Opportunity (many).

Repository context: this is a fresh SFDX project ([sfdx-project.json](sfdx-project.json), package directory `force-app`, sourceApiVersion 67.0). The [classes](force-app/main/default/classes), [triggers](force-app/main/default/triggers), and [flows](force-app/main/default/flows) folders are empty — there is no existing Apex trigger, handler, or automation for Opportunity, so this will be greenfield code.

## Acceptance Criteria

Derived from the business requirements in PMMCWJC-12:

1. Creating or updating an Opportunity with a `CloseDate` in the past is blocked with the error message: **"Close Date cannot be in the past."**
2. On create or update, the Opportunity `Name` is rewritten to `<Account Name> - <Original Opportunity Name>`.
3. On create or update, `Probability` is set from `StageName` as follows (PMMCWJC-12):

   | Stage | Probability |
   | --- | --- |
   | Prospecting | 10% |
   | Qualification | 25% |
   | Proposal/Price Quote | 50% |
   | Negotiation/Review | 75% |
   | Closed Won | 100% |
   | Closed Lost | 0% |

4. Creating or updating an Opportunity with `Amount` not greater than zero is blocked with the error message: **"Amount must be greater than zero."**
5. On create or update, if `Description` is blank it is set to `Opportunity created for <Account Name>`.
6. All rules apply consistently on both insert and update, and behave correctly for bulk operations (multiple records in one transaction) (bulk-processing principle, Confluence: [Design Pattern for Apex Solution Design](https://dinagar4r.atlassian.net/wiki/spaces/SD/pages/15630337/Design+Pattern+for+Apex+Solution+Design)).

## Technical Design

Selected approach: a **bulkified before-trigger with a modular Trigger → Handler → Orchestration architecture**, per the confirmed design pattern in Confluence: [Design Pattern for Apex Solution Design](https://dinagar4r.atlassian.net/wiki/spaces/SD/pages/15630337/Design+Pattern+for+Apex+Solution+Design).

Rationale: all five rules are record-local validations and field defaults/derivations, so a **before** trigger is sufficient — field changes apply without extra DML, and validations use `addError` to block the save. A flow is not selected because the confirmed organizational standard for this work is the Apex trigger framework pattern (Confluence design-pattern page), and the repo has no existing flow automation to extend ([flows](force-app/main/default/flows) is empty).

New artifacts (greenfield — folders are currently empty):

- `force-app/main/default/triggers/OpportunityTrigger.trigger` — event entry point only.
- `force-app/main/default/classes/OpportunityTriggerHandler.cls` — central controller.
- `force-app/main/default/classes/OpportunityTriggerHandlerTest.cls` — unit tests.
- Corresponding `.trigger-meta.xml` / `.cls-meta.xml` files at API version 67.0 ([sfdx-project.json](sfdx-project.json)).

Implementation points:

1. **Trigger layer** (`OpportunityTrigger`): fires on `before insert, before update`; contains no business logic; delegates `Trigger.new` to the handler (Confluence design-pattern page, Trigger Layer responsibilities).
2. **Handler layer** (`OpportunityTriggerHandler`): single public entry point (e.g. `run(List<Opportunity> newOpportunities)`); controls execution sequence by invoking the orchestration method (Confluence design-pattern page, Handler Layer responsibilities).
3. **Orchestration + processing methods**: one orchestration method that calls single-responsibility processing methods in this order:
   1. `validateCloseDate` — `addError('Close Date cannot be in the past.')` when `CloseDate < Date.today()`.
   2. `validateAmount` — `addError('Amount must be greater than zero.')` when `Amount` is null or `<= 0` (*Assumption*: null Amount is treated as not greater than zero — see Open Questions).
   3. `standardizeName` — sets `Name = Account.Name + ' - ' + original Name` (*Assumption*: to stay idempotent on updates, strip an existing `<Account Name> - ` prefix before re-applying — see Open Questions).
   4. `updateProbability` — applies the stage-to-probability mapping from Acceptance Criterion 3 (*Assumption*: stages not in the mapping leave `Probability` unchanged — see Open Questions).
   5. `populateDescription` — when `Description` is blank, sets `Description = 'Opportunity created for ' + Account.Name`.
4. **Bulkified Account lookup**: before running the name/description methods, collect all non-null `AccountId` values from `Trigger.new` and query `SELECT Id, Name FROM Account WHERE Id IN :accountIds` once into a `Map<Id, Account>`; no SOQL inside loops (bulk-processing principle, Confluence design-pattern page). Records with null `AccountId` skip the name-prefix and description rules (*Assumption* — see Open Questions).
5. **Error surfacing**: validations use `SObject.addError()` on the offending record so only invalid records in a bulk batch fail while valid records commit (standard Apex behavior).

Payloads: no request/response/event or integration payload changes — this is internal Apex record automation with no APIs, callouts, or platform events.

## Error Handling

- **Validation failures**: block the record via `addError` with the exact messages confirmed in PMMCWJC-12:
  - `"Close Date cannot be in the past."`
  - `"Amount must be greater than zero."`
- **Bulk behavior**: `addError` is per-record; other records in the same transaction still save (standard Apex trigger behavior).
- **Missing Account lookup** (null `AccountId`): name standardization and description auto-population are skipped for that record; validations still apply (*Assumption* — see Open Questions).
- **Stages outside the confirmed mapping**: probability left unchanged (*Assumption* — see Open Questions).
- No callouts, DML, or async work exist in this design, so no retry/rollback logging pattern is required. No repository-established error-logging framework exists to reuse ([classes](force-app/main/default/classes) is empty).

## Security

- Triggers execute in system context, so the rules apply uniformly across UI, data import, and API-created records (*Assumption*: this uniform enforcement is intended — see Open Questions).
- The handler will be declared `inherited sharing` (*Assumption*: no repository-established sharing convention exists, [classes](force-app/main/default/classes) is empty; the design only reads `Account.Name` and writes Opportunity fields, so sharing impact is minimal).
- No credentials, tokens, external endpoints, or user-supplied free-text is persisted beyond the confirmed field writes (PMMCWJC-12); no injection or XSS surface is introduced.
- No CRUD/FLS-sensitive custom fields are involved; all fields touched are Opportunity/Account standard fields (Confluence objects-and-fields page).

## Unit Testing Notes

- Salesforce requires ≥75% Apex coverage org-wide; target ≥90% on the new handler class (*Assumption*: no repo test convention exists — [classes](force-app/main/default/classes) is empty).
- Create an `OpportunityTriggerHandlerTest` class using `@IsTest` with its own test data (Account + Opportunities inserted in the test).
- Test cases to cover:
  1. Insert with past `CloseDate` → expected `addError` message (assert via `Database.SaveResult` / `Test.startTest` + `DmlException` message check).
  2. Insert with `Amount` = 0 and negative → expected `addError` message.
  3. Name standardization on insert produces `<Account Name> - <Name>`.
  4. All six stage-to-probability mappings from Acceptance Criterion 3.
  5. Blank `Description` auto-populated; non-blank `Description` preserved.
  6. Update path: same rules re-applied on update.
  7. Bulk test with 200 Opportunities in one DML statement to verify no SOQL-in-loop governor-limit issues.
  8. Mixed-validity bulk batch: valid records commit, invalid records fail (partial-success via `Database.insert(list, false)`).

## Open Questions

1. Should name standardization be **idempotent** on update (i.e., strip an existing `Account Name - ` prefix before re-applying) to avoid `Acme Corp - Acme Corp - Renewal Opportunity`? PMMCWJC-12 does not specify update behavior for already-standardized names.
2. Should the Close Date validation fire on **every** update, or only when `CloseDate` itself changes? On every update, editing any field of an old Opportunity with a past Close Date would block the save.
3. Should null `Amount` be treated as an error (not greater than zero), or is a blank Amount allowed?
4. What probability applies to stages **not** in the confirmed mapping (e.g., custom stages)? Assumed: leave unchanged.
5. Should probability overwrite a user-entered `Probability` on every save, or only when `StageName` changes?
6. What should happen when `AccountId` is blank (Private Opportunity)? Assumed: skip name prefix and description auto-population.

## Sources

- Jira: [PMMCWJC-12 — Opportunity Data Quality Automation](https://dinagar4r.atlassian.net/browse/PMMCWJC-12) (no attachments, comments, or linked issues).
- Confluence: [Salesforce Opportunity Data Quality Automation: Objects, Fields, and Relationships](https://dinagar4r.atlassian.net/wiki/spaces/SD/pages/15466497/Salesforce+Opportunity+Data+Quality+Automation+Objects+Fields+and+Relationships) (linked from PMMCWJC-12).
- Confluence: [Design Pattern for Apex Solution Design](https://dinagar4r.atlassian.net/wiki/spaces/SD/pages/15630337/Design+Pattern+for+Apex+Solution+Design) (linked from PMMCWJC-12).
- Repository: [sfdx-project.json](sfdx-project.json), [force-app/main/default/classes](force-app/main/default/classes), [force-app/main/default/triggers](force-app/main/default/triggers), [force-app/main/default/flows](force-app/main/default/flows) (all empty — greenfield implementation).
