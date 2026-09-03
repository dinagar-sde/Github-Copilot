# PMMCWJC-9: AWS S3 Account Folder Creation

## Summary

Implement a Salesforce Apex integration that asynchronously requests creation of an AWS S3 folder for an Account and records the resulting folder path on that Account. The integration will use a named credential for the AWS endpoint, a future method for the callout, durable integration logging, and Apex tests with HTTP callout mocks.

## User Story

As an Account Manager, I want Salesforce to automatically call an AWS API to create a dedicated folder for an Account so that account-related documents can be organized and stored in AWS S3 without manual intervention. [PMMCWJC-9](https://dinagar4r.atlassian.net/browse/PMMCWJC-9)

## Acceptance Criteria

- Given an Account ID is passed to the integration service, the service sends a POST request to the AWS folder-creation API. [PMMCWJC-9](https://dinagar4r.atlassian.net/browse/PMMCWJC-9)
- The JSON request body is `{ "accountId": "<Salesforce Account Id>" }`. [PMMCWJC-9](https://dinagar4r.atlassian.net/browse/PMMCWJC-9)
- When AWS returns HTTP 200, Salesforce sets `Account.S3_Folder_Id__c` to `<AccountId>/`. [PMMCWJC-9](https://dinagar4r.atlassian.net/browse/PMMCWJC-9)
- The integration logs the HTTP status code and response body after receiving a response. [PMMCWJC-9](https://dinagar4r.atlassian.net/browse/PMMCWJC-9)
- Callout and record-update exceptions log the error message and stack trace. [PMMCWJC-9](https://dinagar4r.atlassian.net/browse/PMMCWJC-9)
- External callouts run asynchronously through a method annotated `@future(callout=true)`. [PMMCWJC-9](https://dinagar4r.atlassian.net/browse/PMMCWJC-9)

## Functional Requirements

- Accept one or more Salesforce Account IDs at the integration-service boundary.
- For each Account ID, request folder creation from the AWS endpoint using the required JSON payload.
- Set `S3_Folder_Id__c` only after an HTTP 200 response and derive its value as `<AccountId>/`; do not infer a value from the response body.
- Preserve the Account value when the callout returns a non-200 status or an exception occurs.
- Persist a success or failure audit record containing the Account reference, HTTP status when available, response body when available, error message, and stack trace for exceptions.

## Technical Context

- The repository is a Salesforce DX project with `force-app` as its default package directory and source API version 67.0. [sfdx-project.json](sfdx-project.json)
- The default metadata package currently has application, Aura, LWC, layout, flexipage, static-resource, and tab directories, but no Apex source directory or existing integration implementation. [force-app/main/default](force-app/main/default)
- The project provides `sfdx-lwc-jest` and ESLint scripts, but no Apex-specific test command is declared. [package.json](package.json)
- The linked technical design confirms the endpoint `https://t-1.amazonaws.com/create-folder`, content type `application/json`, HTTP 200 success contract, and future-method execution. [AWS S3 Folder Creation Integration - Technical Design](https://dinagar4r.atlassian.net/wiki/spaces/SD/pages/262165/AWS+S3+Folder+Creation+Integration+Technical+Design)

## Proposed Solution

Add a bulk-safe Apex service named `AWSService` with a public launcher accepting `Set<Id>` and a `@future(callout=true)` worker accepting `List<Id>`. The launcher is the single supported integration boundary and will be called by an `after insert` Account trigger for automatic creation. The worker will construct `{"accountId":"<Account Id>"}`, POST it through a named credential that represents the AWS host, and process each result independently so one failed Account does not prevent other Accounts in the asynchronous job from being attempted.

On HTTP 200, the worker will update the corresponding Account with `S3_Folder_Id__c = String.valueOf(accountId) + '/'`. It will create a durable `Integration_Log__c` record for every attempted callout. Success records will retain the status code and response body; non-200 and exception records will also record failure details, with exceptions including `getMessage()` and `getStackTraceString()`. This satisfies the audit requirement without exposing endpoint authentication or payload data through only transient debug logs.

Use a named credential, for example `AWS_S3_Folder_API`, and call a relative endpoint such as `callout:AWS_S3_Folder_API/create-folder`. Store the AWS base URL and authentication in the named credential rather than Apex. This centralizes endpoint configuration and keeps secrets out of source code.

This is the selected approach because it directly implements the ticket's required future-callout mechanism, supports bulk trigger execution within Salesforce limits, and provides durable operational evidence for both successful and failed integrations.

## Implementation Considerations

- Add `AWSService.cls` and `AWSServiceTest.cls` under `force-app/main/default/classes`; create the missing `classes` directory as part of implementation.
- Add an Account `after insert` trigger that gathers IDs and invokes the service launcher once per trigger context. The trigger must contain no callout or HTTP logic.
- Add `S3_Folder_Id__c` to the Account object metadata if it does not already exist in the target org; its required type and length are not specified.
- Add `Integration_Log__c` object metadata with fields sufficient for Account lookup, outcome, HTTP status, response body, error message, and stack trace. Field types and retention policy require confirmation.
- Configure and deploy the named credential separately from Apex, with the AWS host and approved authentication method. The linked design permits a named credential or Remote Site Setting, but this solution selects the named credential. [AWS S3 Folder Creation Integration - Technical Design](https://dinagar4r.atlassian.net/wiki/spaces/SD/pages/262165/AWS+S3+Folder+Creation+Integration+Technical+Design)
- Test HTTP 200, non-200, thrown callout exceptions, Account update failure, and a bulk insert using `HttpCalloutMock`. Assert payload shape, field updates, and persisted log content.
- Deploy through Salesforce CLI and run Apex tests in the target org. The existing npm unit-test command covers LWC tests only. [package.json](package.json)

## Dependencies and Risks

- AWS availability, DNS/network access, and the `/create-folder` contract are external dependencies. [AWS S3 Folder Creation Integration - Technical Design](https://dinagar4r.atlassian.net/wiki/spaces/SD/pages/262165/AWS+S3+Folder+Creation+Integration+Technical+Design)
- A named credential and its authentication configuration must exist before callouts can succeed.
- Future methods are subject to Salesforce asynchronous limits; a bulk Account insert must enqueue one job for the transaction rather than one job per record.
- Retrying a request after a timeout can create duplicate AWS folder requests unless the AWS API treats the Account ID as idempotent. Idempotency is not defined in the ticket.
- A persistent log object will grow over time; retention, field-level access, and response-body sensitivity must be defined before production deployment.

## Edge Cases

- Multiple Accounts are created in one transaction: submit one asynchronous job and process each ID independently.
- An Account already has `S3_Folder_Id__c` populated: do not enqueue a second folder-creation request unless an approved reprocessing rule is defined.
- AWS returns 200 with an empty or malformed response: update using `<AccountId>/`, because that is the explicitly required value, and log the response body.
- AWS returns 201, 202, 4xx, or 5xx: treat as unsuccessful because the confirmed success criterion is exactly HTTP 200; do not set the folder ID.
- The Account is deleted or inaccessible before the future job updates it: record the update failure with error and stack trace.
- A response or error exceeds the final log-field size: truncate according to the approved field limits while retaining status and Account reference.

## Open Questions

- What user action or field defines an Account as "selected for integration"? The proposed `after insert` trigger covers automatic creation, but no requirement defines manual selection or reprocessing.
- Does `S3_Folder_Id__c` already exist in the target org? If not, what type, length, field label, and field-level security are required?
- Is `Integration_Log__c` an approved object name, and what retention, access, and response-body redaction requirements apply?
- What authentication mechanism and credentials must the named credential use for AWS?
- Is the AWS create-folder API idempotent for the same Account ID, and what retry policy is approved for transient failures?
- Should HTTP 201 or 202 also represent success, or is HTTP 200 exclusively valid as currently stated?

## Sources

- [PMMCWJC-9: AWS S3 Account Folder Creation](https://dinagar4r.atlassian.net/browse/PMMCWJC-9): user story, description, acceptance criteria, priority, status, no Jira issue links, no attachments, and no comments.
- [AWS S3 Folder Creation Integration - Technical Design](https://dinagar4r.atlassian.net/wiki/spaces/SD/pages/262165/AWS+S3+Folder+Creation+Integration+Technical+Design): linked Confluence technical design; endpoint, request format, success status, Account update, logging, error handling, and configuration assumptions. It does not conflict with the Jira issue.
- [sfdx-project.json](sfdx-project.json): default package directory and Salesforce API version.
- [package.json](package.json): available linting and LWC test scripts.
- [force-app/main/default](force-app/main/default): inspected metadata-package structure; no existing Apex or integration metadata found.