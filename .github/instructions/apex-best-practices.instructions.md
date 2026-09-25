---
description: "Use when writing, refactoring, or reviewing Salesforce Apex classes, triggers, and their metadata. Enforces naming conventions, ApexDoc, sharing, API version, and formatting standards."
name: "Apex Best Practices"
applyTo: ["force-app/main/default/**/*.cls", "force-app/main/default/**/*.trigger", "force-app/main/default/**/*.cls-meta.xml", "force-app/main/default/**/*.trigger-meta.xml"]
---

# Apex Best Practices

## Naming

- Use descriptive names that reflect the business responsibility.
- Prefix collection variables and parameters with their collection type: `listAccounts`, `setAccountIds`, and `mapAccountsById`.
- Use `is`, `are`, or `has` for Boolean variables, properties, and methods: `isActive`, `areEligible`, and `hasAccess`.
- Use PascalCase for classes, interfaces, exceptions, and enums; use camelCase for methods, variables, and parameters.
- Keep trigger names in the form `<Object>Trigger` and maintain one trigger per object.
- Preserve Salesforce API names exactly for objects, fields, relationships, and metadata members.

## ApexDoc

- Add concise ApexDoc to public or global classes and methods when their contract, side effects, or integration behavior is not obvious.
- Document parameters, return values, thrown exceptions, sharing assumptions, and asynchronous behavior when relevant.
- Keep documentation factual and synchronized with the implementation; do not restate self-evident code.

## Sharing and Security

- Declare sharing explicitly on every class; prefer `with sharing` or `inherited sharing`.
- Use `without sharing` only when system-context behavior is required and document the reason in ApexDoc.
- Enforce CRUD and field-level security at the trust boundary. Prefer user-mode SOQL and DML where supported, otherwise use the repository's established security utility.
- Bind dynamic SOQL and SOSL values. Allowlist any dynamic object, field, or sort identifiers.
- Do not expose implementation details, sensitive fields, or raw exception messages through REST, Flow, or other public boundaries.

## API Version

- Preserve the API version of existing metadata unless the requirement explicitly changes it.
- Use the project's configured API version for new classes and triggers.
- Do not raise the API version as part of an unrelated refactor.
- When an API-version change is required, document the compatibility impact and validate all affected syntax and platform behavior.

## Formatting and Implementation

- Follow the repository's Prettier and Apex formatter configuration.
- Use four spaces for indentation and keep one statement per line.
- Keep braces and blank lines consistent with neighboring Apex files.
- Keep triggers thin and delegate business logic to a domain or service class.
- Bulkify collection entry points; never perform SOQL or DML inside loops.
- Use maps and sets for lookups and deduplication, and select only fields required by the behavior.
- Do not add `System.debug` statements unless explicitly required.
