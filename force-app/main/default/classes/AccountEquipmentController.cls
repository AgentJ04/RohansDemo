/**
 * AccountEquipmentController
 * -------------------------------------------------------------------------
 * Backing controller for the `accountEquipmentOverview` LWC that lives on the
 * Account record page. It returns, for every piece of equipment tied to the
 * account, a set of "cards" (Equipment, Accessories, Lease, CSMA, Meters).
 *
 * Every column is driven by a Field Set so admins can add/remove displayed
 * fields WITHOUT touching Apex. Field sets follow the `AR_` naming convention:
 *
 *   TSGADX__Equipment__c  -> AR_Equipment
 *   Accessory__c          -> AR_Accessory
 *   TSGADX__Agreements__c -> AR_Lease   (lease agreement)
 *   TSGADX__Agreements__c -> AR_CSMA    (service / CSMA agreement)
 *   Agreement_Detail__c   -> AR_CSMA_Detail
 *   MeterReading__c       -> AR_Meter
 *
 * Linkage (as used elsewhere in this org):
 *   Equipment  -> Account : TSGADX__Business__c
 *   Lease      : Agreement matched on TSGADX__Lease_ID__c = Equipment.TSGADX__Lease_ID__c
 *   CSMA       : Agreement reached through Agreement_Detail__c (Type__c = 'Service')
 *   Meters     : MeterReading__c.Equipment__c (Is_Latest__c = true)
 *   Accessory  : Accessory__c.Equipment__c
 *
 * Reference (lookup) fields added to a field set are automatically resolved to
 * the related record's Name for display.
 */
