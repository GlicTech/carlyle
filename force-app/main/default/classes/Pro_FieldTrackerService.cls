/* 
Developed by:Pavan Patel(Prodigy)
Description:Used to track the histories
    Singleton Class implements the custom field history
    tracking dynamically through custom metadata configuration
*/
public without sharing class Pro_FieldTrackerService {
	// Static members
	private static Pro_FieldTrackerService instance;

	public static Pro_FieldTrackerService getInstance(String objectName) {
		if (instance == null) {
			instance = new Pro_FieldTrackerService(objectName);
		}
		return instance;
	}

	// instance members
	private String objectName;
	private Set<String> fields;
	private List<Field_Tracker_Field__mdt> trackedFields;
	private Field_Tracker_Object__mdt ftObject;

	private Pro_FieldTrackerService(String objectName) {
		this.objectName = objectName;

		ftObject = Field_Tracker_Object__mdt.getInstance(objectName);

		if (ftObject.Is_Active__c) {
			trackedFields = [
				SELECT Field__c, Field_Label__c, Is_Long_Text__c,Is_user_field__c 
				FROM Field_Tracker_Field__mdt
				WHERE
					Field_Tracker_Object__c = :ftObject.Id
					AND Is_Active__c = TRUE
			];
			fields = Schema.getGlobalDescribe()
				.get(ftObject.Object__c)
				.getDescribe()
				.fields.getMap()
				.keySet();
		}
	}

	// OldMap should be null in case of Insert trigger.
	public void saveFieldHistories(
		List<SObject> records,
		Map<Id, SObject> oldMap
	) {
       map<string,user>userdetails= new Map<string, user>([select id,name from user where isactive=true]);
		if (
			ftObject != null &&
			ftObject.Is_Active__c &&
			trackedFields != null &&
			!trackedFields.isEmpty()
		) {
			List<pro_History_Tracking__c> fieldHistories = new List<pro_History_Tracking__c>();
			Boolean isNew = oldMap == null;
			for (SObject record : records) {
				SObject oldRecord = oldMap?.get(record.Id);
				for (Field_Tracker_Field__mdt trackedField : trackedFields) {
					if (
						String.isNotBlank(trackedField.Field__c) &&
						fields.contains(trackedField.Field__c.toLowerCase()) &&
						(isNew && record.get(trackedField.Field__c) != null ||
						!isNew &&
						oldRecord.get(trackedField.Field__c) !=
						record.get(trackedField.Field__c))
					) {
						pro_History_Tracking__c history = new pro_History_Tracking__c(
							Pro_Object_Name__c = objectName,
							Pro_Field_Name__c = trackedField.Field_Label__c,
							Pro_Field_Api_Name__c = trackedField.Field__c,
							Pro_Parent_Record_Id__c = record.Id
						);

						if (trackedField.Is_long_text__c) {
							history.pro_New_Value__c = String.valueOf(
								record.get(trackedField.Field__c)
							);
							history.pro_Old_Value__c = String.valueOf(
								oldRecord?.get(trackedField.Field__c)
							);
                        } else if(trackedField.Is_user_field__c){
                             user newusr=userdetails.get(
								string.valueof(record.get(trackedField.Field__c))
							);
                         history.pro_New_Value__c =string.valueof(newusr.name);
                              user oldusr=userdetails.get(
								string.valueof(oldRecord?.get(trackedField.Field__c))
							);
							history.pro_Old_Value__c =string.valueof(oldusr.name);
							
                        }
                        else {
							history.pro_New_Value__c = String.valueOf(
								record.get(trackedField.Field__c)
							);
							history.pro_Old_Value__c = String.valueOf(
								oldRecord?.get(trackedField.Field__c)
							);
							history.Is_Long_Text__c = true;
						}
						fieldHistories.add(history);
					}
				}
			}
			insert fieldHistories;
		}
	}
}