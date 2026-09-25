---
name: apex-generate
description: 'Generate, refactor, or review production-safe Salesforce Apex classes and triggers. Use for services, selectors, domains, batch, queueable, schedulable, invocable, REST resources, DTOs, utilities, interfaces, abstract classes, exceptions, and matching tests.'
argument-hint: 'Describe the Apex change, target object, behavior, and any solution-design or acceptance-criteria document.'
user-invocable: true
disable-model-invocation: false
---

# Platform Apex Generate

Create or modify Apex in the repository's `force-app/main/default/classes` and `triggers` packages. Treat the request, approved design, and existing code as the source of truth. Do not invent business rules.

## When to Use

- Create a new Apex class or trigger.
- Refactor, fix, or review `.cls`, `.cls-meta.xml`, or `.trigger` files.
- Choose or apply a service, selector, domain, batch, queueable, schedulable, invocable, REST, DTO, utility, interface, abstract, exception, or trigger pattern.
- Apply Apex security, bulkification, governor-limit, SOQL, DML, async, or error-handling rules.
- Generate focused tests with the related `platform-apex-test-generate` skill when it is available.

## Required Inputs

Before authoring, identify:

1. The requested behavior and acceptance criteria.
2. The target object(s), fields, relationships, sharing model, and API version.
3. The public entry point and caller context: UI, integration, trigger, Flow, batch, or scheduled execution.
4. Existing classes, triggers, custom metadata, permissions, and repository conventions that the change must use.
5. Data-volume, transaction, ordering, retry, and failure-handling expectations.

If a solution-design document is supplied, read it first and stop on material ambiguity. For production changes, request explicit approval when the governing agent requires it.

## Workflow

### 1. Inspect and classify

- Locate the smallest relevant implementation surface and neighboring tests.
- Determine whether the behavior belongs in a trigger, domain, service, selector, async job, or integration boundary.
- Reuse existing abstractions and names. Do not create a second trigger for the same object.
- Choose the narrowest pattern that satisfies the requirement; avoid speculative frameworks.

### 2. Design for safe execution

- Declare sharing explicitly on every class: prefer `with sharing` or `inherited sharing`; use `without sharing` only with a documented, justified system-context requirement.
- Enforce object and field security at the trust boundary. Prefer user-mode SOQL/DML where supported; otherwise use explicit describe checks or an established repository security utility.
- Bulkify all collection entry points. Never query or perform DML inside loops.
- Query only needed fields, use selective filters, and bind values. Never concatenate untrusted input into dynamic SOQL or SOSL.
- Use maps and sets for relationship lookups and deduplication. Preserve deterministic ordering where callers depend on it.
- Keep transactions within governor limits. Choose Queueable, Batchable, or Schedulable deliberately and make retries and partial failure behavior explicit.
- Validate required inputs before DML, collect actionable errors, and avoid swallowing exceptions. Never add `System.debug` unless explicitly required.
- Keep trigger logic thin and one-trigger-per-object; delegate behavior to a domain or service class.

### 3. Author

- Start from the closest template in `./assets/` and adapt it to the approved behavior.
- Match repository naming, visibility, constructor patterns, API version, and metadata layout.
- Add concise ApexDoc to public classes and methods when the contract is not obvious.
- Keep DTOs serializable and stable; keep integration payload parsing and response mapping at the boundary.
- Make methods small enough to test independently without weakening encapsulation.
- Create or update focused tests through `platform-apex-test-generate` when available. Tests must cover success, bulk input, no-op or empty input, validation failures, security-sensitive behavior, and async execution where relevant.

### 4. Validate

Run the narrowest available checks before broad checks:

1. Format changed Apex with the repository formatter if available.
2. Compile or deploy-check the changed classes and triggers with Salesforce CLI or the repository's validation command.
3. Run the focused Apex tests, then the broader suite when the change crosses shared boundaries.
4. Review for CRUD/FLS, sharing, injection, governor limits, recursion, mixed DML, async limits, and test isolation.

Do not deploy to an org or modify production unless explicitly requested. Report unavailable prerequisites instead of installing tooling.

## Pattern Selection

| Need | Pattern |
|---|---|
| Orchestrate a business use case | Service |
| Centralize reusable queries | Selector |
| Enforce object lifecycle rules | Domain |
| Process a large dataset | Batchable |
| Defer a bounded unit of work | Queueable |
| Run on a schedule | Schedulable |
| Expose an invocable Flow action | Invocable |
| Expose an HTTP endpoint | REST resource |
| Carry typed data across boundaries | DTO |
| Stateless reusable behavior | Utility |
| Define a contract or extension point | Interface or abstract class |
| Represent a recoverable domain failure | Exception |
| React to record events | Thin trigger delegating to domain/service |

Use the corresponding template in `./assets/` and consult `./references/` for style examples.

## Output Report

Return:

- A concise summary of behavior implemented or reviewed.
- Changed and created files with their purpose.
- Validation commands and results, or clearly reported unavailable checks.
- Security, limit, async, and data-model assumptions.
- Follow-up risks or decisions that still require user approval.

For review requests, list findings first, ordered by severity, with file links and concise remediation guidance. If no findings exist, say so and state remaining test gaps or residual risk.
