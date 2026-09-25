---
description: "Use when writing or reviewing Salesforce Apex security boundaries. Covers USER_MODE, CRUD/FLS, Security.stripInaccessible(), SOQL injection prevention, XSS mitigation, and sharing."
name: "Apex Security Guide"
applyTo: "force-app/main/default/**/*.cls, force-app/main/default/**/*.trigger, force-app/main/default/**/*.cls-meta.xml, force-app/main/default/**/*.trigger-meta.xml"
---

# Apex Security Guide

- Prefer `WITH USER_MODE` for SOQL and user-mode DML where supported and appropriate to the caller contract.
- Otherwise enforce CRUD and field-level security explicitly or use the repository's established security abstraction.
- Use `Security.stripInaccessible()` before returning or persisting data when graceful removal of inaccessible fields is required.
- Bind every dynamic SOQL and SOSL value. Allowlist dynamic object names, field names, and sort directions; never accept them directly from a request.
- For REST, Visualforce, and other HTML-producing boundaries, encode output and do not reflect untrusted input to prevent XSS.
- Return stable, non-sensitive error responses at external boundaries. Do not expose raw exception messages, secrets, or internal identifiers.
- Declare sharing explicitly on every class. Prefer `with sharing` or `inherited sharing`; document any justified `without sharing` usage.
