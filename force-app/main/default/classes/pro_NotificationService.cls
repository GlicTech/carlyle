/**
 * Invocable Apex service backing the Prodigy Notification Framework.
 * Reads pro_Notification_Config__mdt by event type, resolves merge tokens
 * and recipients, dispatches email + in-app bell notifications.
 * See LESSON-001 (notification architecture) and LESSON-005 (prefix-syntax
 * recipients) in ~/.claude/skills/lessons-learned/SKILL.md.
 *
 * Operational telemetry channel: System.debug at LoggingLevel.WARN/ERROR.
 * Future upgrade path: publish pro_Notification_Error__e Platform Event
 * for production visibility (see SF-005 in the v2 code review).
 */
public without sharing class pro_NotificationService {

    public class NotificationRequest {
        @InvocableVariable(required=true label='Record ID')
        public Id recordId;

        @InvocableVariable(required=true label='Config Name' description='DeveloperName of the pro_Notification_Config__mdt record to use.')
        public String configName;
    }

    @TestVisible
    private static pro_Notification_Config__mdt configOverride;

    @TestVisible
    private static List<Id> recipientIdsOverride;

    @TestVisible
    private static SObject hostRecordOverride;

    // Test-visible instrumentation: Limits.getEmailInvocations() isn't reliable
    // in every sandbox, so we count our own sendEmail() / sendBell() invocations.
    @TestVisible
    private static Integer emailInvocationCount = 0;

    @TestVisible
    private static Integer bellInvocationCount = 0;

    private static final Set<String> COMPUTED_TOKENS = new Set<String>{
        'RecordLink', 'Today'
    };

    // Salesforce SOQL permits up to 5 parent relationship hops per field reference.
    private static final Integer MAX_RELATIONSHIP_HOPS = 5;

    // Guardrail: a broad profile: or group: expansion in a large org could
    // resolve thousands of users and exhaust heap. Truncate + WARN above this.
    private static final Integer MAX_RECIPIENTS = 2000;

    // Transaction-scoped caches (MF-001): populate on demand, reuse within the
    // same Apex transaction to keep SOQL / describe work O(unique keys) rather
    // than O(requests).
    private static Map<String, Id> notifTypeIdCache = new Map<String, Id>();
    private static Map<String, Schema.DescribeSObjectResult> describeCache = new Map<String, Schema.DescribeSObjectResult>();

    @TestVisible
    private class RecipientBuckets {
        @TestVisible Set<String> usernames = new Set<String>();
        @TestVisible Set<String> groupNames = new Set<String>();
        @TestVisible Set<String> profileNames = new Set<String>();
        @TestVisible Set<String> profileDevNames = new Set<String>();
        @TestVisible Set<String> fieldPaths = new Set<String>();
    }

    @InvocableMethod(
        label='Send CMDT Notification'
        description='Reads notification config from Custom Metadata, resolves merge tokens against the record, and sends email and/or bell notifications.'
        category='Notifications'
    )
    public static void sendNotifications(List<NotificationRequest> requests) {
        if (requests == null || requests.isEmpty()) return;

        // MF-001: bulk-load all configs needed in this transaction in ONE SOQL.
        // When configOverride is set (test path) we bypass the bulk-load entirely
        // and reuse the override for every request.
        // Config lookup is keyed by the CMDT record DeveloperName (unique by definition).
        Map<String, pro_Notification_Config__mdt> configsByName = new Map<String, pro_Notification_Config__mdt>();
        if (configOverride == null) {
            Set<String> configNames = new Set<String>();
            for (NotificationRequest req : requests) {
                if (req != null && String.isNotBlank(req.configName)) {
                    configNames.add(req.configName);
                }
            }
            if (!configNames.isEmpty()) {
                for (pro_Notification_Config__mdt cfg : [
                    SELECT Id, DeveloperName, pro_Active__c,
                           pro_Email_Enabled__c, pro_Bell_Enabled__c,
                           pro_Email_Subject__c, pro_Email_Body__c,
                           pro_Bell_Title__c, pro_Bell_Body__c,
                           pro_Recipients__c, pro_Notification_Type__c
                    FROM pro_Notification_Config__mdt
                    WHERE DeveloperName IN :configNames
                      AND pro_Active__c = true
                ]) {
                    configsByName.put(cfg.DeveloperName, cfg);
                }
            }
        }

        for (NotificationRequest req : requests) {
            if (req == null) continue;
            pro_Notification_Config__mdt config = configOverride != null
                ? configOverride
                : configsByName.get(req.configName);
            if (config == null) continue;

            try {
                processNotification(req.recordId, config);
            } catch (QueryException qe) {
                System.debug(LoggingLevel.ERROR,
                    'pro_NotificationService QUERY ERROR [' + req.configName
                    + '] ' + qe.getMessage() + ' | ' + qe.getStackTraceString());
            } catch (DmlException de) {
                System.debug(LoggingLevel.ERROR,
                    'pro_NotificationService DML ERROR [' + req.configName
                    + '] ' + de.getMessage() + ' | ' + de.getStackTraceString());
            } catch (System.EmailException ee) {
                System.debug(LoggingLevel.ERROR,
                    'pro_NotificationService EMAIL ERROR [' + req.configName
                    + '] ' + ee.getMessage() + ' | ' + ee.getStackTraceString());
            }
            // SF-005: LimitException, NullPointerException, SObjectException and
            // other programming-error types are NOT caught here — they propagate
            // so tests and runtime monitoring surface real bugs.
        }
    }

    private static void processNotification(Id recordId, pro_Notification_Config__mdt config) {
        // SF-007: configOverride bypasses the SOQL-level Active filter, so
        // re-check explicitly here to keep opt-in semantics tight.
        if (config == null || config.pro_Active__c != true) return;

        Boolean emailOn = config.pro_Email_Enabled__c == true;
        Boolean bellOn  = config.pro_Bell_Enabled__c == true && String.isNotBlank(config.pro_Notification_Type__c);
        if (!emailOn && !bellOn) return;

        RecipientBuckets buckets = parseRecipients(config.pro_Recipients__c);

        Set<String> templateFieldTokens = new Set<String>();
        for (String template : new List<String>{
            config.pro_Email_Subject__c, config.pro_Email_Body__c,
            config.pro_Bell_Title__c, config.pro_Bell_Body__c
        }) {
            for (String token : extractTokens(template)) {
                if (!COMPUTED_TOKENS.contains(token)) {
                    templateFieldTokens.add(token);
                }
            }
        }

        String objectName = recordId.getSObjectType().getDescribe().getName();

        // SF-001: single validator handles both template tokens (max 5 hops —
        // now symmetric with field: recipients) and field: recipient paths.
        Set<String> validTemplateFields = new Set<String>();
        for (String token : templateFieldTokens) {
            String validated = validateFieldPath(objectName, token, MAX_RELATIONSHIP_HOPS);
            if (validated != null) validTemplateFields.add(validated);
        }

        // MF-002: whitelist every field: path against the schema before it
        // enters the dynamic SOQL SELECT list. Drop + WARN anything that
        // doesn't fully resolve.
        Set<String> validFieldPaths = new Set<String>();
        for (String path : buckets.fieldPaths) {
            String validated = validateFieldPath(objectName, path, MAX_RELATIONSHIP_HOPS);
            if (validated != null) {
                validFieldPaths.add(validated);
            } else {
                System.debug(LoggingLevel.WARN,
                    'pro_NotificationService: dropping unresolvable field: path "' + path
                    + '" on ' + objectName);
            }
        }

        Set<String> queryFields = new Set<String>();
        queryFields.addAll(validTemplateFields);
        queryFields.addAll(validFieldPaths);

        SObject record = queryRecord(recordId, objectName, queryFields);
        if (record == null) return;

        Set<Id> fieldUserIds = resolveFieldUserIds(record, validFieldPaths);

        Map<String, String> tokenMap = new Map<String, String>();
        tokenMap.put('RecordLink', URL.getOrgDomainUrl().toExternalForm() + '/' + recordId);
        tokenMap.put('Today', Date.today().format());
        for (String field : validTemplateFields) {
            Object val = getFieldValue(record, field);
            tokenMap.put(field, formatFieldValue(val));
        }

        String emailSubject = resolveTokens(config.pro_Email_Subject__c, tokenMap);
        String emailBody    = resolveTokens(config.pro_Email_Body__c,    tokenMap);
        String bellTitle    = resolveTokens(config.pro_Bell_Title__c,    tokenMap);
        String bellBody     = resolveTokens(config.pro_Bell_Body__c,     tokenMap);

        List<Id> recipientIds = resolveRecipients(buckets, fieldUserIds, config.DeveloperName);
        if (recipientIds.isEmpty()) return;

        if (emailOn) {
            sendEmail(emailSubject, emailBody, recipientIds);
        }

        if (bellOn) {
            sendBell(config.pro_Notification_Type__c, bellTitle, bellBody, recordId, recipientIds);
        }
    }

    @TestVisible
    private static RecipientBuckets parseRecipients(String raw) {
        RecipientBuckets buckets = new RecipientBuckets();
        if (String.isBlank(raw)) return buckets;

        for (String entry : raw.split(',')) {
            String token = entry.trim();
            if (String.isBlank(token)) continue;

            // Split on FIRST colon only so values containing colons (rare SSO usernames) survive.
            Integer sep = token.indexOf(':');
            if (sep <= 0 || sep == token.length() - 1) {
                System.debug(LoggingLevel.WARN, 'pro_NotificationService: skipping malformed recipient token "' + token + '"');
                continue;
            }

            String prefix = token.substring(0, sep).trim().toLowerCase();
            String value  = token.substring(sep + 1).trim();
            if (String.isBlank(value)) {
                System.debug(LoggingLevel.WARN, 'pro_NotificationService: skipping empty value for prefix "' + prefix + '"');
                continue;
            }

            if (prefix == 'user') {
                buckets.usernames.add(value);
            } else if (prefix == 'group') {
                buckets.groupNames.add(value);
            } else if (prefix == 'profile') {
                buckets.profileNames.add(value);
            } else if (prefix == 'profiledev') {
                buckets.profileDevNames.add(value);
            } else if (prefix == 'field') {
                Integer hops = value.split('\\.').size();
                if (hops > MAX_RELATIONSHIP_HOPS) {
                    System.debug(LoggingLevel.WARN,
                        'pro_NotificationService: skipping field path "' + value
                        + '" — exceeds maximum of ' + MAX_RELATIONSHIP_HOPS + ' hops');
                    continue;
                }
                buckets.fieldPaths.add(value);
            } else {
                System.debug(LoggingLevel.WARN, 'pro_NotificationService: skipping unknown prefix "' + prefix + '" in token "' + token + '"');
            }
        }
        return buckets;
    }

    private static Set<String> extractTokens(String template) {
        Set<String> tokens = new Set<String>();
        if (String.isBlank(template)) return tokens;
        Pattern p = Pattern.compile('\\{([^}]+)\\}');
        Matcher m = p.matcher(template);
        while (m.find()) tokens.add(m.group(1));
        return tokens;
    }

    /**
     * SF-001: unified field-path validator, supports N hops. Used for both
     * template merge tokens and field: recipient paths so they share the
     * same semantics (up to 5 hops, schema-whitelisted, case-insensitive
     * relationship-name match).
     *
     * Returns the original path when every hop resolves in the schema,
     * or null when any hop is unknown.
     */
    @TestVisible
    private static String validateFieldPath(String objectName, String path, Integer maxHops) {
        if (String.isBlank(objectName) || String.isBlank(path)) return null;

        List<String> parts = path.split('\\.');
        if (parts.size() > maxHops) return null;

        Schema.DescribeSObjectResult currentDescribe = getDescribe(objectName);
        if (currentDescribe == null) return null;

        // Walk every hop except the terminal field.
        for (Integer i = 0; i < parts.size() - 1; i++) {
            String relName = parts[i];
            Schema.SObjectType nextTarget = resolveRelationship(currentDescribe, relName);
            if (nextTarget == null) return null;
            currentDescribe = nextTarget.getDescribe();
        }

        // Terminal must be a real field on the final SObject.
        String terminal = parts[parts.size() - 1].toLowerCase();
        if (!currentDescribe.fields.getMap().containsKey(terminal)) return null;

        return path;
    }

    @TestVisible
    private static Set<String> validateFieldTokens(String objectName, Set<String> fieldTokens) {
        // Back-compat wrapper retained for existing tests; delegates to the
        // unified validator at the same hop ceiling as field: recipients.
        Set<String> validated = new Set<String>();
        if (fieldTokens == null) return validated;
        for (String token : fieldTokens) {
            String v = validateFieldPath(objectName, token, MAX_RELATIONSHIP_HOPS);
            if (v != null) validated.add(v);
        }
        return validated;
    }

    private static Schema.DescribeSObjectResult getDescribe(String objectName) {
        if (String.isBlank(objectName)) return null;
        String key = objectName.toLowerCase();
        if (describeCache.containsKey(key)) return describeCache.get(key);
        Schema.SObjectType sot = Schema.getGlobalDescribe().get(objectName);
        if (sot == null) {
            describeCache.put(key, null);
            return null;
        }
        Schema.DescribeSObjectResult dsr = sot.getDescribe();
        describeCache.put(key, dsr);
        return dsr;
    }

    private static Schema.SObjectType resolveRelationship(Schema.DescribeSObjectResult parent, String relName) {
        if (parent == null || String.isBlank(relName)) return null;
        String target = relName.toLowerCase();
        for (Schema.SObjectField field : parent.fields.getMap().values()) {
            Schema.DescribeFieldResult dfr = field.getDescribe();
            if (dfr.getType() != Schema.DisplayType.REFERENCE) continue;
            String rn = dfr.getRelationshipName();
            if (rn == null) continue;
            if (rn.toLowerCase() == target) {
                List<Schema.SObjectType> refs = dfr.getReferenceTo();
                return refs.isEmpty() ? null : refs[0];
            }
        }
        return null;
    }

    private static SObject queryRecord(Id recordId, String objectName, Set<String> fields) {
        if (hostRecordOverride != null) return hostRecordOverride;

        Set<String> fieldSet = new Set<String>();
        fieldSet.add('Id');
        if (fields != null) fieldSet.addAll(fields);

        String soql = 'SELECT ' + String.join(new List<String>(fieldSet), ', ')
            + ' FROM ' + String.escapeSingleQuotes(objectName)
            + ' WHERE Id = :recordId LIMIT 1';
        List<SObject> records = Database.query(soql);
        return records.isEmpty() ? null : records[0];
    }

    private static Set<Id> resolveFieldUserIds(SObject record, Set<String> fieldPaths) {
        Set<Id> userIds = new Set<Id>();
        if (record == null || fieldPaths == null || fieldPaths.isEmpty()) return userIds;

        for (String path : fieldPaths) {
            try {
                Object raw = getFieldValue(record, path);
                if (raw == null) continue;
                if (!(raw instanceof Id)) continue;
                Id resolvedId = (Id) raw;
                if (resolvedId.getSObjectType() == User.SObjectType) {
                    userIds.add(resolvedId);
                } else {
                    System.debug(LoggingLevel.WARN,
                        'pro_NotificationService: field path "' + path
                        + '" did not resolve to a User Id');
                }
            } catch (Exception ex) {
                System.debug(LoggingLevel.WARN,
                    'pro_NotificationService: could not resolve field path "' + path
                    + '": ' + ex.getMessage());
            }
        }
        return userIds;
    }

    // Format merge-token values by type so Date fields don't render with a
    // "00:00:00" tail (SObject.get() can coerce Date → Datetime via dynamic SOQL).
    private static String formatFieldValue(Object val) {
        if (val == null) return '';
        if (val instanceof Date) return ((Date) val).format();
        if (val instanceof Datetime) return ((Datetime) val).format();
        return String.valueOf(val);
    }

    private static Object getFieldValue(SObject record, String fieldPath) {
        if (record == null || String.isBlank(fieldPath)) return null;
        List<String> parts = fieldPath.split('\\.');
        SObject current = record;
        for (Integer i = 0; i < parts.size() - 1; i++) {
            current = current.getSObject(parts[i]);
            if (current == null) return null;
        }
        return current.get(parts[parts.size() - 1]);
    }

    @TestVisible
    private static String resolveTokens(String template, Map<String, String> tokenMap) {
        if (String.isBlank(template)) return '';
        String result = template;
        for (String token : tokenMap.keySet()) {
            String value = tokenMap.get(token);
            result = result.replace('{' + token + '}', value != null ? value : '');
        }
        return result;
    }

    // NTH-002: per-bucket helpers keep the orchestration readable.
    private static List<Id> resolveRecipients(RecipientBuckets buckets, Set<Id> fieldUserIds, String configName) {
        if (recipientIdsOverride != null) return recipientIdsOverride;

        Set<Id> candidateUserIds = new Set<Id>();
        if (fieldUserIds != null) candidateUserIds.addAll(fieldUserIds);
        candidateUserIds.addAll(resolveUserBucket(buckets));
        candidateUserIds.addAll(resolveGroupBucket(buckets));
        candidateUserIds.addAll(resolveProfileBucket(buckets));
        candidateUserIds.addAll(resolveProfileDevBucket(buckets));

        List<Id> active = new List<Id>();
        if (candidateUserIds.isEmpty()) return active;

        for (User u : [
            SELECT Id FROM User
            WHERE Id IN :candidateUserIds AND IsActive = true
        ]) {
            active.add(u.Id);
        }

        // SF-006: cap run-away recipient expansions.
        if (active.size() > MAX_RECIPIENTS) {
            System.debug(LoggingLevel.WARN,
                'pro_NotificationService: recipient count ' + active.size()
                + ' for config "' + configName + '" exceeds MAX_RECIPIENTS ('
                + MAX_RECIPIENTS + '). Truncating.');
            List<Id> truncated = new List<Id>();
            for (Integer i = 0; i < MAX_RECIPIENTS; i++) {
                truncated.add(active[i]);
            }
            return truncated;
        }
        return active;
    }

    private static Set<Id> resolveUserBucket(RecipientBuckets buckets) {
        Set<Id> out = new Set<Id>();
        if (buckets.usernames.isEmpty()) return out;
        for (User u : [
            SELECT Id FROM User
            WHERE Username IN :buckets.usernames AND IsActive = true
        ]) {
            out.add(u.Id);
        }
        return out;
    }

    private static Set<Id> resolveGroupBucket(RecipientBuckets buckets) {
        Set<Id> out = new Set<Id>();
        if (buckets.groupNames.isEmpty()) return out;

        Set<Id> groupIds = new Set<Id>();
        for (Group g : [
            SELECT Id FROM Group
            WHERE DeveloperName IN :buckets.groupNames
              AND Type IN ('Regular', 'Queue')
        ]) {
            groupIds.add(g.Id);
        }
        // v2: nested groups (groups-containing-groups) are NOT recursed.
        // Only direct User members are included.
        if (groupIds.isEmpty()) return out;

        for (GroupMember gm : [
            SELECT UserOrGroupId FROM GroupMember
            WHERE GroupId IN :groupIds
        ]) {
            Id memberId = gm.UserOrGroupId;
            if (memberId != null && memberId.getSObjectType() == User.SObjectType) {
                out.add(memberId);
            }
        }
        return out;
    }

    private static Set<Id> resolveProfileBucket(RecipientBuckets buckets) {
        Set<Id> out = new Set<Id>();
        if (buckets.profileNames.isEmpty()) return out;

        Set<Id> profileIds = new Set<Id>();
        for (Profile p : [
            SELECT Id FROM Profile WHERE Name IN :buckets.profileNames
        ]) {
            profileIds.add(p.Id);
        }
        if (profileIds.isEmpty()) return out;

        for (User u : [
            SELECT Id FROM User
            WHERE ProfileId IN :profileIds AND IsActive = true
        ]) {
            out.add(u.Id);
        }
        return out;
    }

    private static Set<Id> resolveProfileDevBucket(RecipientBuckets buckets) {
        Set<Id> out = new Set<Id>();
        if (buckets.profileDevNames.isEmpty()) return out;

        // Profile has no queryable DeveloperName column; resolve by Name just like profile:.
        Set<Id> profileIds = new Set<Id>();
        for (Profile p : [
            SELECT Id FROM Profile WHERE Name IN :buckets.profileDevNames
        ]) {
            profileIds.add(p.Id);
        }
        if (profileIds.isEmpty()) return out;

        for (User u : [
            SELECT Id FROM User
            WHERE ProfileId IN :profileIds AND IsActive = true
        ]) {
            out.add(u.Id);
        }
        return out;
    }

    private static void sendEmail(String subject, String body, List<Id> recipientIds) {
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        for (Id userId : recipientIds) {
            Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
            msg.setTargetObjectId(userId);
            msg.setSaveAsActivity(false);
            msg.setSubject(subject);
            msg.setPlainTextBody(body);
            emails.add(msg);
        }
        if (emails.isEmpty()) return;
        emailInvocationCount++;
        try {
            Messaging.sendEmail(emails, false);
        } catch (System.EmailException ex) {
            System.debug(LoggingLevel.ERROR, 'pro_NotificationService EMAIL ERROR: ' + ex.getMessage());
        }
    }

    private static void sendBell(String notifTypeName, String title, String body, Id targetId, List<Id> recipientIds) {
        Id notifTypeId = getNotificationTypeId(notifTypeName);
        if (notifTypeId == null) {
            System.debug(LoggingLevel.WARN,
                'pro_NotificationService: Custom Notification Type "' + notifTypeName + '" not found');
            return;
        }

        // SF-003: Messaging.CustomNotification.send throws above 500 recipients.
        // Chunk the recipient set so no single send call exceeds the cap.
        List<Id> uniqueIds = new List<Id>(new Set<Id>(recipientIds));
        Integer chunkSize = 500;
        for (Integer start = 0; start < uniqueIds.size(); start += chunkSize) {
            Integer stop = Math.min(start + chunkSize, uniqueIds.size());
            Set<String> chunk = new Set<String>();
            for (Integer i = start; i < stop; i++) {
                chunk.add(String.valueOf(uniqueIds[i]));
            }
            try {
                Messaging.CustomNotification notif = new Messaging.CustomNotification();
                notif.setNotificationTypeId(notifTypeId);
                notif.setTargetId(targetId);
                notif.setTitle(title);
                notif.setBody(body);
                bellInvocationCount++;
                notif.send(chunk);
            } catch (Exception ex) {
                System.debug(LoggingLevel.ERROR,
                    'pro_NotificationService BELL ERROR (chunk ' + start + '-' + (stop - 1)
                    + '): ' + ex.getMessage());
            }
        }
    }

    private static Id getNotificationTypeId(String devName) {
        if (String.isBlank(devName)) return null;
        if (notifTypeIdCache.containsKey(devName)) return notifTypeIdCache.get(devName);
        List<CustomNotificationType> types = [
            SELECT Id FROM CustomNotificationType WHERE DeveloperName = :devName LIMIT 1
        ];
        Id resolved = types.isEmpty() ? null : types[0].Id;
        notifTypeIdCache.put(devName, resolved);
        return resolved;
    }
}