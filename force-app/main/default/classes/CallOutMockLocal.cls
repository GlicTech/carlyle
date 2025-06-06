/*
 * Mock response class for all the global picklist related local batch classes for code coverage
 */

 global with sharing class CallOutMockLocal implements WebServiceMock{
    global void doInvoke(
        Object stub,
        Object request,
        Map<String, Object> response,
        String endpoint,
        String soapAction,
        String requestName,
        String responseNS,
        String responseName,
        String responseType) {
            
            if(request instanceof MetadataService.readMetadata_element){
              MetadataService.readMetadata_element requestReadMetadata_element  = 
                    (MetadataService.readMetadata_element) request;
                  // This allows you to generalize the mock response by type of metadata read
                  if (requestReadMetadata_element.type_x == 'GlobalValueSet') { 
                     MetadataService.readGlobalValueSetResponse_element mockRes   = 
                          new MetadataService.readGlobalValueSetResponse_element();
                     mockRes.result = new MetaDataService.ReadGlobalValueSetResult();
                      
                     MetadataService.GlobalValueSet globalValues = new MetadataService.GlobalValueSet();
                     MetadataService.CustomValue testVal = new MetadataService.CustomValue();
                     testVal.fullName = 'Test';
                     globalValues.customValue = new List<MetadataService.CustomValue>();
                     globalValues.customValue.add(testVal);
                     
                     mockRes.result.records = new List<MetadataService.GlobalValueSet>(); 
                     mockRes.result.records.add(globalValues);
                      
                     response.put('response_x', mockRes);
                  }
                  else if (requestReadMetadata_element.type_x == 'CustomField') { 
                    // mock your customField results
                    MetadataService.readCustomFieldResponse_element mockRes   = 
                          new MetadataService.readCustomFieldResponse_element();
                     mockRes.result = new MetaDataService.ReadCustomFieldResult();
                      
                     MetadataService.CustomField fld = new MetadataService.CustomField();                 
                     fld.fullName = 'Test';
                     fld.valueSet = new MetadataService.ValueSet();
                     fld.valueSet.valueSetDefinition = new MetadataService.ValueSetValuesDefinition(); 
                     fld.valueSet.valueSetDefinition.value = new List<MetadataService.CustomValue>();
                     MetadataService.CustomValue testNewVal = new MetadataService.CustomValue();
                     testNewVal.fullName = 'New Val';
                     fld.valueSet.valueSetDefinition.value.add(testNewVal);
                         
                     mockRes.result.records = new List<MetadataService.CustomField>(); 
                     mockRes.result.records.add(fld);
                      
                     response.put('response_x', mockRes);
                  }
                else if(requestReadMetadata_element.type_x == 'RecordType'){
                    MetadataService.readRecordTypeResponse_element mockRes   = 
                          new MetadataService.readRecordTypeResponse_element();
                     mockRes.result = new MetaDataService.ReadRecordTypeResult();
                      
                     MetadataService.RecordType recType = new MetadataService.RecordType();
                     recType.fullName = 'Test Recordtype';
                     recType.picklistValues = new List<MetadataService.RecordTypePicklistValue>();
                     MetadataService.RecordTypePicklistValue newField = new MetadataService.RecordTypePicklistValue();
                     newField.picklist ='Type';
                     newField.values = new List<MetadataService.PicklistValue>();
                     MetadataService.PicklistValue testVal = new MetadataService.PicklistValue();
                     testVal.fullName = 'Test';
                     newField.values.add(testVal);
                         
                     MetadataService.RecordTypePicklistValue oldField = new MetadataService.RecordTypePicklistValue();
                     oldField.picklist ='Type';
                     oldField.values = new List<MetadataService.PicklistValue>();
                     MetadataService.PicklistValue testVal2 = new MetadataService.PicklistValue();
                     testVal2.fullName = 'Test';
                     oldField.values.add(testVal2);
                    
                     recType.picklistValues.add(newField);
                     recType.picklistValues.add(oldField);
                        mockRes.result.records = new List<MetadataService.RecordType>(); 
                     mockRes.result.records.add(recType);
                      
                     response.put('response_x', mockRes);
                }
               }
           else if (request instanceof MetadataService.upsertMetadataResponse_element) {
                   MetadataService.upsertMetadataResponse_element res = new MetadataService.upsertMetadataResponse_element();
                List<MetadataService.UpsertResult> srList = new List<MetadataService.UpsertResult>();
                MetadataService.UpsertResult sr = new MetadataService.UpsertResult();
                sr.success = true;
                sr.fullName = 'Test FullName';           
                srList.add(sr);
                res.result = srList;
                 response.put('response_x', res);
           }
          
        }
    }