public with sharing class AccountEquipmentController {

    // Change these here if the naming convention ever changes.
    @TestVisible private static final String FS_EQUIPMENT   = 'AR_Equipment';
    @TestVisible private static final String FS_ACCESSORY   = 'AR_Accessory';
    @TestVisible private static final String FS_LEASE       = 'AR_Lease';
    @TestVisible private static final String FS_CSMA        = 'AR_CSMA';
    @TestVisible private static final String FS_CSMA_DETAIL = 'AR_CSMA_Detail';
    @TestVisible private static final String FS_METER       = 'AR_Meter';

    @AuraEnabled(cacheable=true)
    public static OverviewWrapper getOverview(Id recordId) {
        try {
            OverviewWrapper wrapper = new OverviewWrapper();

            // ---- Account header ----------------------------------------------------
            List<Account> accs = [
                SELECT Id, Name, AccountNumber, ParentId,
                       BillingStreet, BillingCity, BillingState, BillingPostalCode
                FROM Account
                WHERE Id = :recordId
                LIMIT 1
            ];
            if (accs.isEmpty()) {
                return wrapper;
            }
            Account acc = accs[0];
            wrapper.accountName   = acc.Name;
            wrapper.accountNumber = String.isBlank(acc.AccountNumber) ? acc.Name : acc.AccountNumber;
            wrapper.address       = formatAddress(acc);
            wrapper.isParentAccount = (acc.ParentId == null);

            // ---- Field set metadata ------------------------------------------------
            List<FsMember> eqFs      = describeFieldSet('TSGADX__Equipment__c', FS_EQUIPMENT);
            List<FsMember> accFs     = describeFieldSet('Accessory__c',          FS_ACCESSORY);
            List<FsMember> leaseFs   = describeFieldSet('TSGADX__Agreements__c', FS_LEASE);
            List<FsMember> csmaFs    = describeFieldSet('TSGADX__Agreements__c', FS_CSMA);
            List<FsMember> csmaDetFs = describeFieldSet('Agreement_Detail__c',   FS_CSMA_DETAIL);
            List<FsMember> meterFs   = describeFieldSet('MeterReading__c',       FS_METER);

            // ---- Equipment ---------------------------------------------------------
            String eqQuery = 'SELECT ' + buildSelect(
                    new Set<String>{ 'Id', 'Name', 'RecordType.Name',
                                     'TSGADX__Service_Request_Count__c', 'TSGADX__Lease_ID__c' },
                    eqFs)
                + ' FROM TSGADX__Equipment__c'
                + ' WHERE TSGADX__Business__c = :recordId'
                + ' ORDER BY Name';
            List<SObject> equipment = Database.query(eqQuery);
            wrapper.equipmentCount = equipment.size();

            Set<Id> equipIds = new Set<Id>();
            Set<String> leaseIds = new Set<String>();
            for (SObject eq : equipment) {
                equipIds.add((Id) eq.get('Id'));
                Object lid = eq.get('TSGADX__Lease_ID__c');
                if (lid != null && String.isNotBlank(String.valueOf(lid))) {
                    leaseIds.add(String.valueOf(lid));
                }
            }

            // ---- Related records (bulk) -------------------------------------------
            Map<Id, List<SObject>> accByEquip   = new Map<Id, List<SObject>>();
            Map<Id, List<SObject>> meterByEquip = new Map<Id, List<SObject>>();
            Map<Id, List<SObject>> serviceDetByEquip = new Map<Id, List<SObject>>();
            Map<Id, Id> serviceAgByEquip = new Map<Id, Id>();
            Map<Id, SObject> csmaById = new Map<Id, SObject>();
            Map<String, SObject> leaseByLeaseId = new Map<String, SObject>();

            if (!equipIds.isEmpty()) {
                // Accessories
                String accQuery = 'SELECT ' + buildSelect(new Set<String>{ 'Id', 'Name', 'Equipment__c' }, accFs)
                    + ' FROM Accessory__c WHERE Equipment__c IN :equipIds ORDER BY Name';
                for (SObject a : Database.query(accQuery)) {
                    groupBy(accByEquip, (Id) a.get('Equipment__c'), a);
                }

                // Meter readings (latest only)
                String meterQuery = 'SELECT ' + buildSelect(
                        new Set<String>{ 'Id', 'Equipment__c', 'Meter_Type__c' }, meterFs)
                    + ' FROM MeterReading__c'
                    + ' WHERE Equipment__c IN :equipIds AND Is_Latest__c = true'
                    + ' ORDER BY Meter_Type__c';
                for (SObject m : Database.query(meterQuery)) {
                    groupBy(meterByEquip, (Id) m.get('Equipment__c'), m);
                }

                // CSMA: service agreement details -> coverage groups + header agreement id
                Set<Id> serviceAgIds = new Set<Id>();
                String detQuery = 'SELECT ' + buildSelect(
                        new Set<String>{ 'Id', 'Equipment__c', 'Agreement__c', 'Contract_Meter_Group__c' }, csmaDetFs)
                    + ' FROM Agreement_Detail__c'
                    + ' WHERE Equipment__c IN :equipIds AND Agreement__r.Type__c = \'Service\''
                    + ' ORDER BY Contract_Meter_Group__c';
                for (SObject d : Database.query(detQuery)) {
                    Id eqId = (Id) d.get('Equipment__c');
                    groupBy(serviceDetByEquip, eqId, d);
                    Object agId = d.get('Agreement__c');
                    if (agId != null) {
                        serviceAgIds.add((Id) agId);
                        if (!serviceAgByEquip.containsKey(eqId)) {
                            serviceAgByEquip.put(eqId, (Id) agId);
                        }
                    }
                }
                if (!serviceAgIds.isEmpty()) {
                    String csmaQuery = 'SELECT ' + buildSelect(new Set<String>{ 'Id' }, csmaFs)
                        + ' FROM TSGADX__Agreements__c WHERE Id IN :serviceAgIds';
                    for (SObject c : Database.query(csmaQuery)) {
                        csmaById.put((Id) c.get('Id'), c);
                    }
                }

                // Lease: agreement matched on Lease ID
                if (!leaseIds.isEmpty()) {
                    String leaseQuery = 'SELECT ' + buildSelect(
                            new Set<String>{ 'Id', 'TSGADX__Lease_ID__c' }, leaseFs)
                        + ' FROM TSGADX__Agreements__c WHERE TSGADX__Lease_ID__c IN :leaseIds';
                    for (SObject l : Database.query(leaseQuery)) {
                        String lid = String.valueOf(l.get('TSGADX__Lease_ID__c'));
                        if (!leaseByLeaseId.containsKey(lid)) {
                            leaseByLeaseId.put(lid, l);
                        }
                    }
                }
            }

            // ---- Assemble equipment cards -----------------------------------------
            wrapper.equipment = new List<EquipmentCard>();
            for (SObject eq : equipment) {
                Id eqId = (Id) eq.get('Id');
                EquipmentCard card = new EquipmentCard();
                card.id = eqId;
                card.name = (String) eq.get('Name');
                card.recordTypeName = relName(eq, 'RecordType');
                Object src = eq.get('TSGADX__Service_Request_Count__c');
                card.serviceRequestCount = (src == null) ? 0 : (Decimal) src;

                card.equipmentFields = toCells(eq, eqFs);

                // accessories
                card.accessories = new List<AccessoryItem>();
                if (accByEquip.containsKey(eqId)) {
                    for (SObject a : accByEquip.get(eqId)) {
                        AccessoryItem item = new AccessoryItem();
                        item.id = (Id) a.get('Id');
                        item.label = (String) a.get('Name');
                        item.fields = toCells(a, accFs);
                        card.accessories.add(item);
                    }
                }

                // lease (matched by Lease ID)
                card.leaseFields = new List<FieldCell>();
                Object lid = eq.get('TSGADX__Lease_ID__c');
                if (lid != null && leaseByLeaseId.containsKey(String.valueOf(lid))) {
                    card.leaseFields = toCells(leaseByLeaseId.get(String.valueOf(lid)), leaseFs);
                }

                // csma header + coverage groups
                card.csmaFields = new List<FieldCell>();
                if (serviceAgByEquip.containsKey(eqId) && csmaById.containsKey(serviceAgByEquip.get(eqId))) {
                    card.csmaFields = toCells(csmaById.get(serviceAgByEquip.get(eqId)), csmaFs);
                }
                card.csmaGroups = new List<MeterGroup>();
                if (serviceDetByEquip.containsKey(eqId)) {
                    for (SObject d : serviceDetByEquip.get(eqId)) {
                        MeterGroup g = new MeterGroup();
                        Object grp = d.get('Contract_Meter_Group__c');
                        g.groupLabel = (grp == null) ? 'Coverage' : String.valueOf(grp);
                        g.fields = toCells(d, csmaDetFs);
                        card.csmaGroups.add(g);
                    }
                }

                // meter readings grouped by type
                card.meterGroups = new List<MeterGroup>();
                if (meterByEquip.containsKey(eqId)) {
                    for (SObject m : meterByEquip.get(eqId)) {
                        MeterGroup g = new MeterGroup();
                        Object mt = m.get('Meter_Type__c');
                        g.groupLabel = (mt == null) ? 'Meter' : String.valueOf(mt);
                        g.fields = toCells(m, meterFs);
                        card.meterGroups.add(g);
                    }
                }

                wrapper.equipment.add(card);
            }

            return wrapper;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'AccountEquipmentController error: '
                + e.getTypeName() + ': ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ---------------------------------------------------------------------------
    // Field-set / describe helpers
    // ---------------------------------------------------------------------------

    /** Lightweight view of a field set member with resolved describe info. */
    @TestVisible
    private class FsMember {
        String path;              // API field path (e.g. TSGADX__Make__c)
        String label;             // display label
        Schema.DisplayType type;  // field data type
        String relationshipName;  // populated for reference fields
        Boolean refHasName;       // true if the parent object exposes a Name field
    }

    private static Map<String, List<FsMember>> fsCache = new Map<String, List<FsMember>>();

    @TestVisible
    private static List<FsMember> describeFieldSet(String objectApiName, String fieldSetName) {
        String key = objectApiName + '.' + fieldSetName;
        if (fsCache.containsKey(key)) {
            return fsCache.get(key);
        }
        List<FsMember> members = new List<FsMember>();
        Schema.SObjectType sot = Schema.getGlobalDescribe().get(objectApiName);
        if (sot != null) {
            Schema.FieldSet fs = sot.getDescribe().fieldSets.getMap().get(fieldSetName);
            if (fs != null) {
                for (Schema.FieldSetMember fsm : fs.getFields()) {
                    FsMember m = new FsMember();
                    m.path  = fsm.getFieldPath();
                    m.label = fsm.getLabel();
                    m.type  = fsm.getType();
                    if (m.type == Schema.DisplayType.REFERENCE && !m.path.contains('.')) {
                        Schema.DescribeFieldResult dfr = fsm.getSObjectField().getDescribe();
                        m.relationshipName = dfr.getRelationshipName();
                        m.refHasName = referenceHasName(dfr);
                    }
                    members.add(m);
                }
            }
        }
        fsCache.put(key, members);
        return members;
    }

    private static Boolean referenceHasName(Schema.DescribeFieldResult dfr) {
        List<Schema.SObjectType> refs = dfr.getReferenceTo();
        if (refs == null || refs.isEmpty()) {
            return false;
        }
        return refs[0].getDescribe().fields.getMap().containsKey('Name');
    }

    /** Builds a de-duplicated SELECT clause from base fields + field set members. */
    @TestVisible
    private static String buildSelect(Set<String> baseFields, List<FsMember> members) {
        Set<String> lower = new Set<String>();
        List<String> ordered = new List<String>();
        for (String b : baseFields) {
            if (lower.add(b.toLowerCase())) {
                ordered.add(b);
            }
        }
        for (FsMember m : members) {
            if (lower.add(m.path.toLowerCase())) {
                ordered.add(m.path);
            }
            if (m.relationshipName != null && m.refHasName) {
                String rel = m.relationshipName + '.Name';
                if (lower.add(rel.toLowerCase())) {
                    ordered.add(rel);
                }
            }
        }
        return String.join(ordered, ', ');
    }

    /** Converts a record into display cells based on its field set members. */
    @TestVisible
    private static List<FieldCell> toCells(SObject record, List<FsMember> members) {
        List<FieldCell> cells = new List<FieldCell>();
        for (FsMember m : members) {
            FieldCell cell = new FieldCell();
            cell.label = m.label;
            cell.name = m.path;
            cell.type = displayType(m.type);
            if (m.relationshipName != null && m.refHasName) {
                cell.value = relName(record, m.relationshipName);
                cell.type = 'string';
            } else {
                cell.value = readPath(record, m.path);
            }
            cells.add(cell);
        }
        return cells;
    }

    /** Traverses relationship paths (a.b.c) to read a field value. */
    private static Object readPath(SObject record, String path) {
        if (!path.contains('.')) {
            return record.get(path);
        }
        List<String> parts = path.split('\\.');
        SObject cursor = record;
        for (Integer i = 0; i < parts.size() - 1; i++) {
            if (cursor == null) {
                return null;
            }
            cursor = cursor.getSObject(parts[i]);
        }
        return (cursor == null) ? null : cursor.get(parts[parts.size() - 1]);
    }

    private static String relName(SObject record, String relationshipName) {
        SObject parent = record.getSObject(relationshipName);
        return (parent == null) ? null : (String) parent.get('Name');
    }

    private static String displayType(Schema.DisplayType t) {
        switch on t {
            when CURRENCY { return 'currency'; }
            when PERCENT  { return 'percent'; }
            when DATE     { return 'date'; }
            when DATETIME { return 'datetime'; }
            when DOUBLE, INTEGER, LONG { return 'number'; }
            when BOOLEAN  { return 'boolean'; }
            when else     { return 'string'; }
        }
    }

    private static void groupBy(Map<Id, List<SObject>> target, Id key, SObject value) {
        if (key == null) {
            return;
        }
        if (!target.containsKey(key)) {
            target.put(key, new List<SObject>());
        }
        target.get(key).add(value);
    }

    private static String formatAddress(Account a) {
        List<String> parts = new List<String>();
        if (String.isNotBlank(a.BillingStreet)) parts.add(a.BillingStreet.replace('\n', ' '));
        List<String> cityLine = new List<String>();
        if (String.isNotBlank(a.BillingCity)) cityLine.add(a.BillingCity);
        if (String.isNotBlank(a.BillingState)) cityLine.add(a.BillingState);
        String cs = String.join(cityLine, ', ');
        if (String.isNotBlank(a.BillingPostalCode)) cs = (cs + ' ' + a.BillingPostalCode).trim();
        if (String.isNotBlank(cs)) parts.add(cs);
        return String.join(parts, ', ');
    }

    // ---------------------------------------------------------------------------
    // Wrapper types (serialized to the LWC)
    // ---------------------------------------------------------------------------

    public class OverviewWrapper {
        @AuraEnabled public String accountName;
        @AuraEnabled public String accountNumber;
        @AuraEnabled public String address;
        @AuraEnabled public Boolean isParentAccount;
        @AuraEnabled public Integer equipmentCount = 0;
        @AuraEnabled public List<EquipmentCard> equipment = new List<EquipmentCard>();
    }

    public class EquipmentCard {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String recordTypeName;
        @AuraEnabled public Decimal serviceRequestCount;
        @AuraEnabled public List<FieldCell> equipmentFields = new List<FieldCell>();
        @AuraEnabled public List<AccessoryItem> accessories = new List<AccessoryItem>();
        @AuraEnabled public List<FieldCell> leaseFields = new List<FieldCell>();
        @AuraEnabled public List<FieldCell> csmaFields = new List<FieldCell>();
        @AuraEnabled public List<MeterGroup> csmaGroups = new List<MeterGroup>();
        @AuraEnabled public List<MeterGroup> meterGroups = new List<MeterGroup>();
    }

    public class AccessoryItem {
        @AuraEnabled public Id id;
        @AuraEnabled public String label;
        @AuraEnabled public List<FieldCell> fields = new List<FieldCell>();
    }

    public class MeterGroup {
        @AuraEnabled public String groupLabel;
        @AuraEnabled public List<FieldCell> fields = new List<FieldCell>();
    }

    public class FieldCell {
        @AuraEnabled public String label;
        @AuraEnabled public String name;
        @AuraEnabled public String type;
        @AuraEnabled public Object value;
    }
}