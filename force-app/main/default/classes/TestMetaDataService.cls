/**
 * This is a dummy test class to obtain code coverage for the generated WSDL2Apex code - MetadataService.cls, it is not a funcitonal test class
 **/ 
@isTest  
private class TestMetaDataService
{    
    /**
     * Dummy Metadata API web service mock class 
     **/
	private class WebServiceMockImpl implements WebServiceMock 
	{
		public void doInvoke(
			Object stub, Object request, Map<String, Object> response,
			String endpoint, String soapAction, String requestName,
			String responseNS, String responseName, String responseType) 
		{
			if(request instanceof MetadataService.retrieve_element)
				response.put('response_x', new MetadataService.retrieveResponse_element());
			else if(request instanceof MetadataService.checkDeployStatus_element)
				response.put('response_x', new MetadataService.checkDeployStatusResponse_element());
			else if(request instanceof MetadataService.deploy_element)
				response.put('response_x', new MetadataService.deployResponse_element());
            else if(request instanceof MetadataService.updateMetadata_element)
                response.put('response_x', new MetadataService.updateMetadataResponse_element());
            else if(request instanceof  MetadataService.upsertMetadata_element)
                response.put('response_x', new MetadataService.upsertMetadataResponse_element());
            else if(request instanceof  MetadataService.createMetadata_element)
                response.put('response_x', new MetadataService.createMetadataResponse_element());
			return;
		}
	}    
		
	@IsTest
	private static void coverGeneratedCodeCRUDOperations()
	{	
    	// Null Web Service mock implementation
        System.Test.setMock(WebServiceMock.class, new WebServiceMockImpl());
        // Only required to workaround a current code coverage bug in the platform
        MetadataService metaDataService = new MetadataService();
        // Invoke operations     
        Test.startTest();    
        MetadataService.MetadataPort metaDataPort = new MetadataService.MetadataPort();
        Test.stopTest();
	}
	
	@IsTest
    private static void coverGeneratedCodeFileBasedOperations1()
    {    	
    	// Null Web Service mock implementation
        System.Test.setMock(WebServiceMock.class, new WebServiceMockImpl());
        // Only required to workaround a current code coverage bug in the platform
        MetadataService metaDataService = new MetadataService();
        // Invoke operations    
        Test.startTest();     
        MetadataService.MetadataPort metaDataPort = new MetadataService.MetadataPort();
        metaDataPort.retrieve(null);
        metaDataPort.checkDeployStatus(null, false);
        metaDataPort.deploy(null, null);
        metaDataPort.checkDeployStatus(null, false);
        metaDataPort.updateMetadata(null);
        new MetadataService.DeployDetails();
        new MetadataService.RetrieveResult();        
        new MetadataService.SaveResult();
        new MetadataService.Error();
        new MetadataService.Package_x();
        new MetadataService.LogInfo();
        new MetadataService.RunTestsResult();
        new MetadataService.FileProperties();
        new MetadataService.RetrieveMessage();
        new MetadataService.ProfileObjectPermissions();
        new MetadataService.CodeCoverageResult();
        new MetadataService.CodeCoverageWarning();
        new MetadataService.CodeLocation();
        new MetadataService.RunTestFailure();
        new MetadataService.RunTestSuccess();
        new MetadataService.FieldSet();
        new MetadataService.CustomField();
        new MetadataService.CustomObject();
        new MetadataService.LookupFilter();
        new MetadataService.ValueSet();
        new MetadataService.RecordType();
        new MetadataService.PicklistValue();
        Test.stopTest();
    }

    @IsTest
    private static void coverGeneratedCodeFileBasedOperations2()
    {       
        // Null Web Service mock implementation
        System.Test.setMock(WebServiceMock.class, new WebServiceMockImpl());
        // Only required to workaround a current code coverage bug in the platform
        MetadataService metaDataService = new MetadataService();
        // Invoke operations     
        Test.startTest();    
        MetadataService.MetadataPort metaDataPort = new MetadataService.MetadataPort();        
        metaDataPort.upsertMetadata(null);
        metaDataPort.createMetadata(null);
        new MetadataService.UpsertResult();
        new MetadataService.readMetadata_element(); 		
        new MetadataService.ReadRecordTypeResult().getRecords();
        new MetadataService.readRecordTypeResponse_element();
        new MetadataService.AsyncResult();
        new MetadataService.DeployResult();
        new MetaDataService.AllOrNoneHeader_element();
        new MetadataService.DeployMessage();
        new MetadataService.RetrieveRequest();
        Test.stopTest();
    }

}