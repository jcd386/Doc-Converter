@IsTest
public class WSM_DocConverterServiceTest {

    private static String insertContentVersionAndGetDocId(String title) {
        ContentVersion cv = new ContentVersion(
            Title = title,
            PathOnClient = title + '.pdf',
            VersionData = Blob.valueOf('test content for ' + title)
        );
        insert cv;
        return [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
    }

    @IsTest
    static void testGetDocumentInfo() {
        String docId = insertContentVersionAndGetDocId('TestFile');

        Test.startTest();
        List<WSM_DocConverterService.DocInfo> results =
            WSM_DocConverterService.getDocumentInfo(new List<String>{ docId });
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Expected 1 DocInfo result');
        WSM_DocConverterService.DocInfo info = results[0];
        System.assertEquals(docId, info.contentDocumentId, 'ContentDocumentId should match');
        System.assertNotEquals(null, info.contentVersionId, 'ContentVersionId should be set');
        System.assertEquals('TestFile', info.title, 'Title should match');
        System.assertNotEquals(null, info.contentSize, 'ContentSize should be populated');
        System.assertNotEquals(null, info.fileType, 'FileType should be populated');
    }

    @IsTest
    static void testGetDocumentInfoPreservesOrder() {
        String docId1 = insertContentVersionAndGetDocId('Alpha');
        String docId2 = insertContentVersionAndGetDocId('Beta');
        String docId3 = insertContentVersionAndGetDocId('Gamma');

        List<String> orderedIds = new List<String>{ docId3, docId1, docId2 };

        Test.startTest();
        List<WSM_DocConverterService.DocInfo> results =
            WSM_DocConverterService.getDocumentInfo(orderedIds);
        Test.stopTest();

        System.assertEquals(3, results.size(), 'Expected 3 DocInfo results');
        System.assertEquals('Gamma', results[0].title, 'First result should be Gamma');
        System.assertEquals('Alpha', results[1].title, 'Second result should be Alpha');
        System.assertEquals('Beta', results[2].title, 'Third result should be Beta');
    }

    @IsTest
    static void testGetDocumentInfoEmptyList() {
        Test.startTest();
        List<WSM_DocConverterService.DocInfo> results =
            WSM_DocConverterService.getDocumentInfo(new List<String>());
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Empty input should return empty list');
    }

    @IsTest
    static void testGetDocumentInfoNull() {
        Test.startTest();
        List<WSM_DocConverterService.DocInfo> results =
            WSM_DocConverterService.getDocumentInfo(null);
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Null input should return empty list');
    }

    @IsTest
    static void testBuildRequest() {
        Test.setMock(HttpCalloutMock.class, new OAuthMock());

        WSM_DocConverterService.RequestInput input = new WSM_DocConverterService.RequestInput();
        input.contentDocumentIds = new List<String>{ '069000000000001', '069000000000002' };
        input.parentRecordId = '001000000000001';
        input.outputFileName = 'My Package.pdf';
        input.mergeFiles = true;
        input.uploadIndividual = false;
        input.apiKey = 'test-api-key-123';
        input.endpointUrl = 'https://example.modal.run';
        input.sfClientId = 'test-client-id';
        input.sfClientSecret = 'test-client-secret';

        Test.startTest();
        List<WSM_DocConverterService.RequestOutput> outputs =
            WSM_DocConverterService.buildRequest(new List<WSM_DocConverterService.RequestInput>{ input });
        Test.stopTest();

        System.assertEquals(1, outputs.size(), 'Expected 1 output');
        WSM_DocConverterService.RequestOutput output = outputs[0];

        System.assertNotEquals(null, output.jsonBody, 'jsonBody should not be null');
        System.assertNotEquals(null, output.headersJson, 'headersJson should not be null');
        System.assertEquals('https://example.modal.run', output.endpointUrl, 'endpointUrl should match input');

        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(output.jsonBody);
        System.assertEquals('001000000000001', (String) parsed.get('parent_record_id'));
        System.assertEquals('My Package.pdf', (String) parsed.get('output_filename'));
        System.assertEquals(true, (Boolean) parsed.get('merge'));
        System.assertEquals(false, (Boolean) parsed.get('upload_individual'));
        System.assertEquals('63.0', (String) parsed.get('api_version'));
        System.assertEquals('mock-access-token-xyz', (String) parsed.get('access_token'));

        List<Object> docIds = (List<Object>) parsed.get('content_document_ids');
        System.assertEquals(2, docIds.size());

        System.assert(output.headersJson.contains('test-api-key-123'), 'headersJson should contain the API key');
        System.assert(output.headersJson.contains('Content-Type'), 'headersJson should contain Content-Type');
    }

    @IsTest
    static void testBuildRequestDefaults() {
        Test.setMock(HttpCalloutMock.class, new OAuthMock());

        WSM_DocConverterService.RequestInput input = new WSM_DocConverterService.RequestInput();
        input.contentDocumentIds = new List<String>{ '069000000000003' };
        input.parentRecordId = '001000000000002';
        input.outputFileName = null;
        input.mergeFiles = null;
        input.uploadIndividual = null;
        input.apiKey = 'test-key';
        input.endpointUrl = 'https://example.modal.run';
        input.sfClientId = 'test-client-id';
        input.sfClientSecret = 'test-client-secret';

        Test.startTest();
        List<WSM_DocConverterService.RequestOutput> outputs =
            WSM_DocConverterService.buildRequest(new List<WSM_DocConverterService.RequestInput>{ input });
        Test.stopTest();

        WSM_DocConverterService.RequestOutput output = outputs[0];
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(output.jsonBody);
        System.assertEquals('Merged Package.pdf', (String) parsed.get('output_filename'));
        System.assertEquals(true, (Boolean) parsed.get('merge'));
        System.assertEquals(false, (Boolean) parsed.get('upload_individual'));
    }

    private class OAuthMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"access_token":"mock-access-token-xyz","instance_url":"https://test.salesforce.com","token_type":"Bearer"}');
            return res;
        }
    }
}
