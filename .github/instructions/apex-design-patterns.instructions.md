---
description: "Use when choosing or reviewing Salesforce Apex architecture and design patterns. Covers Service, Selector, Strategy, Factory, Queueable, Batch, and Unit of Work decisions."
name: "Apex Design Patterns"
applyTo: "force-app/main/default/**/*.cls, force-app/main/default/**/*.trigger, force-app/main/default/**/*.cls-meta.xml, force-app/main/default/**/*.trigger-meta.xml"
---

# Apex Design Patterns

Choose the narrowest pattern that owns the behavior by following this decision tree:

1. Does the code coordinate a business use case across validation, queries, domain logic, and DML? Use a **Service**.
2. Is the responsibility reusable, security-aware query logic? Use a **Selector**.
3. Are multiple interchangeable algorithms selected by a business rule? Define a **Strategy** interface and implementations.
4. Does object construction vary by type, configuration, or record state? Use a **Factory** and keep branching out of callers.
5. Is this a bounded unit of deferred work, optionally with callouts or chaining? Use **Queueable** and define retry behavior.
6. Can the work exceed one transaction's limits or process a large query result? Use **Batch** with bulk scope handling.
7. Does one use case coordinate related inserts, updates, and deletes with shared commit behavior? Use **Unit of Work** when the repository already provides that abstraction; do not introduce a framework for one operation.

Keep triggers as event adapters: one trigger per object, no queries or DML in the trigger body, and delegate to the selected domain or service.
