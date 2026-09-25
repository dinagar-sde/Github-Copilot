---
description: "Use when reviewing or writing Salesforce Apex for bulkification and common failure modes. Requires anti-pattern findings to include why they fail and BAD/GOOD examples."
name: "Apex Anti-Patterns"
applyTo: "force-app/main/default/**/*.cls, force-app/main/default/**/*.trigger, force-app/main/default/**/*.cls-meta.xml, force-app/main/default/**/*.trigger-meta.xml"
---

# Apex Anti-Patterns

For each finding, state the anti-pattern, why it fails, show the BAD example, and provide the GOOD replacement.

| Anti-pattern | Why it fails | BAD example | GOOD example |
|---|---|---|---|
| SOQL in loops | Exceeds query limits and scales with input size. | `for (Id id : setIds) { [SELECT Id FROM Account WHERE Id = :id]; }` | Query once with `WHERE Id IN :setIds`, then index results by Id. |
| DML in loops | Exceeds DML limits and creates partial-transaction risk. | `for (Account account : listAccounts) { update account; }` | Add records to `listAccountsToUpdate`, then perform one DML operation. |
| Missing sharing declarations | Record visibility depends on implicit caller context. | `public class AccountService {}` | `public with sharing class AccountService {}` or justified `inherited sharing`. |
| Hardcoded IDs | IDs differ between orgs and environments. | `Id recordTypeId = '012000000000000AAA';` | Resolve metadata by stable developer name or configuration. |
| Unbulkified triggers | Single-record assumptions fail during data loads. | `update Trigger.new[0];` | Pass all trigger records to a bulkified domain or service. |
| Dynamic SOQL injection | Untrusted input can alter queries or expose data. | `Database.query('SELECT Id FROM Account WHERE Name = \' ' + name + '\'');` | Bind values and allowlist dynamic identifiers. |

Also check for recursive trigger side effects, synchronous trigger callouts, swallowed exceptions, and tests that depend on org data.
