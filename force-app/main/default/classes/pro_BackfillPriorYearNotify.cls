/**
 * Sends aggregated DML failure details for the annual utilization backfill.
 * Recipients come from custom metadata pro_Backfill_Prior_Year_Config__mdt (record Default).
 */
public with sharing class pro_BackfillPriorYearNotify {
    private static final Integer MAX_BODY_CHARS = 100000;

    public static void sendFailureSummary(List<String> lines) {
        if (lines == null || lines.isEmpty()) {
            return;
        }
        pro_Backfill_Prior_Year_Config__mdt cfg = pro_Backfill_Prior_Year_Config__mdt.getInstance('Default');
        if (cfg == null || String.isBlank(cfg.pro_Error_Notification_Emails__c)) {
            return;
        }
        List<String> toAddresses = parseEmails(cfg.pro_Error_Notification_Emails__c);
        if (toAddresses.isEmpty()) {
            return;
        }
        String body = String.join(lines, '\n');
        if (body.length() > MAX_BODY_CHARS) {
            body = body.substring(0, MAX_BODY_CHARS) + '\n...(truncated)';
        }
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(toAddresses);
        mail.setSubject('Prior calendar year backfill — update failures');
        mail.setPlainTextBody(
            'One or more Utilization Report records could not be updated during the annual backfill.\n\n' + body
        );
        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
    }

    private static List<String> parseEmails(String raw) {
        List<String> result = new List<String>();
        if (String.isBlank(raw)) {
            return result;
        }
        for (String part : raw.split('[;,\\s]+')) {
            if (part == null) {
                continue;
            }
            String trimmed = part.trim();
            if (!String.isBlank(trimmed)) {
                result.add(trimmed);
            }
        }
        return result;
    }
}