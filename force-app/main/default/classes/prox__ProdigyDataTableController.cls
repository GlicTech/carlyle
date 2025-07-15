/**
 * @description       : 
 * @author            : Pavan Patel(Prodigy)
 * @group             : 
 * @last modified on  : 07-04-2025
 * @last modified by  : Pavan Patel(Prodigy)
**/
// ProdigyDataTableController.cls
 /*
 * Created by Prodigy Ltd on 19/06/2025.
 *
 * Description: Mainclass ProdigyDataTableController
 *
 * Last modified by Pavan Patel in Prodigy on 19/06/2025.
*/
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
        
    }
    
    public class RecordWrapper {
        @AuraEnabled public String Id;
        @AuraEnabled public List<CellData> cells;
        
    }
    public class FlowAction {
    @AuraEnabled public String label;
    @AuraEnabled public String apiName;
}
    
    public class TableData {
        @AuraEnabled public List<ColumnConfig> columns;
        @AuraEnabled public List<RecordWrapper> records;
        @AuraEnabled public TableConfig config;
        @AuraEnabled public List<FlowAction> flowActions;
    }
    
    public class TableConfig {
        
        @AuraEnabled public Boolean autoRefresh;
        @AuraEnabled public Integer refreshInterval;
        @AuraEnabled public Boolean searchable;
         @AuraEnabled public String Name;
    }
    @AuraEnabled
    public static TableData getConfigAndData(String configDevName) {
        TableData output = new TableData();
        output.columns = new List<ColumnConfig>();
        output.records = new List<RecordWrapper>();
        
         Prodigy_Data_Table__mdt config;
        if (Test.isRunningTest() && mockMetadata != null) {
            config = mockMetadata;
        } else {
            config = [
                SELECT Object_API_Name__c, Auto_Refresh_Enabled__c, Filter_Logic__c,
                       Auto_Refresh_Interval__c, Enable_Search__c, label,
                       Row_Level_Flow_Actions__c
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
        output.config = configDetails;
       output.flowActions = new List<FlowAction>();

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
        List<Prodigy_Data_Table_Column__mdt> columnMdts;
        if (Test.isRunningTest() && mockColumns != null) {
            columnMdts = mockColumns;
        } else {
            columnMdts = [
                SELECT Field_API_Name__c, Column_Label__c, Conditional_Formatting__c,
                       Display_Order__c, Sortable__c, Editable__c
                FROM Prodigy_Data_Table_Column__mdt
                WHERE Prodigy_Data_Table__c = :config.Id
                ORDER BY Display_Order__c ASC
            ];
        }

        for (Prodigy_Data_Table_Column__mdt col : columnMdts) {
            ColumnConfig cc = new ColumnConfig();
            cc.label = col.Column_Label__c;
            cc.fieldName = col.Field_API_Name__c;
            cc.cellStyle = col.Conditional_Formatting__c;
            cc.Display_Order = Integer.valueOf(col.Display_Order__c);
            cc.editable = col.Editable__c;
            cc.sortable = col.Sortable__c;
            output.columns.add(cc);
        }

        String soql = 'SELECT Id';
        for (ColumnConfig cc : output.columns) {
            soql += ', ' + cc.fieldName;
        }
        soql += ' FROM ' + config.Object_API_Name__c;
        if (String.isNotBlank(config.Filter_Logic__c)) {
            soql += ' WHERE ' + config.Filter_Logic__c;
        }

        List<SObject> records = Database.query(soql);
        for (SObject record : records) {
            RecordWrapper wrapper = new RecordWrapper();
            wrapper.Id = record.Id;
            wrapper.cells = new List<CellData>();

            for (ColumnConfig col : output.columns) {
                CellData cell = new CellData();
                cell.fieldName = col.fieldName;
                Object val = record.get(col.fieldName);
                cell.value = val != null ? String.valueOf(val) : '';
                cell.editable = col.editable;
                if (String.isNotBlank(col.cellStyle)) {
                    cell.style = evaluateStyle(col.cellStyle, cell.value);
                } else {
                    cell.style = '';
                }
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
            }
            if (condition.contains('<=')) {Decimal expected = Decimal.valueOf(condition.split('<=')[1].trim());return val <= expected;
            }
            if (condition.contains('>')) {Decimal expected = Decimal.valueOf(condition.split('>')[1].trim());return val > expected;
            }
            if (condition.contains('<')) {Decimal expected = Decimal.valueOf(condition.split('<')[1].trim());return val < expected;
            }
        } catch (Exception e) {
            // ignore if not numeric
        }
        
        return false;
    }

}