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
- Secure OAuth client_credentials flow for API access (no session tokens in transit)
- Works on any object — just pass `recordId` to the Flow

## Prerequisites

1. **[HttpCalloutService](https://github.com/jcd386/HttpCalloutService)** must be deployed to your org first — this package uses it for the HTTP callout.

2. **External conversion API** — A server endpoint that accepts file IDs, downloads them from Salesforce via REST API, converts to PDF, and uploads results back. The Flow sends a POST to `/convert-sf` with:
   ```json
   {
     "content_document_ids": ["069..."],
     "instance_url": "https://your-org.my.salesforce.com",
     "access_token": "00D...",
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

4. **Two Remote Site Settings** (included in this package, but you must update the URLs):
   - `Doc_Converter_Endpoint` — Your conversion API base URL
   - `Salesforce_Login` — Your org's My Domain URL (e.g., `https://your-org.my.salesforce.com`)

## Installation

### Option A: One-Click Deploy

Click the "Deploy to Salesforce" button above.

### Option B: SFDX CLI

```bash
git clone https://github.com/jcd386/Doc-Converter.git
cd Doc-Converter
sf project deploy start --target-org YOUR_ORG_ALIAS
```

## Post-Install Setup

1. **Update Remote Site Settings** — In Setup > Remote Site Settings, update both entries with your actual URLs.

2. **Set Flow Variables** — Open the Flow `WSM - SCR - Convert Documents` in Flow Builder and set default values for these variables:
   - `varApiKey` — Your conversion API key
   - `varEndpointUrl` — Your conversion API base URL
   - `varSfClientId` — External Client App Consumer Key
   - `varSfClientSecret` — External Client App Consumer Secret

3. **Activate the Flow** — The Flow deploys in Draft status. Activate it after setting the variables.

4. **Create a Quick Action** — Add a Screen Flow action on your target object (Account, Opportunity, etc.) that launches `WSM - SCR - Convert Documents` and passes `recordId`.

## How It Works

```
Record Page → Quick Action → Screen Flow
  ↓
Get Related Files (ContentDocumentLink)
  ↓
File Selection (datatable — multi-select)
  ↓
Configure Conversion (LWC — reorder, rename, merge options)
  ↓
Build Request (Apex — gets OAuth token, builds JSON payload)
  ↓
HTTP Callout (HttpCalloutService — POST to /convert-sf)
  ↓
Success / Error Screen
```

The Apex class (`WSM_DocConverterService`) handles OAuth internally via `client_credentials` flow — credentials never appear in Flow variables at runtime, only as defaults in the Flow definition.

## Files

| File | Description |
|------|-------------|
| `WSM_DocConverterService.cls` | Apex: `getDocumentInfo` (LWC data) + `buildRequest` (InvocableMethod with OAuth) |
| `WSM_DocConverterServiceTest.cls` | Test class (6 methods, 75%+ coverage) |
| `wsmDocConverter/` | LWC: file table, reorder, merge/upload options for Flow Screens |
| `WSM_SCR_Convert_Documents.flow-meta.xml` | Screen Flow: end-to-end orchestration |
| `Doc_Converter_Endpoint.remoteSite-meta.xml` | Remote Site Setting for the conversion API |
| `Salesforce_Login.remoteSite-meta.xml` | Remote Site Setting for OAuth token exchange |

## Author

[We Summit Mountains](https://wesummitmountains.com)

## License

MIT
