# PMMCWJC-9: AWS S3 Account Folder Creation

## Requirement Summary

- When a Salesforce Account is created, Salesforce must asynchronously request creation of a dedicated AWS S3 folder so Account-related documents have an organized storage location. (PMMCWJC-9)
- Salesforce sends the Account ID to an AWS API, and saves the resulting folder reference on the Account only after a successful response. (PMMCWJC-9)
- The integration uses Salesforce Named Credential `AWS_API`, the `POST` resource `/create-folder`, and JSON content type. ([AWS S3 Folder Creation Integration - Technical Design](https://dinagar4r.atlassian.net/wiki/spaces/SD/pages/262165/AWS+S3+Folder+Creation+Integration+Technical+Design))
- The repository is a Salesforce DX project whose default package is `force-app`; its current source contains no implementation for this integration. ([sfdx-project.json](sfdx-project.json), `force-app/main/default/classes/`, `force-app/main/default/triggers/`, `force-app/main/default/namedCredentials/`)

## Acceptance Criteria

- After a new Account is committed, Salesforce invokes the AWS API in the background and does not block the Account creation transaction. (PMMCWJC-9)
- The request is `POST callout:AWS_API/create-folder` with `Content-Type: application/json` and a required string property `accountId` containing the Salesforce Account ID. ([AWS S3 Folder Creation Integration - Technical Design](https://dinagar4r.atlassian.net/wiki/spaces/SD/pages/262165/AWS+S3+Folder+Creation+Integration+Technical+Design))
- For HTTP `200 OK`, Salesforce sets `Account.S3_Folder_Id__c` to `<AccountId>/`. ([AWS S3 Folder Creation Integration - Technical Design](https://dinagar4r.atlassian.net/wiki/spaces/SD/pages/262165/AWS+S3+Folder+Creation+Integration+Technical+Design))
- For HTTP `400`, `401`, `403`, `404`, or `500`, Salesforce does not update `S3_Folder_Id__c`. ([AWS S3 Folder Creation Integration - Technical Design](https://dinagar4r.atlassian.net/wiki/spaces/SD/pages/262165/AWS+S3+Folder+Creation+Integration+Technical+Design))
- Callout exceptions and timeouts are logged, and the Account folder field is not updated. ([AWS S3 Folder Creation Integration - Technical Design](https://dinagar4r.atlassian.net/wiki/spaces/SD/pages/262165/AWS+S3+Folder+Creation+Integration+Technical+Design))
- The Account field is a Text field named `S3_Folder_Id__c` with length 255. ([AWS S3 Folder Creation Integration - Technical Design](https://dinagar4r.atlassian.net/wiki/spaces/SD/pages/262165/AWS+S3+Folder+Creation+Integration+Technical+Design))

## Technical Design

- Add `Account.S3_Folder_Id__c` as a Text(255) custom field under `force-app/main/default/objects/Account/fields/`. The field stores the folder reference returned by the contract, currently defined as the Account ID followed by `/`. ([AWS S3 Folder Creation Integration - Technical Design](https://dinagar4r.atlassian.net/wiki/spaces/SD/pages/262165/AWS+S3+Folder+Creation+Integration+Technical+Design))
- Add an `after insert` Account trigger under `force-app/main/default/triggers/`. The trigger should collect inserted Account IDs and enqueue one asynchronous job for the batch, keeping the trigger thin and avoiding synchronous callouts. This directly satisfies the background-processing requirement. (PMMCWJC-9)
- Implement a Queueable Apex job with callout capability under `force-app/main/default/classes/`. The job should issue one HTTP request per Account ID to `callout:AWS_API/create-folder`, set `Content-Type: application/json`, and serialize `{ "accountId": "<Salesforce Account ID>" }`. The confirmed request payload is:

  ```json
  {
    "accountId": "001XXXXXXXXXXXXXXX"
  }
  ```

  (Confluence: [AWS S3 Folder Creation Integration - Technical Design](https://dinagar4r.atlassian.net/wiki/spaces/SD/pages/262165/...), PMMCWJC-9)

- Treat HTTP `200` as success and update the corresponding Account with `<AccountId>/` in a separate DML operation. Do not update the field for the documented non-200 statuses or callout failures. No new Salesforce event or public API payload is required; the integration request is the only outbound payload, and the Account field is the only persisted result. (Confluence: [AWS S3 Folder Creation Integration - Technical Design](https://dinagar4r.atlassian.net/wiki/spaces/SD/pages/262165/AWS+S3+Folder+Creation+Integration+Technical+Design))
- Add a Named Credential metadata definition under `force-app/main/default/namedCredentials/` with API name `AWS_API` and the configured AWS API base URL. The design page gives `https://abc123xyz.execute-api.us-east-1.amazonaws.com/dev` as an example URL and specifies no authentication. The deployed endpoint and credential behavior must be supplied per environment. ([AWS S3 Folder Creation Integration - Technical Design](https://dinagar4r.atlassian.net/wiki/spaces/SD/pages/262165/AWS+S3+Folder+Creation+Integration+Technical+Design))
- Keep the callout and update logic in a service/job class so the trigger remains bulk-safe and testable. Prevent an Account from being overwritten by a later duplicate job once `S3_Folder_Id__c` is populated; the exact duplicate-request policy is an open question because it is not specified by PMMCWJC-9 or the technical design.

## Error Handling

- For HTTP `400`, `401`, `403`, `404`, and `500`, preserve the Account’s existing `S3_Folder_Id__c` value and log the failed status and Account ID. ([AWS S3 Folder Creation Integration - Technical Design](https://dinagar4r.atlassian.net/wiki/spaces/SD/pages/262165/AWS+S3+Folder+Creation+Integration+Technical+Design))
- For callout exceptions and timeouts, preserve the field and log the exception context. (Confluence: [AWS S3 Folder Creation Integration - Technical Design](https://dinagar4r.atlassian.net/wiki/spaces/SD/pages/262165/AWS+S3+Folder+Creation+Integration+Technical+Design))
- Logging destination, retention, retry policy, and alerting threshold are not defined in the ticket or linked design and remain open questions. The implementation must avoid surfacing asynchronous failures as errors on the already-committed Account creation transaction. (PMMCWJC-9)
- A response-body schema beyond HTTP `200 OK` and status `success` is not documented. The implementation should not depend on undocumented response properties; the persisted value is the contractually specified `<AccountId>/` reference. ([AWS S3 Folder Creation Integration - Technical Design](https://dinagar4r.atlassian.net/wiki/spaces/SD/pages/262165/AWS+S3+Folder+Creation+Integration+Technical+Design))

## Security

- Use the `AWS_API` Named Credential for endpoint resolution rather than hard-coding the URL in Apex. ([AWS S3 Folder Creation Integration - Technical Design](https://dinagar4r.atlassian.net/wiki/spaces/SD/pages/262165/AWS+S3+Folder+Creation+Integration+Technical+Design))
- Send only the Salesforce Account ID required by the documented contract; do not include Account business data. (PMMCWJC-9; [AWS S3 Folder Creation Integration - Technical Design](https://dinagar4r.atlassian.net/wiki/spaces/SD/pages/262165/AWS+S3+Folder+Creation+Integration+Technical+Design))
- The linked design specifies unauthenticated access for the Named Credential. Whether the AWS API is protected by network controls, API Gateway policy, or another mechanism is not documented and must be confirmed before production deployment. (Confluence: [AWS S3 Folder Creation Integration - Technical Design](https://dinagar4r.atlassian.net/wiki/spaces/SD/pages/262165/AWS+S3+Folder+Creation+Integration+Technical+Design))
- Use standard Apex sharing and CRUD/FLS review for the Account update. No repository security convention exists yet for this integration because the relevant Apex and metadata directories are empty. (`force-app/main/default/classes/`, `force-app/main/default/triggers/`)

## Unit Testing Notes

- Add Apex tests alongside the new classes using `HttpCalloutMock` to cover HTTP `200`, each documented non-200 status, callout exception, and timeout behavior. The success test must assert `S3_Folder_Id__c == Account.Id + '/'`; failure tests must assert that the field is unchanged. (Confluence: [AWS S3 Folder Creation Integration - Technical Design](https://dinagar4r.atlassian.net/wiki/spaces/SD/pages/262165/AWS+S3+Folder+Creation+Integration+Technical+Design))
- Test the Account trigger with a bulk insert and assert that the asynchronous job processes all Account IDs without performing a synchronous callout. (PMMCWJC-9)
- Assert the outbound method, endpoint suffix, content type, and JSON `accountId` value in the mock. The API contract is defined by the linked Confluence page. ([AWS S3 Folder Creation Integration - Technical Design](https://dinagar4r.atlassian.net/wiki/spaces/SD/pages/262165/AWS+S3+Folder+Creation+Integration+Technical+Design))
- The repository currently provides only the standard LWC Jest scripts in `package.json`; no Apex test implementation or integration test harness exists yet. ([package.json](package.json), `force-app/main/default/classes/`)

## Open Questions

- What is the production AWS API URL and how should Named Credential values differ across scratch, sandbox, and production environments? The linked page provides an example URL only.
- Is unauthenticated API access intentional, and what AWS API Gateway or network controls protect the endpoint?
- What logging target should receive failures, and what information, retention, alerting, and monitoring requirements apply?
- Should failed folder creation be retried, and if so, what backoff, maximum-attempt, and duplicate-request rules apply?
- Should an Account be reprocessed when `S3_Folder_Id__c` is already populated, or should the integration be strictly create-once?
- What exact response body indicates `status: success`, and should a `200` response without that body status be treated as success?
- Should the Account field be writable by users, or should field-level security make it read-only outside the integration path?

## Sources

- Jira issue [PMMCWJC-9](https://dinagar4r.atlassian.net/browse/PMMCWJC-9): story, scope, status, and acceptance behavior.
- Confluence page [AWS S3 Folder Creation Integration - Technical Design](https://dinagar4r.atlassian.net/wiki/spaces/SD/pages/262165/AWS+S3+Folder+Creation+Integration+Technical+Design): API, field, error, configuration, and flow details.
- No directly linked Jira issues, attachments, or comments were found for PMMCWJC-9.
- Repository context: [sfdx-project.json](sfdx-project.json), [package.json](package.json), and the currently empty integration directories under `force-app/main/default/`.
