# PMMCWJC-9: AWS S3 Account Folder Creation

## Summary

Implement an asynchronous Salesforce-to-AWS REST integration that creates an S3 folder for an Account, then stores the resulting Account-based folder path on that Account. The integration must record HTTP outcomes and failures without blocking the initiating user action.

## User Story

As an Account Manager, I want Salesforce to automatically call an AWS API to create a dedicated folder for an Account so account documents can be organized in AWS S3 without manual intervention. [PMMCWJC-9]

## Acceptance Criteria

- Given an Account ID, the integration sends a POST request to the AWS folder-creation API. [PMMCWJC-9]
- The JSON request body is `{ "accountId": "<Salesforce Account Id>" }`. [PMMCWJC-9]
- When AWS returns HTTP 200, update `Account.S3_Folder_Id__c` to `<AccountId>/`. [PMMCWJC-9]
- Record the HTTP status code and response body after a response is received. [PMMCWJC-9]
- On callout or Account-update failure, record the error message and stack trace. [PMMCWJC-9]
- Execute the callout asynchronously through a future method with callout support. [PMMCWJC-9]

## Functional Requirements

- Accept a persisted Salesforce Account ID as the integration input.
- Invoke the AWS create-folder endpoint with an HTTP POST and `application/json` content type.
- Treat HTTP 200 as the confirmed success condition; only then set the Account folder identifier to the Account ID followed by `/`.
- Persist a log entry for HTTP responses and for caught exceptions.
- Do not perform the external callout in the synchronous Account transaction.

## Technical Context

- The repository is a Salesforce DX project with API version 67.0. [sfdx-project.json](sfdx-project.json)
- The default package directory is `force-app`; it currently has no Apex classes, Aura components, LWCs, or application metadata. [force-app/main/default/classes](force-app/main/default/classes), [force-app/main/default/aura](force-app/main/default/aura), [force-app/main/default/lwc](force-app/main/default/lwc), [force-app/main/default/applications](force-app/main/default/applications)
- `Account` has no field metadata in source, including no source definition for `S3_Folder_Id__c`; `Integration_Log__c` exists as an object directory but has no field metadata. [force-app/main/default/objects/Account/fields](force-app/main/default/objects/Account/fields), [force-app/main/default/objects/Integration_Log__c/fields](force-app/main/default/objects/Integration_Log__c/fields)
- The documented endpoint is `POST https://t-1.amazonaws.com/create-folder`. [AWS S3 Folder Creation Integration - Technical Design]

## Proposed Solution

Add an Account-triggered Apex integration using a thin after-insert trigger and handler that pass newly created Account IDs to `AWSService.createFolderAsync`. Implement that method as `@future(callout=true)`; it queries the Account, constructs the required JSON with `JSON.serialize`, and performs the POST through a Named Credential-based endpoint. On HTTP 200, it updates `S3_Folder_Id__c` to `String.valueOf(accountId) + '/'`. For every response, it writes the status code and body to `Integration_Log__c`; for caught callout, deserialization, DML, or unexpected exceptions, it writes the exception message and stack trace.

This approach is the best fit because the ticket explicitly requires a future callout and automatic creation for Accounts, while a trigger handler keeps the synchronous transaction limited to enqueueing the asynchronous work. A Named Credential keeps the endpoint configuration and authentication out of Apex source.

## Implementation Considerations

- Create `S3_Folder_Id__c` on Account and the `Integration_Log__c` fields required to retain Account reference, operation name, status code, response body, error message, and stack trace. Field types and retention limits must accommodate response/stack-trace sizes.
- Use bulk-safe trigger handling: gather IDs from `Trigger.new` and enqueue future work in batches within the platform's future-call limit. The future method should accept a collection of primitive IDs, not sObjects.
- Use a Named Credential with an External Credential/authentication configuration approved by the AWS API owner. Do not hard-code the endpoint or secrets in Apex.
- Isolate logging in a dedicated helper so a logging DML failure is handled and does not mask the original integration error.
- Add Apex tests with `HttpCalloutMock` for HTTP 200, non-200 response, callout exception, and Account-update exception paths. Assert both Account outcome and persisted logging.

## Dependencies and Risks

- AWS must expose and authorize the documented endpoint from Salesforce. [AWS S3 Folder Creation Integration - Technical Design]
- A Named Credential or equivalent authenticated endpoint configuration is required before deployment. [AWS S3 Folder Creation Integration - Technical Design]
- `@future` has platform limits and does not provide immediate results to the initiating transaction; users cannot rely on `S3_Folder_Id__c` being populated immediately after Account creation.
- The source repository lacks the required Account field and log-object field definitions, so metadata creation is a delivery dependency.
- The ticket only defines HTTP 200 as success. All other status codes must be logged and leave `S3_Folder_Id__c` unchanged unless product requirements later specify retries or another success range.

## Edge Cases

- Multiple integration requests for the same Account can create duplicate AWS calls; ensure the trigger handler does not enqueue duplicate IDs within a transaction and confirm whether AWS folder creation is idempotent.
- An Account may be deleted or changed before asynchronous execution; log a missing-record condition and do not attempt the folder-ID update.
- A response body or stack trace may exceed the selected log-field length; choose suitable long-text fields and explicitly truncate only if required by the final schema.
- A non-200 AWS response, timeout, malformed response, or authentication failure must be logged without updating the Account field.
- Bulk Account inserts must respect future-call and DML limits.

## Open Questions

- What business action represents an Account being “selected for integration,” and should it invoke the same service in addition to Account creation?
- Should folder creation run for every new Account, or only when a flag, record type, or other eligibility rule is met?
- What authentication method, Named Credential name, AWS region, and timeout are required for the endpoint?
- Is AWS folder creation idempotent, and what retry policy is expected for timeouts and non-200 responses?
- What exact `Integration_Log__c` field API names, field types, retention policy, and visibility model are required?
- Should any HTTP 2xx response besides 200 be considered successful, or is 200 intentionally the sole success status?

## Sources

- Jira: [PMMCWJC-9: AWS S3 Account Folder Creation](https://dinagar4r.atlassian.net/browse/PMMCWJC-9). Source of the user story, acceptance criteria, asynchronous processing requirement, logging requirement, and status-code behavior. No directly linked Jira issues, attachments, or comments were present.
- Confluence: [AWS S3 Folder Creation Integration - Technical Design](https://dinagar4r.atlassian.net/wiki/pages/viewpage.action?pageId=262165). Source of the AWS endpoint, payload, successful response behavior, and Named Credential/Remote Site Setting assumption. Its details align with the Jira issue.
- Local implementation context: [sfdx-project.json](sfdx-project.json), [force-app/main/default/classes](force-app/main/default/classes), [force-app/main/default/aura](force-app/main/default/aura), [force-app/main/default/lwc](force-app/main/default/lwc), [force-app/main/default/applications](force-app/main/default/applications), [force-app/main/default/objects/Account/fields](force-app/main/default/objects/Account/fields), and [force-app/main/default/objects/Integration_Log__c/fields](force-app/main/default/objects/Integration_Log__c/fields).