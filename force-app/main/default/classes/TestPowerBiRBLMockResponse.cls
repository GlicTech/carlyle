public class TestPowerBiRBLMockResponse implements HttpCalloutMock{
    public static Integer statusCodeToReturn = 202;
    public static String responseBody = '{"status": "Succeeded"}';   
    public static String type='PollingExports';
    public static boolean isTestFailureCallout = false;
       // Implement this interface method
    public static HTTPResponse respond(HTTPRequest req) {
         // Optionally, only send a mock response for a specific endpoint
        // and method.
        HttpResponse res ;
        // Create a dummy response
        if(req.getEndpoint().endswith('ExportTo')){
        
         res = new HttpResponse();
         

            res.setStatusCode(200);
         res.setStatus('OK');
         res.setHeader('Content-Type', 'application/json');
         res.setBody('{"@odata.context":"https://wabi-us-west2-redirect.analysis.windows.net/v1.0/myorg/groups/aedffeioo976/$metadata#exports/$entity","id":"MS9CbG9iSWRWMi1lYzFiOWQyMy02NzVlLTQ0OGItYTZmOC0zNjQyYTYzYjBhOWRndzk0UEpmT09TeDhCV1dwWm9Nc1k0NHV0WkktT3dBRFhXamZqZlhra1dBPS4=","createdDateTime":"2025-07-04T03:08:27.0329794Z","lastActionDateTime":"2025-07-04T03:08:27.0329794Z","reportId":"abc123456778"}');
          
        }
      
        else{
            res = new HttpResponse();
            System.debug('isTestFailureCallout :: ' + isTestFailureCallout);
            res.setStatusCode(200);
            if(isTestFailureCallout){
                res.setBody('{"@odata.context": "https://wabi-us-west2-redirect.analysis.windows.net/v1.0/myorg/groups/ce4bade4-2e18-4fec-832d-de305f4acee7/$metadata#exports/$entity","id": "MS9CbG9iSWRWMi05ZDIwZjg2ZC0zOWJjLTQyZWItYmMwNC02NjcxOTA3MDY0NzI4ZEJGNlBKY3FFTjNtSGFuSGRudW1URjhtR2ZIRW9oTWNzVE1qLW4wNjhFPS4=","createdDateTime": "2025-07-04T03:26:10.7029836Z","lastActionDateTime": "2025-07-04T03:27:42.040469Z","reportId": "abcddd","status": "Error","resourceLocation":"yyyyyyyy"}');
            } else{
                res.setBody('{"@odata.context": "https://wabi-us-west2-redirect.analysis.windows.net/v1.0/myorg/groups/ce4bade4-2e18-4fec-832d-de305f4acee7/$metadata#exports/$entity","id": "MS9CbG9iSWRWMi05ZDIwZjg2ZC0zOWJjLTQyZWItYmMwNC02NjcxOTA3MDY0NzI4ZEJGNlBKY3FFTjNtSGFuSGRudW1URjhtR2ZIRW9oTWNzVE1qLW4wNjhFPS4=","createdDateTime": "2025-07-04T03:26:10.7029836Z","lastActionDateTime": "2025-07-04T03:27:42.040469Z","reportId": "abcddd","status": "Succeeded","resourceLocation":"yyyyyyyy"}');
            }
         res.setStatus('OK');
         res.setHeader('Content-Type', 'application/json');
         
        
        }
        
        return res;
        
    }
}