public with sharing class WSM_DocConverterService {

    public class DocInfo {
        @AuraEnabled public String contentDocumentId;
        @AuraEnabled public String contentVersionId;
        @AuraEnabled public String title;
        @AuraEnabled public Long contentSize;
        @AuraEnabled public String fileType;
        @AuraEnabled public String fileExtension;
    }

    public class RequestInput {
        @InvocableVariable(required=true label='Content Document IDs')
        public List<String> contentDocumentIds;
        @InvocableVariable(required=true label='Parent Record ID')
        public String parentRecordId;
        @InvocableVariable(label='Output File Name')
        public String outputFileName;
        @InvocableVariable(label='Merge Files')
        public Boolean mergeFiles;
        @InvocableVariable(label='Upload Individual')
        public Boolean uploadIndividual;
        @InvocableVariable(required=true label='API Key')
        public String apiKey;
        @InvocableVariable(required=true label='Endpoint URL')
        public String endpointUrl;
        @InvocableVariable(required=true label='SF Client ID')
        public String sfClientId;
        @InvocableVariable(required=true label='SF Client Secret')
        public String sfClientSecret;
    }

    public class RequestOutput {
        @InvocableVariable(label='JSON Body')
        public String jsonBody;
        @InvocableVariable(label='Headers JSON')
        public String headersJson;
        @InvocableVariable(label='Endpoint URL')
        public String endpointUrl;
    }

    @AuraEnabled(cacheable=true)
    public static List<DocInfo> getDocumentInfo(List<String> contentDocumentIds) {
        if (contentDocumentIds == null || contentDocumentIds.isEmpty()) {
            return new List<DocInfo>();
        }

        Map<String, ContentVersion> cvMap = new Map<String, ContentVersion>();
        for (ContentVersion cv : [
            SELECT Id, ContentDocumentId, Title, ContentSize, FileType, FileExtension
            FROM ContentVersion
            WHERE ContentDocumentId IN :contentDocumentIds
            AND IsLatest = true
        ]) {
            cvMap.put(cv.ContentDocumentId, cv);
        }

        List<DocInfo> results = new List<DocInfo>();
        for (String docId : contentDocumentIds) {
            ContentVersion cv = cvMap.get(docId);
            if (cv != null) {
                DocInfo info = new DocInfo();
                info.contentVersionId = cv.Id;
                info.contentDocumentId = cv.ContentDocumentId;
                info.title = cv.Title;
                info.contentSize = cv.ContentSize;
                info.fileType = cv.FileType;
                info.fileExtension = cv.FileExtension;
                results.add(info);
            }
        }
        return results;
    }

    @AuraEnabled
    public static String validateIntegrationAccess(String sfClientId, String sfClientSecret, List<String> contentDocumentIds) {
        if (contentDocumentIds == null || contentDocumentIds.isEmpty()) {
            return null;
        }

        String accessToken;
        try {
            accessToken = getOAuthToken(sfClientId, sfClientSecret);
        } catch (Exception e) {
            return 'Unable to authenticate the integration user. Please ask your administrator to verify the External Client App credentials and the WSM Doc Converter API permission set. (' + e.getMessage() + ')';
        }

        String baseUrl = URL.getOrgDomainUrl().toExternalForm() + '/services/data/v63.0';
        List<String> escaped = new List<String>();
        for (String docId : contentDocumentIds) {
            escaped.add(String.escapeSingleQuotes(docId));
        }
        String soql = 'SELECT ContentDocumentId FROM ContentVersion'
            + ' WHERE ContentDocumentId IN (\'' + String.join(escaped, '\',\'') + '\')'
            + ' AND IsLatest = true';

        HttpRequest req = new HttpRequest();
        req.setEndpoint(baseUrl + '/query?q=' + EncodingUtil.urlEncode(soql, 'UTF-8'));
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setTimeout(15000);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            return 'The integration user cannot query files (HTTP ' + res.getStatusCode() + '). Please ask your administrator to update the WSM Doc Converter API permission set.';
        }

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> records = (List<Object>) body.get('records');
        Integer visible = records != null ? records.size() : 0;

        if (visible == 0) {
            return 'The integration user does not have access to the selected files. Please ask your administrator to update the WSM Doc Converter API permission set to include read access to the records these files are attached to.';
        }
        if (visible < contentDocumentIds.size()) {
            return visible + ' of ' + contentDocumentIds.size() + ' files are accessible to the integration user. Some files may fail to convert. Please ask your administrator to update the WSM Doc Converter API permission set.';
        }

        return null;
    }

    @InvocableMethod(
        label='Build Doc Converter Request'
        description='Gets an API access token via Connected App, then builds the JSON request for the Modal doc converter'
        category='Integration'
        callout=true
    )
    public static List<RequestOutput> buildRequest(List<RequestInput> inputs) {
        RequestInput input = inputs[0];

        String accessToken = getOAuthToken(input.sfClientId, input.sfClientSecret);

        Map<String, Object> body = new Map<String, Object>();
        body.put('content_document_ids', input.contentDocumentIds);
        body.put('instance_url', URL.getOrgDomainUrl().toExternalForm());
        body.put('access_token', accessToken);
        body.put('parent_record_id', input.parentRecordId);
        body.put('output_filename', input.outputFileName != null ? input.outputFileName : 'Merged Package.pdf');
        body.put('merge', input.mergeFiles != null ? input.mergeFiles : true);
        body.put('upload_individual', input.uploadIndividual != null ? input.uploadIndividual : false);
        body.put('api_version', '63.0');

        RequestOutput output = new RequestOutput();
        output.jsonBody = JSON.serialize(body);
        output.headersJson = '[{"key":"X-API-Key","value":"' + input.apiKey + '"},{"key":"Content-Type","value":"application/json"}]';
        output.endpointUrl = input.endpointUrl;

        return new List<RequestOutput>{ output };
    }

    private static String getOAuthToken(String clientId, String clientSecret) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + '/services/oauth2/token');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setBody(
            'grant_type=client_credentials' +
            '&client_id=' + EncodingUtil.urlEncode(clientId, 'UTF-8') +
            '&client_secret=' + EncodingUtil.urlEncode(clientSecret, 'UTF-8')
        );

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            throw new AuraHandledException(
                'OAuth token request failed (HTTP ' + res.getStatusCode() + '): ' + res.getBody()
            );
        }

        Map<String, Object> tokenResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        return (String) tokenResponse.get('access_token');
    }
}