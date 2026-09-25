# Apex Review Checklist

Use this checklist after implementation and before reporting completion.

## Correctness

- Requirements and acceptance criteria are mapped to methods and tests.
- Empty, null, duplicate, and mixed-validity inputs have defined behavior.
- Trigger context and recursion behavior are explicit.
- Async jobs are idempotent or document their retry behavior.

## Security

- Sharing is explicit and justified.
- CRUD/FLS is enforced at the trust boundary.
- SOQL/SOSL is bound and dynamic identifiers are allowlisted.
- REST, invocable, and global APIs validate input and avoid leaking internals.

## Limits and data access

- No SOQL or DML occurs in loops.
- Queries select only needed fields and filter selectively.
- Collection sizes, callouts, heap, CPU, and async chaining are considered.
- Partial success uses `Database` methods only when the business contract permits it.

## Tests and delivery

- Tests are isolated, deterministic, and use `Test.startTest()` around the unit under test.
- Tests cover success, bulk behavior, no-op input, validation errors, and relevant permission or async paths.
- Changed metadata and tests are included in the report.
- Validation results and unavailable prerequisites are stated plainly.
