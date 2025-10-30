global with sharing class Pro_NintexInvoiceTrueUpDS implements Loop.IApexDataSource {

    private static final String OBJ_INVOICE  = 'TrueUpInvoice';
    private static final String OBJ_RATE     = 'InvoiceRateRow';
    private static final String OBJ_TOTALS   = 'TrueUpTotals';

    public Set<String> getGlobalDescribe() {  
        return new Set<String>{ OBJ_INVOICE, OBJ_RATE, OBJ_TOTALS };
    }

    public Set<String> getChildRelationships(String objectName) {  
        if (objectName == OBJ_INVOICE) 
            return new Set<String>{ OBJ_RATE, OBJ_TOTALS };    
        return new Set<String>();   
    }

    public List<Loop.ExternalData.DataObject> describeObjects(List<String> objectNames) {
        List<Loop.ExternalData.DataObject> out = new List<Loop.ExternalData.DataObject>();
        for (String name : objectNames) {
            List<Loop.ExternalData.FieldInfo> f = new List<Loop.ExternalData.FieldInfo>();

            if (name == OBJ_INVOICE) {
                f.add(new Loop.ExternalData.FieldInfo('Id',           Schema.DisplayType.Id));
                f.add(new Loop.ExternalData.FieldInfo('InvoiceName',  Schema.DisplayType.String));
                f.add(new Loop.ExternalData.FieldInfo('InvoiceDate',  Schema.DisplayType.Date));
                f.add(new Loop.ExternalData.FieldInfo('OldTotal',     Schema.DisplayType.String));
                f.add(new Loop.ExternalData.FieldInfo('NewTotal',     Schema.DisplayType.String));
                f.add(new Loop.ExternalData.FieldInfo('Difference',   Schema.DisplayType.String));
            }
            else if (name == OBJ_RATE) {
                f.add(new Loop.ExternalData.FieldInfo('Id',            Schema.DisplayType.Id));
                f.add(new Loop.ExternalData.FieldInfo('InvoiceId',     Schema.DisplayType.Id));
                f.add(new Loop.ExternalData.FieldInfo('LineItemId',    Schema.DisplayType.Id));
                f.add(new Loop.ExternalData.FieldInfo('UtilizationId', Schema.DisplayType.Id));
                f.add(new Loop.ExternalData.FieldInfo('Description',   Schema.DisplayType.String));
                f.add(new Loop.ExternalData.FieldInfo('Utilization',   Schema.DisplayType.String));
                f.add(new Loop.ExternalData.FieldInfo('RateUOM',       Schema.DisplayType.String));
                f.add(new Loop.ExternalData.FieldInfo('Rate',          Schema.DisplayType.String));
                f.add(new Loop.ExternalData.FieldInfo('Amount',        Schema.DisplayType.String));

                f.add(new Loop.ExternalData.FieldInfo('UtilOldAmount',      Schema.DisplayType.String));
                f.add(new Loop.ExternalData.FieldInfo('UtilNewAmount',      Schema.DisplayType.String));
                f.add(new Loop.ExternalData.FieldInfo('UtilDiffAmount',     Schema.DisplayType.String));
                f.add(new Loop.ExternalData.FieldInfo('TotalUnitsForUtil',  Schema.DisplayType.String));
                f.add(new Loop.ExternalData.FieldInfo('OldDerivedUnitPrice',Schema.DisplayType.String));
                f.add(new Loop.ExternalData.FieldInfo('UnitPriceDiff',      Schema.DisplayType.String));
            }
            else if (name == OBJ_TOTALS) {
                f.add(new Loop.ExternalData.FieldInfo('InvoiceId', Schema.DisplayType.Id));
                f.add(new Loop.ExternalData.FieldInfo('LineCount', Schema.DisplayType.String));
                f.add(new Loop.ExternalData.FieldInfo('OldTotal',  Schema.DisplayType.String));
                f.add(new Loop.ExternalData.FieldInfo('NewTotal',  Schema.DisplayType.String));
                f.add(new Loop.ExternalData.FieldInfo('Difference',Schema.DisplayType.String));
            }
            out.add(new Loop.ExternalData.DataObject(name, f));
        }
        return out;
    }

    public Loop.ExternalData.QueryResultSet query(Loop.ExternalData.QueryRequestInfo requestInfo) {
        Id invoiceId = requestInfo.RecordId;

        Map<String, Loop.ExternalData.QueryResult> qr = new Map<String, Loop.ExternalData.QueryResult>();   
        for (String obj : requestInfo.getObjectNames()) {  
            qr.put(obj, new Loop.ExternalData.QueryResult(obj, getFieldOrder(obj))); 
        }

        leaseworks__Invoice__c inv = [
            SELECT Id, Name, leaseworks__Invoice_Date__c,
                   (SELECT Id, Name, leaseworks__Total_Line_Amount__c,
                           leaseworks__Assembly_Utilization__c,
                           leaseworks__Assembly_Utilization__r.Name
                      FROM leaseworks__Invoice_Line_Items__r
                      WHERE leaseworks__Total_Line_Amount__c != 0)
              FROM leaseworks__Invoice__c
             WHERE Id = :invoiceId
             LIMIT 1
        ];

        Set<Id> utilIds = new Set<Id>();
        Map<Id, Id> lineByUtil = new Map<Id, Id>();          
        Map<Id, Decimal> oldAmtByUtil = new Map<Id, Decimal>();    
        Decimal oldTotal = 0; 
        Integer lineCount = 0;   

        for (leaseworks__Invoice_Line_Item__c li : inv.leaseworks__Invoice_Line_Items__r) { 
            lineCount++;      
            Decimal oldAmt = (li.leaseworks__Total_Line_Amount__c == null ? 0 : li.leaseworks__Total_Line_Amount__c);   
            oldTotal += oldAmt;   
            if (li.leaseworks__Assembly_Utilization__c != null) {  Id u = li.leaseworks__Assembly_Utilization__c;  utilIds.add(u);  if (!lineByUtil.containsKey(u)) lineByUtil.put(u, li.Id); oldAmtByUtil.put(u, (oldAmtByUtil.containsKey(u) ? oldAmtByUtil.get(u) : 0) + oldAmt);
            }
        }  

        Decimal newTotal = 0;   
        Map<Id, Decimal> newAmtByUtil   = new Map<Id, Decimal>();   
        Map<Id, Decimal> totalUnitsByUtil = new Map<Id, Decimal>();   

        if (!utilIds.isEmpty()) {    for (leaseworks__Utilization_Report_List_Item__c u :
                [SELECT Id, Name, leaseworks__Assembly_MR_Info__r.Name,
                        (SELECT Id, Name,
                                leaseworks__Net_Units__c,
                                leaseworks__Effective_Unit_F__c,
                                leaseworks__Effective_Rate__c,
                                leaseworks__MR_Total__c
                           FROM leaseworks__Supplemental_Rent_Utilization_Rates__r)
                   FROM leaseworks__Utilization_Report_List_Item__c
                  WHERE Id IN :utilIds]) {    

                String asm = (u.leaseworks__Assembly_MR_Info__r != null) ? u.leaseworks__Assembly_MR_Info__r.Name : '';     Decimal utilNew = 0, utilUnits = 0; 

                for (leaseworks__Supplemental_Rent_Utilization_Rate__c rAgg : u.leaseworks__Supplemental_Rent_Utilization_Rates__r) {    utilNew   += (rAgg.leaseworks__MR_Total__c  == null ? 0 : rAgg.leaseworks__MR_Total__c);
                    utilUnits += (rAgg.leaseworks__Net_Units__c == null ? 0 : rAgg.leaseworks__Net_Units__c); 
                } 
                newTotal += utilNew;  newAmtByUtil.put(u.Id, utilNew);   totalUnitsByUtil.put(u.Id, utilUnits);

                if (qr.containsKey(OBJ_RATE)) {    
                    for (leaseworks__Supplemental_Rent_Utilization_Rate__c r : u.leaseworks__Supplemental_Rent_Utilization_Rates__r) {   
                        String description = (String.isNotBlank(asm) ? ' ' + asm : ''); Decimal amount     = (r.leaseworks__MR_Total__c == null ? 0 : r.leaseworks__MR_Total__c);  Decimal utilOld   = oldAmtByUtil.containsKey(u.Id) ? oldAmtByUtil.get(u.Id) : 0;  
                        Decimal utilNew2  = newAmtByUtil.containsKey(u.Id) ? newAmtByUtil.get(u.Id) : 0;   Decimal utilDiff  = utilNew2 - utilOld;   Decimal units     = totalUnitsByUtil.containsKey(u.Id) ? totalUnitsByUtil.get(u.Id) : 0; Decimal oldUnit   = (units != 0) ? (utilOld / units) : null;  Decimal unitDiff  = (oldUnit == null || r.leaseworks__Effective_Rate__c == null) ? null : (r.leaseworks__Effective_Rate__c - oldUnit); 

                        qr.get(OBJ_RATE).rows.add(new List<String>{    String.valueOf(r.Id),   String.valueOf(inv.Id),    lineByUtil.containsKey(u.Id) ? String.valueOf(lineByUtil.get(u.Id)) : '',  
                            String.valueOf(u.Id),    description,  formatDecimal(r.leaseworks__Net_Units__c, 2),  String.valueOf(r.leaseworks__Effective_Unit_F__c), formatDecimal(r.leaseworks__Effective_Rate__c, 2),  formatDecimal(amount, 2),   formatDecimal(utilOld, 2),    formatDecimal(utilNew2, 2),  formatDecimal(utilDiff, 2),   formatDecimal(units, 2),               
                            (oldUnit == null ? null : formatDecimal(oldUnit, 2)),     (unitDiff == null ? null : formatDecimal(unitDiff, 2))            
                        });
                    }
                }
            }
        }

        Decimal difference = newTotal - oldTotal;

        if (qr.containsKey(OBJ_INVOICE)) {      qr.get(OBJ_INVOICE).rows.add(new List<String>{   String.valueOf(inv.Id),   inv.Name,      inv.get('leaseworks__Invoice_Date__c') != null ? String.valueOf(inv.get('leaseworks__Invoice_Date__c')) : '',  formatDecimal(oldTotal,2),   formatDecimal(newTotal,2),   formatDecimal(difference,2) 
            });
        }  

        if (qr.containsKey(OBJ_TOTALS)) {     qr.get(OBJ_TOTALS).rows.add(new List<String>{    String.valueOf(inv.Id),   String.valueOf(lineCount),   formatDecimal(oldTotal,2),  formatDecimal(newTotal,2),  formatDecimal(difference,2)
            });      
        } 

        Loop.ExternalData.QueryResultSet rs = new Loop.ExternalData.QueryResultSet(); 
        for (Loop.ExternalData.QueryResult q : qr.values()) rs.add(q);
        return rs;
    }   

    private List<String> getFieldOrder(String obj) {    if (obj == OBJ_INVOICE)       return new List<String>{ 'Id','InvoiceName','InvoiceDate','OldTotal','NewTotal','Difference' };   if (obj == OBJ_RATE)    return new List<String>{ 'Id','InvoiceId','LineItemId','UtilizationId','Description',   'Utilization','RateUOM','Rate','Amount',   'UtilOldAmount','UtilNewAmount','UtilDiffAmount',   'TotalUnitsForUtil','OldDerivedUnitPrice','UnitPriceDiff' };   if (obj == OBJ_TOTALS)      return new List<String>{ 'InvoiceId','LineCount','OldTotal','NewTotal','Difference' };  return new List<String>();
    }

    private static String formatDecimal(Decimal val, Integer scale) { return (val == null) ? null : String.valueOf(val.setScale(scale)); 
    }
}