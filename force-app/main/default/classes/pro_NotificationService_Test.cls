@isTest
private class pro_NotificationService_Test {

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------

    private static pro_Notification_Config__mdt buildConfig(
        Boolean emailEnabled,
        Boolean bellEnabled,
        String notifType,
        String emailSubject,
        String emailBody,
        String bellTitle,
        String bellBody,
        String recipients
    ) {
        pro_Notification_Config__mdt cfg = new pro_Notification_Config__mdt();
        cfg.pro_Active__c = true;
        cfg.pro_Email_Enabled__c = emailEnabled;
        cfg.pro_Bell_Enabled__c = bellEnabled;
        cfg.pro_Notification_Type__c = notifType;
        cfg.pro_Email_Subject__c = emailSubject;
        cfg.pro_Email_Body__c = emailBody;
        cfg.pro_Bell_Title__c = bellTitle;
        cfg.pro_Bell_Body__c = bellBody;
        cfg.pro_Recipients__c = recipients;
        return cfg;
    }

    private static Account createAccount() {
        Account a = new Account(Name = 'Notification Test Account');
        insert a;
        return a;
    }

    private static pro_NotificationService.NotificationRequest buildRequest(Id recordId, String configName) {
        pro_NotificationService.NotificationRequest req = new pro_NotificationService.NotificationRequest();
        req.recordId = recordId;
        req.configName = configName;
        return req;
    }

