/**
 * GT-15 — Phase-Specific Checklist Completion Notification Handler
 *
 * Called by the pro_Checklist_Item_Orchestrator flow when a checklist item
 * transitions to Completed or Necessary = No. Evaluates per-phase completion
 * and sends configurable bell + email notifications via pro_Notification_Config__mdt.
 */
public with sharing class pro_ChecklistNotificationHandler {

    private static final String LINK_TARGET_ASSET_IN_DEAL = 'AssetInDeal';
    private static final String STATUS_COMPLETED = 'Completed';
    private static final String NECESSARY_NO = 'No';

    // Injected in tests to bypass CMDT query limitations
    @TestVisible
    private static Map<String, pro_Notification_Config__mdt> configOverride;

    // Tracks which phase events fired — used by test class to assert notification behaviour
    @TestVisible
    private static List<String> firedEventTypes = new List<String>();

    @InvocableMethod(
        label       = 'Send Checklist Completion Notification'
        description = 'Sends phase-specific bell and email notifications when all checklist items for a phase are complete.'
        category    = 'Checklist'
    )
    public static void handleChecklistCompletion(List<Id> assetInDealIds) {

        if (assetInDealIds == null || assetInDealIds.isEmpty()) {
            return;
        }

        Set<Id> aidIdSet = new Set<Id>(assetInDealIds);

        // 1. Query all checklist items including phase
        Map<Id, Map<String, List<pro_Checklist_Item__c>>> itemsByAidAndPhase =
            groupItemsByAidAndPhase(aidIdSet);

        // 2. Determine which AiD+phase combos are fully satisfied
        List<PhaseEvent> triggeredEvents = identifyCompletedPhases(itemsByAidAndPhase);

        if (triggeredEvents.isEmpty()) {
            return;
        }

        // 3. Load notification configs
        Map<String, pro_Notification_Config__mdt> configMap = loadConfigs();

        // 4. Query AiD records with Deal relationship
        Set<Id> completedAidIds = new Set<Id>();
        for (PhaseEvent pe : triggeredEvents) {
            completedAidIds.add(pe.aidId);
        }

        Map<Id, leaseworks__Aircraft_Proposal__c> aidMap =
            new Map<Id, leaseworks__Aircraft_Proposal__c>([
                SELECT Id, Name,
                       leaseworks__Marketing_Activity__c,
                       leaseworks__Marketing_Activity__r.Name
                FROM   leaseworks__Aircraft_Proposal__c
                WHERE  Id IN :completedAidIds
                WITH SECURITY_ENFORCED
            ]);

        // 5. Fetch recipients
        List<pro_Notification_Recipient__mdt> recipients = [
            SELECT pro_Recipient_Username__c
            FROM   pro_Notification_Recipient__mdt
            WHERE  pro_Active__c = true
            WITH SECURITY_ENFORCED
        ];

        if (recipients.isEmpty()) {
            return;
        }

        Set<String> usernames = new Set<String>();
        for (pro_Notification_Recipient__mdt r : recipients) {
            if (String.isNotBlank(r.pro_Recipient_Username__c)) {
                usernames.add(r.pro_Recipient_Username__c);
            }
        }

        Map<String, Id> usernameToId = new Map<String, Id>();
        for (User u : [
            SELECT Id, Username
            FROM   User
            WHERE  Username IN :usernames
            AND    IsActive  = true
            WITH SECURITY_ENFORCED
        ]) {
            usernameToId.put(u.Username, u.Id);
        }

        // 6. Resolve notification type
        CustomNotificationType notifType = null;
        List<CustomNotificationType> notifTypes = [
            SELECT Id
            FROM   CustomNotificationType
            WHERE  DeveloperName = 'pro_Checklist_Complete'
            WITH SECURITY_ENFORCED
            LIMIT  1
        ];
        if (!notifTypes.isEmpty()) {
            notifType = notifTypes[0];
        }

        // 7. Build and send notifications
        String orgBaseUrl = Url.getOrgDomainUrl().toExternalForm();
        String signOff = System.Label.ProPO_Checklist_SignOff;
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (PhaseEvent pe : triggeredEvents) {
            pro_Notification_Config__mdt config = configMap.get(pe.eventType);
            if (config == null) {
                System.debug(LoggingLevel.WARN,
                    'pro_ChecklistNotificationHandler: No active pro_Notification_Config__mdt record found for event type "'
                    + pe.eventType + '" on Asset in Deal ' + pe.aidId
                    + '. Create a CMDT record with pro_Event_Type__c = "' + pe.eventType + '".');
                continue;
            }

            leaseworks__Aircraft_Proposal__c aid = aidMap.get(pe.aidId);
            if (aid == null) {
                continue;
            }

            String assetName = aid.Name;
            String dealName = aid.leaseworks__Marketing_Activity__r != null
                ? aid.leaseworks__Marketing_Activity__r.Name
                : '';
            Id dealId = aid.leaseworks__Marketing_Activity__c;
            Id targetId = resolveTargetId(config.pro_Link_Target__c, pe.aidId, dealId);
            String recordLink = orgBaseUrl + '/' + targetId;

            Map<String, String> tokens = new Map<String, String>{
                'AssetName'      => assetName,
                'DealName'       => dealName,
                'Phase'          => pe.phase,
                'CompletionDate' => Date.today().format(),
                'RecordLink'     => recordLink
            };

            String keyFieldsBlock = buildKeyFieldsBlock(config.pro_Key_Fields__c, tokens);
            tokens.put('KeyFields', keyFieldsBlock);

            String emailSubject = resolveMergeFields(config.pro_Email_Subject__c, tokens);
            String emailBody = resolveMergeFields(config.pro_Email_Body__c, tokens)
                + '\n\n' + signOff;
            String bellTitle = resolveMergeFields(config.pro_Bell_Title__c, tokens);
            String bellBody = resolveMergeFields(config.pro_Bell_Body__c, tokens);

            Set<String> recipientUserIds = new Set<String>();

            for (pro_Notification_Recipient__mdt r : recipients) {
                Id userId = usernameToId.get(r.pro_Recipient_Username__c);
                if (userId == null) {
                    continue;
                }

                recipientUserIds.add(String.valueOf(userId));

                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                email.setTargetObjectId(userId);
                email.setSaveAsActivity(false);
                email.setSubject(emailSubject);
                email.setPlainTextBody(emailBody);
                emails.add(email);
            }

            if (notifType != null && !recipientUserIds.isEmpty()) {
                try {
                    Messaging.CustomNotification notif = new Messaging.CustomNotification();
                    notif.setNotificationTypeId(notifType.Id);
                    notif.setTargetId(targetId);
                    notif.setTitle(bellTitle);
                    notif.setBody(bellBody);
                    notif.send(recipientUserIds);
                } catch (Exception ex) {
                    System.debug(LoggingLevel.WARN,
                        'pro_ChecklistNotificationHandler: Bell notification failed for Asset in Deal '
                        + pe.aidId + ': ' + ex.getMessage());
                }
            }
        }

        if (!emails.isEmpty()) {
            try {
                Messaging.sendEmail(emails, false);
            } catch (Exception ex) {
                System.debug(LoggingLevel.WARN,
                    'pro_ChecklistNotificationHandler: Email send failed for '
                    + emails.size() + ' recipient(s): ' + ex.getMessage());
            }
        }
    }

    // -------------------------------------------------------------------------
    // Private helpers
    // -------------------------------------------------------------------------

    private static Map<Id, Map<String, List<pro_Checklist_Item__c>>> groupItemsByAidAndPhase(
        Set<Id> aidIdSet
    ) {
        Map<Id, Map<String, List<pro_Checklist_Item__c>>> result =
            new Map<Id, Map<String, List<pro_Checklist_Item__c>>>();

        for (Id aidId : aidIdSet) {
            result.put(aidId, new Map<String, List<pro_Checklist_Item__c>>());
        }

        for (pro_Checklist_Item__c item : [
            SELECT Id, pro_Status__c, pro_Necessary__c, pro_Phase__c, pro_Asset_in_Deal__c
            FROM   pro_Checklist_Item__c
            WHERE  pro_Asset_in_Deal__c IN :aidIdSet
            WITH SECURITY_ENFORCED
        ]) {
            Map<String, List<pro_Checklist_Item__c>> phaseMap =
                result.get(item.pro_Asset_in_Deal__c);

            String phase = item.pro_Phase__c;
            if (String.isBlank(phase)) {
                continue;
            }

            if (!phaseMap.containsKey(phase)) {
                phaseMap.put(phase, new List<pro_Checklist_Item__c>());
            }
            phaseMap.get(phase).add(item);
        }

        return result;
    }

    private static List<PhaseEvent> identifyCompletedPhases(
        Map<Id, Map<String, List<pro_Checklist_Item__c>>> itemsByAidAndPhase
    ) {
        List<PhaseEvent> events = new List<PhaseEvent>();

        for (Id aidId : itemsByAidAndPhase.keySet()) {
            Map<String, List<pro_Checklist_Item__c>> phaseMap = itemsByAidAndPhase.get(aidId);

            for (String phase : phaseMap.keySet()) {
                List<pro_Checklist_Item__c> items = phaseMap.get(phase);

                if (items.isEmpty()) {
                    continue;
                }

                Boolean allDone = true;
                for (pro_Checklist_Item__c item : items) {
                    Boolean isComplete = (item.pro_Status__c == STATUS_COMPLETED);
                    Boolean isUnnecessary = (item.pro_Necessary__c == NECESSARY_NO);
                    if (!isComplete && !isUnnecessary) {
                        allDone = false;
                        break;
                    }
                }

                if (allDone) {
                    String eventType = phase.replace('-', '_').replace(' ', '_') + '_Complete';
                    events.add(new PhaseEvent(aidId, phase, eventType));
                    firedEventTypes.add(eventType);
                }
            }
        }

        return events;
    }

    private static Map<String, pro_Notification_Config__mdt> loadConfigs() {
        if (configOverride != null) {
            return configOverride;
        }

        Map<String, pro_Notification_Config__mdt> configMap =
            new Map<String, pro_Notification_Config__mdt>();

        for (pro_Notification_Config__mdt config : [
            SELECT pro_Event_Type__c, pro_Email_Subject__c, pro_Email_Body__c,
                   pro_Bell_Title__c, pro_Bell_Body__c, pro_Key_Fields__c,
                   pro_Link_Target__c, pro_Active__c
            FROM   pro_Notification_Config__mdt
            WHERE  pro_Active__c = true
        ]) {
            configMap.put(config.pro_Event_Type__c, config);
        }

        return configMap;
    }

    @TestVisible
    private static String resolveMergeFields(String template, Map<String, String> tokens) {
        if (String.isBlank(template)) {
            return '';
        }

        String resolved = template;
        for (String tokenName : tokens.keySet()) {
            String tokenValue = tokens.get(tokenName);
            resolved = resolved.replace(
                '{' + tokenName + '}',
                tokenValue != null ? tokenValue : ''
            );
        }
        return resolved;
    }

    @TestVisible
    private static String buildKeyFieldsBlock(
        String keyFieldsConfig,
        Map<String, String> tokens
    ) {
        if (String.isBlank(keyFieldsConfig)) {
            return '';
        }

        List<String> lines = new List<String>();

        for (String pair : keyFieldsConfig.split(',')) {
            pair = pair.trim();
            if (String.isBlank(pair)) {
                continue;
            }

            List<String> parts = pair.split(':');
            if (parts.size() != 2) {
                continue;
            }

            String label = parts[0].trim();
            String tokenName = parts[1].trim();
            String value = tokens.containsKey(tokenName) ? tokens.get(tokenName) : '';
            lines.add(label + ': ' + (value != null ? value : ''));
        }

        return String.join(lines, '\n');
    }

    @TestVisible
    private static Id resolveTargetId(String linkTarget, Id aidId, Id dealId) {
        if (linkTarget == LINK_TARGET_ASSET_IN_DEAL) {
            return aidId;
        }
        return dealId != null ? dealId : aidId;
    }

    // -------------------------------------------------------------------------
    // Inner class for phase completion events
    // -------------------------------------------------------------------------

    private class PhaseEvent {
        public Id aidId;
        public String phase;
        public String eventType;

        public PhaseEvent(Id aidId, String phase, String eventType) {
            this.aidId = aidId;
            this.phase = phase;
            this.eventType = eventType;
        }
    }
}