/**
 * @description       : 
 * @author            : Pavan Patel(Prodigy)
 * @group             : 
 * @last modified on  : 08-19-2025
 * @last modified by  : Pavan Patel(Prodigy)
**/
// ProdigyDataTableController.cls

public virtual  class ProdigyDataTableController {
    public static Prodigy_Data_Table__mdt mockMetadata;
    public static List<Prodigy_Data_Table_Column__mdt> mockColumns;
    public class ColumnConfig {
        @AuraEnabled public String label;
        @AuraEnabled public String fieldName;
        @AuraEnabled public String cellStyle; // updated from conditionalFormatting to cellStyle
        @auraEnabled public integer Display_Order;
        @AuraEnabled public Boolean sortable; // NEW
        @AuraEnabled public Boolean editable;
        
        
    }
    
    public class CellData {
        @AuraEnabled public String fieldName;
        @AuraEnabled public String value;
        @AuraEnabled public String style; // updated from colorHex to full style
        @AuraEnabled public Boolean editable;
        @AuraEnabled public Boolean islink;
        @AuraEnabled public string url;
        
    }
    
    public class RecordWrapper {
        @AuraEnabled public String Id;
        @AuraEnabled public List<CellData> cells;
        
    }
    public class FlowAction {
        @AuraEnabled public String label;
        @AuraEnabled public String apiName;
    }
    public class TopLevelAction {
        @AuraEnabled public String label;
        @AuraEnabled public String flowApiName;
    }
    
    public class TableData {
        @AuraEnabled public List<ColumnConfig> columns;
        @AuraEnabled public List<RecordWrapper> records;
        @AuraEnabled public TableConfig config;
        @AuraEnabled public List<FlowAction> flowActions;
        @AuraEnabled public List<TopLevelAction> topLevelActions;
    }
    
    public class TableConfig {
        
        @AuraEnabled public Boolean autoRefresh;
        @AuraEnabled public Integer refreshInterval;
        @AuraEnabled public Boolean searchable;
        @AuraEnabled public String Name;
        @AuraEnabled public integer defaultRowCount ;
        @auraenabled public boolean showrecordcount;
        @auraenabled public string relatedListRedirectionLink;
          @auraenabled public boolean showselectionCheckbox;
        @AuraEnabled public Boolean paginationEnabled=false;
            @AuraEnabled public Integer totalRecords;
@AuraEnabled public Integer pageSize;
        @AuraEnabled public Boolean flowSplitScreen;
    }
    @AuraEnabled
    public static TableData getConfigAndData(String configDevName,string recordId,List<SObject> recordsfromFlow,boolean isFlowContext, Integer offsetValue, Integer limitValue) {
        TableData output = new TableData();
        output.columns = new List<ColumnConfig>();
        output.records = new List<RecordWrapper>();
        
        Prodigy_Data_Table__mdt config;
        if (Test.isRunningTest() && mockMetadata != null) {
            config = mockMetadata;
        } else {
            config = [
                SELECT Object_API_Name__c, Auto_Refresh_Enabled__c, Filter_Logic__c, Page_Size__c,
                Auto_Refresh_Interval__c, Enable_Search__c, Label,
                proX__default_number_of_rows__c, proX__Show_Selection_check_box__c,
                Row_Level_Flow_Actions__c, proX__Top_Level_Actions__c,
                proX__Show_Count_of_Records__c, proX__Pro_Related_List_Redirection_URL__c,
                proX__Flow_Split_Screen__c
                FROM Prodigy_Data_Table__mdt
                WHERE DeveloperName = :configDevName
                LIMIT 1
            ];
        }
        TableConfig configDetails = new TableConfig();
        configDetails.autoRefresh = config.Auto_Refresh_Enabled__c;
        configDetails.refreshInterval = Integer.valueOf(config.Auto_Refresh_Interval__c);
        configDetails.searchable = config.Enable_Search__c;
        configDetails.Name = config.label;
        configDetails.defaultRowCount =Integer.valueOf(config.proX__default_number_of_rows__c);
        configDetails.showrecordcount=config.proX__Show_Count_of_Records__c;
        configDetails.relatedlistredirectionlink=config.proX__Pro_Related_List_Redirection_URL__c;
        configDetails.showselectionCheckbox=config.proX__Show_Selection_check_box__c;
        configDetails.flowSplitScreen = config.proX__Flow_Split_Screen__c;
        Integer pageSize = config.Page_Size__c != null ? Integer.valueOf(config.Page_Size__c) : 0;
   
Boolean isPaginated = pageSize > 0;
Integer finalLimit = isPaginated ? (limitValue != null ? limitValue : pageSize) : null;
Integer finalOffset = isPaginated ? (offsetValue != null ? offsetValue : 0) : null;

             configDetails.paginationEnabled = isPaginated;
configDetails.pageSize = pageSize;
      
        output.flowActions = new List<FlowAction>();
        output.topLevelActions=new list<TopLevelAction>();
        String raw = config.Row_Level_Flow_Actions__c;
        if(raw != null ) {
            
            Pattern p = Pattern.compile('\\{([^,{}]+),([^,{}]+)\\}');
            Matcher m = p.matcher(raw);
            
            while (m.find()) {
                FlowAction fa = new FlowAction();
                fa.label = m.group(1).trim();
                fa.apiName = m.group(2).trim();
                output.flowActions.add(fa);
            }
        }
        string raw1=config.proX__Top_Level_Actions__c;
        if(raw1 != null ) {
            
            Pattern p = Pattern.compile('\\{([^,{}]+),([^,{}]+)\\}');
            Matcher m = p.matcher(raw1);
            
            while (m.find()) {
                TopLevelAction fa = new TopLevelAction();
                fa.label = m.group(1).trim();
                fa.flowApiName = m.group(2).trim();
                output.topLevelActions.add(fa);
            }
        }
        List<Prodigy_Data_Table_Column__mdt> columnMdts;
        if (Test.isRunningTest() && mockColumns != null) {
            columnMdts = mockColumns;
        } else {
            columnMdts = [
                SELECT Field_API_Name__c, Column_Label__c, Conditional_Formatting__c,
                Display_Order__c, Sortable__c, Editable__c,Type__c,proX__Lookup_Display_Field__c,proX__Show_Record_Link__c
                FROM Prodigy_Data_Table_Column__mdt
                WHERE Prodigy_Data_Table__c = :config.Id
                ORDER BY Display_Order__c ASC
            ];
        }
        string relationshipFields ='';
        for (Prodigy_Data_Table_Column__mdt col : columnMdts) {
            ColumnConfig cc = new ColumnConfig();
            cc.label = col.Column_Label__c;
            cc.fieldName = col.Field_API_Name__c;
            cc.cellStyle = col.Conditional_Formatting__c;
            cc.Display_Order = Integer.valueOf(col.Display_Order__c);
            cc.editable = col.Editable__c;
            cc.sortable = col.Sortable__c;
            
            if (col.Type__c == 'lookup' && String.isNotBlank(col.Lookup_Display_Field__c)) {
                relationshipFields+=','+col.Lookup_Display_Field__c; // e.g., Owner.Name
            }
            output.columns.add(cc);
        }
        
        String soql = 'SELECT Id';
        
        for (ColumnConfig cc : output.columns) {
            soql += ', ' + cc.fieldName;
        }
        if(relationshipFields !=''){soql+=relationshipFields;}
        soql += ' FROM ' + config.Object_API_Name__c;
        if (String.isNotBlank(config.Filter_Logic__c)) {
            soql += ' WHERE ' + config.Filter_Logic__c;
        }

    if (finalLimit != null) {
        soql += ' LIMIT ' + finalLimit;
    }
    if (finalOffset != null) {
        soql += ' OFFSET ' + finalOffset;
    }
configDetails.totalRecords = (Integer)Database.countQuery('SELECT COUNT() FROM ' + config.Object_API_Name__c + ' WHERE ' + config.Filter_Logic__c);
        output.config = configDetails;
        List<SObject> records =new list<Sobject>();
          
        if(isFlowContext==true){records=recordsfromFlow;}else{records=  Database.query(soql);}
        Map<String, Prodigy_Data_Table_Column__mdt> fieldToMetadataMap = new Map<String, Prodigy_Data_Table_Column__mdt>();
        for (Prodigy_Data_Table_Column__mdt c : columnMdts) {
            fieldToMetadataMap.put(c.Field_API_Name__c, c); // "OwnerId" → metadata
        }
        for (SObject record : records) {
            RecordWrapper wrapper = new RecordWrapper();
            wrapper.Id = record.Id;
            wrapper.cells = new List<CellData>();
            
            for (ColumnConfig col : output.columns) {
                CellData cell = new CellData();
                cell.fieldName = col.fieldName;
                cell.islink=false;
                Prodigy_Data_Table_Column__mdt colMdt = fieldToMetadataMap.get(col.fieldName); // Should be OwnerId, Contact__c, etc.
                Object val = record.get(col.fieldName); // ✅ Will now always work
                if (col.fieldName == 'Name' || colMdt.proX__Show_Record_Link__c==true) {
                    // Always show Name as a link to the record
                    String label = val != null ? String.valueOf(val) : '';
                    String url = '/' + record.get('Id');
                    
                    cell.isLink = true;
                    cell.value = label;
                    cell.url = url;
                }
                if (colMdt != null && colMdt.Type__c == 'lookup' && val != null) {
                    if (col.fieldName == 'OwnerId') {
                        // Special handling for OwnerId (polymorphic field: User or Group)
                        SObject ownerObj = record.getSObject('Owner');
                        String label = 'View';
                        if (ownerObj != null && ownerObj.get('Name') != null) {
                            label = String.valueOf(ownerObj.get('Name'));
                        }
                        String url = '/' + String.valueOf(val);
                        /*   cell.value = JSON.serialize(new Map<String, String>{
'label' => label,
'url' => url
});*/   cell.value = label;
                        cell.url = url;
                        cell.islink=true;
                        
                    } else {
                        // Handle other standard lookups
                        List<String> parts = new List<String>();
                        if (String.isNotBlank(colMdt.Lookup_Display_Field__c)) {
                            parts = colMdt.Lookup_Display_Field__c.split('\\.');
                        }
                        
                        if (parts.size() == 2) {
                            SObject lookupObj = record.getSObject(parts[0]);
                            cell.islink=true;
                            String label = (lookupObj != null && lookupObj.get(parts[1]) != null)
                                ? String.valueOf(lookupObj.get(parts[1]))
                                : 'View';
                            String url = '/' + String.valueOf(val);
                            /*   cell.value = JSON.serialize(new Map<String, String>{
'label' => label,
'url' => url
});*/ cell.value = label;
                            cell.url = url;
                        } else {
                            cell.value = val != null ? String.valueOf(val) : '';
                        }
                    }
                }
                else {
                    cell.value = val != null ? String.valueOf(val) : '';
                }
                
                cell.editable = col.editable;
                cell.style = String.isNotBlank(col.cellStyle) ? evaluateStyle(col.cellStyle, cell.value) : '';
                wrapper.cells.add(cell);
            }
            
            output.records.add(wrapper);
        }
        
        return output;
        
    }
    public static String evaluateStyle(String logic, String valueStr) {
        if (String.isBlank(logic)) return '';
        
        String cleanedValue = valueStr != null ? valueStr.trim() : '';
        
        for (String rule : logic.split('\\|\\|')) {
            rule = rule.trim();
            
            if (rule.startsWith('if:')) {
                String[] ifParts = rule.replace('if:', '').split('\\?');
                if (ifParts.size() != 2) continue;
                
                String condition = ifParts[0].trim(); // example: value=='Active'
                String style = ifParts[1].trim();     // example: background-color: green;
                
                if (evaluateCondition(condition, cleanedValue)) {
                    return style; }} else if (rule.startsWith('else=')) { return rule.replace('else=', '').trim();
                                                                        } }return '';
    }
    
    
    public static Boolean evaluateCondition(String condition, String valueStr) {
        if (String.isBlank(condition)) return false;
        String cleanedValue = valueStr != null ? valueStr.trim() : '';
        
        // Check equality
        if (condition.contains('==')) {
            String expected = condition.split('==')[1].replaceAll('\'', '').trim();
            return cleanedValue == expected;
        }
        
        if (condition.contains('!=')) {String expected = condition.split('!=')[1].replaceAll('\'', '').trim();return cleanedValue != expected;
                                      }
        
        // Check numeric comparisons only if value is numeric
        try {
            Decimal val = Decimal.valueOf(cleanedValue);
            if (condition.contains('>=')) {Decimal expected = Decimal.valueOf(condition.split('>=')[1].trim());return val >= expected;
                                          }if (condition.contains('<=')) {Decimal expected = Decimal.valueOf(condition.split('<=')[1].trim());return val <= expected;
                                                                         } if (condition.contains('>')) {Decimal expected = Decimal.valueOf(condition.split('>')[1].trim());return val > expected;
                                                                                                        }if (condition.contains('<')) {Decimal expected = Decimal.valueOf(condition.split('<')[1].trim());return val < expected;
                                                                                                                                      }
        } catch (Exception e) {
            // ignore if not numeric
        }
        
        return false;
    }
    
}