    /**
     * Insert a test User inside a runAs() block to dodge MIXED_DML_OPERATION.
     * Returns the inserted User.
     */
    private static User insertTestUser(String uniq, String profileName, Boolean active) {
        Profile p = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];
        User u = new User(
            FirstName = 'Notif',
            LastName  = 'User ' + uniq,
            Email     = 'notif.' + uniq + '@example.com.invalid',
            Username  = 'notif.' + uniq + '.' + System.currentTimeMillis() + '@example.com.invalid',
            Alias     = ('no' + uniq).left(8),
            CommunityNickname = ('nu' + uniq).left(40),
            TimeZoneSidKey    = 'Europe/London',
            LocaleSidKey      = 'en_GB',
            EmailEncodingKey  = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId         = p.Id,
            IsActive          = active
        );
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert u;
        }
        return u;
    }

    // ------------------------------------------------------------------
    // Existing behaviour tests (override-based, preserved)
    // ------------------------------------------------------------------

    @isTest
    static void sendsEmailWithResolvedTokens() {
        Account a = createAccount();
        pro_NotificationService.configOverride = buildConfig(
            true, false, null,
            'Account update: {Name}',
            'Link: {RecordLink} Date: {Today}',
            null, null,
            'user:unused@example.com'
        );
        pro_NotificationService.recipientIdsOverride = new List<Id>{ UserInfo.getUserId() };

        Test.startTest();
        pro_NotificationService.sendNotifications(new List<pro_NotificationService.NotificationRequest>{
            buildRequest(a.Id, 'Test_Event')
        });
        Test.stopTest();

        System.assertEquals(1, pro_NotificationService.emailInvocationCount, 'Exactly one email invocation expected');
    }

    @isTest
    static void resolvesRelationshipFields() {
        Account a = createAccount();
        pro_NotificationService.configOverride = buildConfig(
            true, false, null,
            'Owner is {Owner.Name}',
            'Body {Owner.Name}',
            null, null,
            'user:x@x.com'
        );
        pro_NotificationService.recipientIdsOverride = new List<Id>{ UserInfo.getUserId() };

        Test.startTest();
        pro_NotificationService.sendNotifications(new List<pro_NotificationService.NotificationRequest>{
            buildRequest(a.Id, 'Test_Event')
        });
        Test.stopTest();

        System.assertEquals(1, pro_NotificationService.emailInvocationCount, 'Email should still have been sent');
    }

    @isTest
    static void skipsWhenBothChannelsDisabled() {
        Account a = createAccount();
        pro_NotificationService.configOverride = buildConfig(
            false, false, null,
            'Subj', 'Body', 'Bell', 'BellBody',
            'user:x@x.com'
        );
        pro_NotificationService.recipientIdsOverride = new List<Id>{ UserInfo.getUserId() };

        Test.startTest();
        pro_NotificationService.sendNotifications(new List<pro_NotificationService.NotificationRequest>{
            buildRequest(a.Id, 'Test_Event')
        });
        Test.stopTest();

        System.assertEquals(0, pro_NotificationService.emailInvocationCount, 'No email expected when both channels off');
    }

    @isTest
    static void skipsEmailWhenEmailDisabled() {
        Account a = createAccount();
        pro_NotificationService.configOverride = buildConfig(
            false, true, 'pro_Framework_Notification',
            'Subj', 'Body', 'Bell', 'BellBody',
            'user:x@x.com'
        );
        pro_NotificationService.recipientIdsOverride = new List<Id>{ UserInfo.getUserId() };

        Test.startTest();
        pro_NotificationService.sendNotifications(new List<pro_NotificationService.NotificationRequest>{
            buildRequest(a.Id, 'Test_Event')
        });
        Test.stopTest();

        System.assertEquals(0, pro_NotificationService.emailInvocationCount, 'No email expected when Email Enabled = false');
    }

    @isTest
    static void sendsEmailWhenOnlyEmailEnabled() {
        Account a = createAccount();
        pro_NotificationService.configOverride = buildConfig(
            true, false, null,
            'Subj {Name}', 'Body', null, null,
            'user:x@x.com'
        );
        pro_NotificationService.recipientIdsOverride = new List<Id>{ UserInfo.getUserId() };

        Test.startTest();
        pro_NotificationService.sendNotifications(new List<pro_NotificationService.NotificationRequest>{
            buildRequest(a.Id, 'Test_Event')
        });
        Test.stopTest();

        System.assertEquals(1, pro_NotificationService.emailInvocationCount, 'Exactly one email expected');
    }

    @isTest
    static void skipsWhenConfigNotFound() {
        Account a = createAccount();
        pro_NotificationService.configOverride = null;
        pro_NotificationService.recipientIdsOverride = new List<Id>{ UserInfo.getUserId() };

        Test.startTest();
        pro_NotificationService.sendNotifications(new List<pro_NotificationService.NotificationRequest>{
            buildRequest(a.Id, 'Non_Existent_Event_Type_____xyz')
        });
        Test.stopTest();

        System.assertEquals(0, pro_NotificationService.emailInvocationCount, 'No email expected when config not found');
    }

    @isTest
    static void skipsWhenNoRecipients() {
        Account a = createAccount();
        pro_NotificationService.configOverride = buildConfig(
            true, false, null,
            'Subj', 'Body', null, null,
            'user:x@x.com'
        );
        pro_NotificationService.recipientIdsOverride = new List<Id>();

        Test.startTest();
        pro_NotificationService.sendNotifications(new List<pro_NotificationService.NotificationRequest>{
            buildRequest(a.Id, 'Test_Event')
        });
        Test.stopTest();

        System.assertEquals(0, pro_NotificationService.emailInvocationCount, 'No email expected when recipient list empty');
    }

    @isTest
    static void resolvesComputedTokens() {
        Account a = createAccount();
        pro_NotificationService.configOverride = buildConfig(
            true, false, null,
            'Subj {RecordLink}',
            'Body {Today} {KeyFields}',
            null, null,
            'user:x@x.com'
        );
        pro_NotificationService.recipientIdsOverride = new List<Id>{ UserInfo.getUserId() };

        Test.startTest();
        pro_NotificationService.sendNotifications(new List<pro_NotificationService.NotificationRequest>{
            buildRequest(a.Id, 'Test_Event')
        });
        Test.stopTest();

        System.assertEquals(1, pro_NotificationService.emailInvocationCount,
            '{KeyFields} should be left literal and not cause a failure');
    }

    // ------------------------------------------------------------------
    // Parse-recipients tests
    // ------------------------------------------------------------------

    @isTest
    static void parseRecipients_allFivePrefixes() {
        String raw = 'user:alice@x.com, group:Sales_Managers, profile:System Administrator, '
                   + 'profiledev:Standard_User, field:Owner.ManagerId';

        Test.startTest();
        pro_NotificationService.RecipientBuckets buckets = pro_NotificationService.parseRecipients(raw);
        Test.stopTest();

        System.assert(buckets.usernames.contains('alice@x.com'), 'Usernames bucket should contain alice@x.com');
        System.assert(buckets.groupNames.contains('Sales_Managers'), 'Group bucket should contain Sales_Managers');
        System.assert(buckets.profileNames.contains('System Administrator'), 'Profile bucket should contain System Administrator');
        System.assert(buckets.profileDevNames.contains('Standard_User'), 'profiledev bucket should contain Standard_User');
        System.assert(buckets.fieldPaths.contains('Owner.ManagerId'), 'Field paths bucket should contain Owner.ManagerId');
    }

    @isTest
    static void parseRecipients_unknownPrefixSkipped() {
        Test.startTest();
        pro_NotificationService.RecipientBuckets buckets = pro_NotificationService.parseRecipients('foo:bar, user:x@x.com');
        Test.stopTest();

        System.assertEquals(1, buckets.usernames.size(), 'Only the user token should have been accepted');
        System.assert(buckets.usernames.contains('x@x.com'), 'Usernames bucket should contain x@x.com');
        System.assertEquals(0, buckets.groupNames.size(), 'foo: prefix must not land in any known bucket');
    }

    @isTest
    static void parseRecipients_malformedEntry() {
        Test.startTest();
        pro_NotificationService.RecipientBuckets buckets =
            pro_NotificationService.parseRecipients('no_colon_here, , user:valid@x.com, user:');
        Test.stopTest();

        System.assertEquals(1, buckets.usernames.size(), 'Only valid@x.com should land in usernames');
        System.assert(buckets.usernames.contains('valid@x.com'), 'Expected valid user to survive parsing');
    }

    @isTest
    static void parseRecipients_fieldPathOverMaxHops() {
        Test.startTest();
        pro_NotificationService.RecipientBuckets buckets =
            pro_NotificationService.parseRecipients('field:a.b.c.d.e.f, field:OwnerId');
        Test.stopTest();

        System.assertEquals(1, buckets.fieldPaths.size(), 'Six-hop path must be dropped, one-hop kept');
        System.assert(buckets.fieldPaths.contains('OwnerId'), 'OwnerId single-hop path should survive');
        System.assert(!buckets.fieldPaths.contains('a.b.c.d.e.f'), 'Six-hop path should have been skipped');
    }

    // ------------------------------------------------------------------
    // Field-path validator
    // ------------------------------------------------------------------

    @isTest
    static void validateFieldTokens_existingRelationship() {
        Set<String> tokens = new Set<String>{ 'Name', 'Owner.Name', 'NotAField', 'BadRel.Name' };

        Test.startTest();
        Set<String> validated = pro_NotificationService.validateFieldTokens('Account', tokens);
        Test.stopTest();

        System.assert(validated.contains('Name'), 'Direct Name field should validate');
        System.assert(validated.contains('Owner.Name'), 'Owner.Name relationship should validate');
        System.assert(!validated.contains('NotAField'), 'Unknown field should be rejected');
        System.assert(!validated.contains('BadRel.Name'), 'Unknown relationship should be rejected');
    }

    @isTest
    static void validateFieldPath_multiHopAcrossObjects() {
        // SF-001: with unified validator, multi-hop merge tokens now resolve.
        Test.startTest();
        String twoHop = pro_NotificationService.validateFieldPath('Contact', 'Account.OwnerId', 5);
        String threeHop = pro_NotificationService.validateFieldPath('Contact', 'Account.Owner.ManagerId', 5);
        String bogus = pro_NotificationService.validateFieldPath('Contact', 'Account.NotAField', 5);
        Test.stopTest();

        System.assertEquals('Account.OwnerId', twoHop, 'Two-hop Account.OwnerId should resolve from Contact');
        System.assertEquals('Account.Owner.ManagerId', threeHop, 'Three-hop to a User.ManagerId should resolve');
        System.assertEquals(null, bogus, 'Unknown terminal field should be rejected');
    }

    // ------------------------------------------------------------------
    // Token resolver
    // ------------------------------------------------------------------

    @isTest
    static void resolveTokens_replacesAllTokens() {
        Map<String, String> tokens = new Map<String, String>{
            'Name' => 'Acme',
            'Owner.Name' => 'Alice',
            'RecordLink' => 'https://example/abc'
        };

        Test.startTest();
        String result = pro_NotificationService.resolveTokens(
            'Account {Name} owned by {Owner.Name} — see {RecordLink}',
            tokens
        );
        Test.stopTest();

        System.assertEquals('Account Acme owned by Alice — see https://example/abc', result,
            'All tokens should be replaced in order');
    }

    // ------------------------------------------------------------------
    // Flow-shape tests
    // ------------------------------------------------------------------

    @isTest
    static void sendNotifications_swallowsExceptions() {
        pro_NotificationService.configOverride = null;

        Test.startTest();
        pro_NotificationService.sendNotifications(new List<pro_NotificationService.NotificationRequest>{
            buildRequest(UserInfo.getUserId(), 'Unknown_Event_xyz')
        });
        Test.stopTest();

        System.assertEquals(0, pro_NotificationService.emailInvocationCount, 'Unknown event should cause no email');
    }

    @isTest
    static void bellBranchSkippedWhenNotifTypeBlank() {
        Account a = createAccount();
        pro_NotificationService.configOverride = buildConfig(
            false, true, null,
            null, null, 'Title', 'Body',
            'user:x@x.com'
        );
        pro_NotificationService.recipientIdsOverride = new List<Id>{ UserInfo.getUserId() };

        Test.startTest();
        pro_NotificationService.sendNotifications(new List<pro_NotificationService.NotificationRequest>{
            buildRequest(a.Id, 'Test_Event')
        });
        Test.stopTest();

        System.assertEquals(0, pro_NotificationService.emailInvocationCount,
            'Blank notif type + Email off should result in no sends (both gates closed)');
    }

    // SF-007: configOverride must still respect pro_Active__c
    @isTest
    static void inactiveConfigOverride_isIgnored() {
        Account a = createAccount();
        pro_Notification_Config__mdt cfg = buildConfig(
            true, false, null,
            'Subj', 'Body', null, null,
            'user:x@x.com'
        );
        cfg.pro_Active__c = false;
        pro_NotificationService.configOverride = cfg;
        pro_NotificationService.recipientIdsOverride = new List<Id>{ UserInfo.getUserId() };

        Test.startTest();
        pro_NotificationService.sendNotifications(new List<pro_NotificationService.NotificationRequest>{
            buildRequest(a.Id, 'Test_Event')
        });
        Test.stopTest();

        System.assertEquals(0, pro_NotificationService.emailInvocationCount,
            'Inactive config must not send even when used as configOverride');
    }

    // MF-001: one SOQL for configs regardless of how many requests share
    // the same event type. Here we fire 50 requests against the same event
    // type under a null override; the governor should see a tight query count.
    @isTest
    static void bulkRequests_singleConfigSoql() {
        Account a = createAccount();
        List<pro_NotificationService.NotificationRequest> reqs = new List<pro_NotificationService.NotificationRequest>();
        for (Integer i = 0; i < 50; i++) {
            reqs.add(buildRequest(a.Id, 'Nonexistent_Event_For_Bulk_Test'));
        }
        pro_NotificationService.configOverride = null;

        Test.startTest();
        Integer before = Limits.getQueries();
        pro_NotificationService.sendNotifications(reqs);
        Integer after = Limits.getQueries();
        Test.stopTest();

        // 1 SOQL to bulk-load configs; 0 further queries because no config matches.
        System.assert(after - before <= 2,
            'Bulk path should issue at most 2 SOQL for 50 unmatched requests, observed ' + (after - before));
    }

    // ------------------------------------------------------------------
    // SF-004: real recipient-resolution integration tests
    // ------------------------------------------------------------------

    @isTest
    static void resolveUserPrefix_byUsername() {
        User u = insertTestUser('u1', 'Standard User', true);
        Account a = createAccount();

        pro_NotificationService.configOverride = buildConfig(
            true, false, null,
            'Subj', 'Body', null, null,
            'user:' + u.Username
        );

        Test.startTest();
        pro_NotificationService.sendNotifications(new List<pro_NotificationService.NotificationRequest>{
            buildRequest(a.Id, 'Test_Event')
        });
        Test.stopTest();

        System.assertEquals(1, pro_NotificationService.emailInvocationCount,
            'Username prefix should resolve to exactly one email invocation');
    }

    @isTest
    static void resolveGroupPrefix_publicGroup() {
        User u = insertTestUser('g1', 'Standard User', true);
        Group g;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            g = new Group(Name = 'Notif Test Group', DeveloperName = 'Notif_Test_Group_' + System.currentTimeMillis(), Type = 'Regular');
            insert g;
            insert new GroupMember(GroupId = g.Id, UserOrGroupId = u.Id);
        }
        Account a = createAccount();

        pro_NotificationService.configOverride = buildConfig(
            true, false, null,
            'Subj', 'Body', null, null,
            'group:' + g.DeveloperName
        );

        Test.startTest();
        pro_NotificationService.sendNotifications(new List<pro_NotificationService.NotificationRequest>{
            buildRequest(a.Id, 'Test_Event')
        });
        Test.stopTest();

        System.assertEquals(1, pro_NotificationService.emailInvocationCount,
            'Public Group prefix should resolve to its one active member');
    }

    @isTest
    static void resolveProfilePrefix_byName() {
        // Use Standard User profile; pick any existing active user with it or insert one.
        List<User> existing = [
            SELECT Id FROM User
            WHERE Profile.Name = 'Standard User' AND IsActive = true LIMIT 1
        ];
        if (existing.isEmpty()) {
            insertTestUser('p1', 'Standard User', true);
        }
        Account a = createAccount();

        pro_NotificationService.configOverride = buildConfig(
            true, false, null,
            'Subj', 'Body', null, null,
            'profile:Standard User'
        );

        Test.startTest();
        pro_NotificationService.sendNotifications(new List<pro_NotificationService.NotificationRequest>{
            buildRequest(a.Id, 'Test_Event')
        });
        Test.stopTest();

        System.assert(pro_NotificationService.emailInvocationCount >= 1,
            'profile:Standard User should resolve to at least one active user');
    }

    @isTest
    static void resolveProfileDevPrefix_byDeveloperName() {
        List<Profile> profs = [SELECT Id, Name FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        if (profs.isEmpty()) return; // Defensive; 'Standard' should exist in every org.

        List<User> existing = [
            SELECT Id FROM User WHERE ProfileId = :profs[0].Id AND IsActive = true LIMIT 1
        ];
        if (existing.isEmpty()) {
            insertTestUser('pd1', 'Standard User', true);
        }
        Account a = createAccount();

        pro_NotificationService.configOverride = buildConfig(
            true, false, null,
            'Subj', 'Body', null, null,
            'profiledev:Standard User'
        );

        Test.startTest();
        pro_NotificationService.sendNotifications(new List<pro_NotificationService.NotificationRequest>{
            buildRequest(a.Id, 'Test_Event')
        });
        Test.stopTest();

        System.assert(pro_NotificationService.emailInvocationCount >= 1,
            'profiledev:Standard User should resolve to at least one active user');
    }

    @isTest
    static void resolveFieldPrefix_crossObjectPath() {
        Account a = createAccount();
        // OwnerId will be the running user; that must resolve.
        pro_NotificationService.configOverride = buildConfig(
            true, false, null,
            'Subj', 'Body', null, null,
            'field:OwnerId'
        );

        Test.startTest();
        pro_NotificationService.sendNotifications(new List<pro_NotificationService.NotificationRequest>{
            buildRequest(a.Id, 'Test_Event')
        });
        Test.stopTest();

        System.assertEquals(1, pro_NotificationService.emailInvocationCount,
            'field:OwnerId should resolve to the record owner (the running user)');
    }

    @isTest
    static void inactiveUsersFilteredOut() {
        User inactive = insertTestUser('inac', 'Standard User', false);
        Account a = createAccount();

        pro_NotificationService.configOverride = buildConfig(
            true, false, null,
            'Subj', 'Body', null, null,
            'user:' + inactive.Username
        );

        Test.startTest();
        pro_NotificationService.sendNotifications(new List<pro_NotificationService.NotificationRequest>{
            buildRequest(a.Id, 'Test_Event')
        });
        Test.stopTest();

        System.assertEquals(0, pro_NotificationService.emailInvocationCount,
            'Inactive users must not receive notifications');
    }

    @isTest
    static void crossBucketDedupe() {
        // Running user IS the Account Owner. Also reference them by username.
        // Should receive exactly one email, not two.
        User me = [SELECT Id, Username FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        Account a = createAccount();

        pro_NotificationService.configOverride = buildConfig(
            true, false, null,
            'Subj', 'Body', null, null,
            'user:' + me.Username + ', field:OwnerId'
        );

        Test.startTest();
        pro_NotificationService.sendNotifications(new List<pro_NotificationService.NotificationRequest>{
            buildRequest(a.Id, 'Test_Event')
        });
        Test.stopTest();

        System.assertEquals(1, pro_NotificationService.emailInvocationCount,
            'Same user referenced via two buckets must be deduped');
    }
}