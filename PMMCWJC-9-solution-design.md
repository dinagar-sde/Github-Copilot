# PMMCWJC-9: AWS S3 Account Folder Creation

## Requirement Summary

When a new Salesforce Account is created, Salesforce must initiate creation of a dedicated AWS S3 folder by sending the Account ID to an AWS API. The operation must run asynchronously so Account creation is not delayed or interrupted (PMMCWJC-9: [Jira issue](https://dinagar4r.atlassian.net/browse/PMMCWJC-9)).

After a successful API response, Salesforce must store the S3 folder identifier on `Account.S3_Folder_Id__c`. The confirmed technical specification defines the stored value as `<AccountId>/`, for example `001XXXXXXXXXXXXXXX/` ([AWS S3 Folder Creation Integration - Technical Design](https://dinagar4r.atlassian.net/wiki/spaces/SD/pages/262165/AWS+S3+Folder+Creation+Integration+Technical+Design)).

The repository is a Salesforce DX project whose default package directory is `force-app` ([sfdx-project.json](sfdx-project.json)). The component paths referenced in the Jira comments are not currently present in the local workspace, so the Salesforce metadata and Apex implementation described below remain delivery work rather than confirmed local implementation.

## Acceptance Criteria

- On creation of a new Account, Salesforce asynchronously sends the Account ID to the AWS folder-creation API (PMMCWJC-9).
- The request uses `POST` to `callout:AWS_API/create-folder`, with `Content-Type: application/json` and body `{ "accountId": "<Salesforce Account ID>" }` ([AWS S3 Folder Creation Integration - Technical Design](https://dinagar4r.atlassian.net/wiki/spaces/SD/pages/262165/AWS+S3+Folder+Creation+Integration+Technical+Design)).
- The callout uses the `AWS_API` Named Credential ([AWS S3 Folder Creation Integration - Technical Design](https://dinagar4r.atlassian.net/wiki/spaces/SD/pages/262165/AWS+S3+Folder+Creation+Integration+Technical+Design)).
- A successful HTTP `200 OK` response causes `Account.S3_Folder_Id__c` to be updated to `<AccountId>/` ([AWS S3 Folder Creation Integration - Technical Design](https://dinagar4r.atlassian.net/wiki/spaces/SD/pages/262165/AWS+S3+Folder+Creation+Integration+Technical+Design)).
- A non-`200` response does not update `Account.S3_Folder_Id__c`, and callout/API exceptions are logged ([AWS S3 Folder Creation Integration - Technical Design](https://dinagar4r.atlassian.net/wiki/spaces/SD/pages/262165/AWS+S3+Folder+Creation+Integration+Technical+Design)).
- Account creation remains independent of the AWS callout outcome (PMMCWJC-9).

## Technical Design

- Add the `Account.S3_Folder_Id__c` custom field as Text with length 255, matching the confirmed integration specification ([AWS S3 Folder Creation Integration - Technical Design](https://dinagar4r.atlassian.net/wiki/spaces/SD/pages/262165/AWS+S3+Folder+Creation+Integration+Technical+Design)).
- Add an `after insert` Account trigger at `force-app/main/default/triggers/AccountS3FolderTrigger.trigger`. The trigger should collect inserted Account IDs and enqueue one asynchronous job for the transaction, preserving bulk behavior and keeping the database transaction free of the external callout.
- Add `force-app/main/default/classes/AccountS3FolderQueueable.cls` implementing a callout-capable Queueable job. The job should accept Account IDs, issue one `POST` request per Account to `callout:AWS_API/create-folder`, set the JSON content type, and serialize the request payload with the required `accountId` string ([AWS S3 Folder Creation Integration - Technical Design](https://dinagar4r.atlassian.net/wiki/spaces/SD/pages/262165/AWS+S3+Folder+Creation+Integration+Technical+Design)).
- Treat only HTTP `200` as success. For each successful response, update the corresponding Account with `<AccountId>/`. Do not update the field for any other status or for a callout exception.
- Use the `AWS_API` Named Credential as the endpoint boundary. The environment-specific Named Credential must be configured during deployment; no endpoint URL or secret should be hard-coded ([AWS S3 Folder Creation Integration - Technical Design](https://dinagar4r.atlassian.net/wiki/spaces/SD/pages/262165/AWS+S3+Folder+Creation+Integration+Technical+Design)).
- No external request or response payload changes apply. The confirmed request is:

  ```json
  {
    "accountId": "001XXXXXXXXXXXXXXX"
  }
  ```

  The confirmed success response is HTTP `200 OK` with `{ "status": "success" }`; the folder value persisted in Salesforce is derived as `<AccountId>/` ([AWS S3 Folder Creation Integration - Technical Design](https://dinagar4r.atlassian.net/wiki/spaces/SD/pages/262165/AWS+S3+Folder+Creation+Integration+Technical+Design)).
- Add the required Apex metadata files under the default package. The local `manifest` directory is not the package source of record; `sfdx-project.json` identifies `force-app` as the default package ([sfdx-project.json](sfdx-project.json)).

## Error Handling

- HTTP `200`: update `Account.S3_Folder_Id__c` with `<AccountId>/`.
- Any non-`200` response: leave `Account.S3_Folder_Id__c` unchanged and record an error with sufficient context to identify the Account and response status ([AWS S3 Folder Creation Integration - Technical Design](https://dinagar4r.atlassian.net/wiki/spaces/SD/pages/262165/AWS+S3+Folder+Creation+Integration+Technical+Design)).
- Callout or API exception: catch and log the exception; do not propagate it back into the original Account insert transaction ([AWS S3 Folder Creation Integration - Technical Design](https://dinagar4r.atlassian.net/wiki/spaces/SD/pages/262165/AWS+S3+Folder+Creation+Integration+Technical+Design)).
- The persistent error-log object, retention policy, retry policy, and alerting destination are not specified and are open questions.

## Security

- Use the `AWS_API` Named Credential for the callout, with authentication configured outside Apex ([AWS S3 Folder Creation Integration - Technical Design](https://dinagar4r.atlassian.net/wiki/spaces/SD/pages/262165/AWS+S3+Folder+Creation+Integration+Technical+Design)).
- Do not hard-code AWS endpoints, credentials, access keys, or tokens in Apex or metadata.
- Send only the Salesforce Account ID required by the confirmed request contract. Avoid writing request or response content containing sensitive data to logs.
- The specification states the Named Credential authentication value as `None`; the required network, API Gateway authorization, and Named Credential deployment configuration are not further defined and remain open questions.

## Unit Testing Notes

- Add `force-app/main/default/classes/AccountS3FolderQueueableTest.cls` and test the Queueable job with `Test.setMock(HttpCalloutMock.class, ...)`.
- Cover a `200` response and verify the request method, endpoint, content type, JSON `accountId`, and persisted `<AccountId>/` value ([AWS S3 Folder Creation Integration - Technical Design](https://dinagar4r.atlassian.net/wiki/spaces/SD/pages/262165/AWS+S3+Folder+Creation+Integration+Technical+Design)).
- Cover non-`200` responses and verify that the Account field is not updated.
- Cover callout exceptions and verify that the exception is handled without failing Account creation; assert the chosen logging behavior once the logging mechanism is confirmed.
- Cover multiple Accounts inserted in one transaction and verify that asynchronous processing handles all IDs without relying on one trigger invocation per record.
- Cover the trigger path with an Account insert and verify that a Queueable job is enqueued after insert.
- The expected test data factory, logging assertions, retry behavior, and deployment validation strategy are not defined and are open questions.

## Open Questions

- Where should non-`200` responses and callout exceptions be persisted, and what fields are required in the error log?
- Should failed folder creation be retried, and if so, what backoff, maximum attempts, and idempotency behavior does the AWS API support?
- How is the `AWS_API` Named Credential provisioned per Salesforce environment when the specification declares authentication as `None`?
- What API response statuses or body values, beyond HTTP `200`, indicate a usable folder creation result?
- Should Accounts with an existing `S3_Folder_Id__c` ever be retried or updated by a later process?
- What monitoring or notification is required when asynchronous folder creation fails?

## Sources

- [PMMCWJC-9 Jira issue](https://dinagar4r.atlassian.net/browse/PMMCWJC-9), including its description and comments.
- [AWS S3 Folder Creation Integration - Technical Design](https://dinagar4r.atlassian.net/wiki/spaces/SD/pages/262165), active Confluence specification linked from the Jira issue.
- A prior page titled `PMMCWJC-9: AWS S3 Account Folder Creation - Solution Design` was found in Confluence but is trashed; it was not treated as authoritative.
- [sfdx-project.json](sfdx-project.json), local Salesforce DX package configuration.
- The Jira comments name `AccountS3FolderTrigger`, `AccountS3FolderQueueable`, `AccountS3FolderQueueableTest`, and `Account.S3_Folder_Id__c`, but those paths are absent from the current local workspace.
