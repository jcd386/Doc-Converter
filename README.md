# Doc-Converter

[![Deploy to Salesforce](https://raw.githubusercontent.com/afawcett/githubsfdeploy/master/src/main/webapp/resources/img/deploy.png)](https://githubsfdeploy.herokuapp.com/app/githubdeploy/jcd386/Doc-Converter?ref=main)

Universal document converter for Salesforce. Select Word, Excel, image, and PDF files from any record, convert non-PDFs to PDF, optionally reorder and merge into a single PDF. Uses a Screen Flow with a drag-and-drop LWC and an external conversion API.

## Features

- Select files from any Salesforce record via datatable
- Convert DOCX, XLSX, PNG, JPG, and other formats to PDF
- Reorder files with up/down arrows before merging
- Merge multiple files into a single PDF
- Optionally upload individually converted PDFs back to the record
- Custom output filename
- Named Credentials for encrypted credential storage and automatic token management
- Works on any object — just pass `recordId` to the Flow

## Prerequisites

1. **[HttpCalloutService](https://github.com/jcd386/HttpCalloutService)** must be deployed to your org first — this package uses it for the HTTP callout.

2. **External conversion API** — A server endpoint that accepts file IDs, downloads them from Salesforce via REST API, converts to PDF, and uploads results back. The API must read the Salesforce access token from the `Authorization: Bearer` header (auto-attached by the Named Credential). The Flow sends a POST to `/convert-sf` with:
   ```json
   {
     "content_document_ids": ["069..."],
     "instance_url": "https://your-org.my.salesforce.com",
     "parent_record_id": "001...",
     "output_filename": "Merged Package.pdf",
     "merge": true,
     "upload_individual": false,
     "api_version": "63.0"
   }
   ```

3. **External Client App** (Setup > External Client Apps) configured with:
   - OAuth `client_credentials` grant type
   - A Run As user with API access and read access to ContentVersion/ContentDocument
   - Note the Consumer Key and Consumer Secret

## Installation

### Option A: One-Click Deploy

Click the "Deploy to Salesforce" button above. This deploys the Apex classes, LWC, Flow, custom permission, and permission set.

### Option B: SFDX CLI

```bash
git clone https://github.com/jcd386/Doc-Converter.git
cd Doc-Converter
sf project deploy start --target-org YOUR_ORG_ALIAS
```

## Post-Install Setup

Named Credentials **cannot be deployed via Metadata API** — they must be created manually in Setup. Reference files are included in the repo under `externalCredentials/` and `namedCredentials/` for documentation.

### 1. Create External Credential

In **Setup > Named Credentials > External Credentials**, click **New**:

| Field | Value |
|-------|-------|
| Label | WSM Doc Converter |
| Authentication Protocol | OAuth 2.0 |
| Authentication Flow Type | Client Credentials with Client Secret Flow |
| Token Endpoint | `https://YOUR_ORG_DOMAIN.my.salesforce.com/services/oauth2/token` |

After saving, click the Principal name and enter the Consumer Key and Consumer Secret from your External Client App.

### 2. Create Named Credential — SF Internal API

In **Setup > Named Credentials**, click **New**:

| Field | Value |
|-------|-------|
| Label | WSM Doc Converter SF |
| URL | `https://YOUR_ORG_DOMAIN.my.salesforce.com` |
| External Credential | WSM Doc Converter |
| Generate Authorization Header | Checked |

This is used by `validateIntegrationAccess()` to query the org as the integration user.

### 3. Create Named Credential — Conversion Endpoint

In **Setup > Named Credentials**, click **New**:

| Field | Value |
|-------|-------|
| Label | WSM Doc Converter Endpoint |
| URL | Your conversion API base URL |
| External Credential | WSM Doc Converter |
| Generate Authorization Header | Checked |

After saving, add a custom header `X-API-Key` with your conversion service API key.

### 4. Set Flow Variable

Open the Flow `WSM - SCR - Convert Documents` in Flow Builder and set:
- `varApiKey` — Your conversion API key (also available as a custom header on the Named Credential)

### 5. Activate the Flow

The Flow deploys in Draft status. Activate it after completing the Named Credential setup.

### 6. Assign the Permission Set

Assign `WSM Doc Converter` to users who need access. The permission set grants:
- Apex class access
- Custom permission (`WSM_Doc_Converter_Access`) for the Flow's access check
- External Credential Principal access for the Named Credential

### 7. Create a Quick Action

Add a Screen Flow action on your target object (Account, Opportunity, etc.) that launches `WSM - SCR - Convert Documents` and passes `recordId`.

## How It Works

```
Record Page -> Quick Action -> Screen Flow
  |
  v
Get Related Files (ContentDocumentLink)
  |
  v
File Selection (datatable - multi-select)
  |
  v
Configure Conversion (LWC - reorder, rename, merge options)
  |
  v
Build Request (Apex - builds JSON payload, returns callout:NamedCredential)
  |
  v
HTTP Callout (HttpCalloutService - POST to /convert-sf via Named Credential)
  |
  v
Success / Error Screen
```

The Named Credential handles OAuth token management automatically. When `HttpCalloutService` calls `callout:WSM_Doc_Converter_Endpoint/convert-sf`, Salesforce auto-attaches the Bearer token as an Authorization header. The conversion API reads the token from the header to call back into Salesforce and download files.

## Files

| File | Description |
|------|-------------|
| `WSM_DocConverterService.cls` | Apex: `getDocumentInfo` (LWC data) + `buildRequest` (InvocableMethod) + `validateIntegrationAccess` |
| `WSM_DocConverterServiceTest.cls` | Test class (9 methods) |
| `wsmDocConverter/` | LWC: file table, reorder, merge/upload options for Flow Screens |
| `WSM_SCR_Convert_Documents.flow-meta.xml` | Screen Flow: end-to-end orchestration |
| `WSM_Doc_Converter_Access.customPermission-meta.xml` | Custom permission for access control |
| `WSM_Doc_Converter.permissionset-meta.xml` | Permission set bundling Apex + custom permission + External Credential |
| `externalCredentials/` | Reference XML for External Credential (manual setup required) |
| `namedCredentials/` | Reference XML for Named Credentials (manual setup required) |

## Author

[We Summit Mountains](https://wesummitmountains.com)

## License

MIT
