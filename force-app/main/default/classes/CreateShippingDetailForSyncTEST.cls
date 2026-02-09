@isTest
    public class CreateShippingDetailForSyncTEST {
        public static final String MODEL = 'Model';
        public static final String MODEL_RTID = Schema.SObjectType.TSGCFG__Price_Book__c.getRecordTypeInfosByName().get(MODEL).getRecordTypeId();
        static testMethod void itShould(){
        
        Account parentAcc = new Account(Name = 'testAccountparent',ShippingStreet = 'street', ShippingCity = 'city', ShippingState = 'state', ShippingCountry = 'country', ShippingPostalCode = '00000');
        insert parentAcc;

        Account acc = new Account(Name = 'testAccount',ShippingStreet = 'street', ShippingCity = 'city',TSGCFG__Price_Book__c = 'Standard', ShippingState = 'state', ShippingCountry = 'country', ShippingPostalCode = '00000', parentId = parentAcc.id);
        insert acc;

        TSGADX__Deal__c deal = new TSGADX__Deal__c(Name = 'testDeal1', TSGADX__Type__c = 'CTI', TSGADX__Deal_Assignment__c = 'Order/Installer',TSGADX__Company__c = acc.id, TSGADX__Price__c = 200 ,TSGADX__Product_Service__c = 'Test deal record', TSGADX__Close_Date__c = system.today(),TSGCFG__Price_Book__c = 'Large Deal');
        insert deal;

        TSGCFG__Quote__c qt = new TSGCFG__Quote__c(Name = 'Test Quote', TSGCFG__Deal__c = deal.Id, TSGCFG__Price_Book__c = 'Standard', TSGCFG__Primary__c = TRUE);
        insert qt;

        TSGCFG__Quote__c qt2 = new TSGCFG__Quote__c(Name = 'Test Quote', TSGCFG__Deal__c = deal.Id, TSGCFG__Price_Book__c = 'Standard', TSGCFG__Primary__c = FALSE);
        insert qt2;

        List<TSGCFG__Price_Book__c> models = new List<TSGCFG__Price_Book__c>{
            new TSGCFG__Price_Book__c(Name = 'Product 1', RecordTypeId = MODEL_RTID,TSGCFG__Sales_Price__c = 110, TSGCFG__Product_Code__c = 'pb001', TSGCFG__Active__c = true, TSGCFG__Price_Level_1_Active__c = true, TSGCFG__Price_Level_2_Active__c = true, TSGCFG__Price_Level_3_Active__c = true, TSGCFG__Sales_Price_Level_1__c = 300, TSGCFG__Cost_Price_Level_1__c = 300, TSGCFG__Printing_Segment__c = '1'),
            new TSGCFG__Price_Book__c(Name = 'Product 2',RecordTypeId = MODEL_RTID, TSGCFG__Sales_Price__c = 220, TSGCFG__Product_Code__c = 'pb002', TSGCFG__Active__c = true, TSGCFG__Price_Level_1_Active__c = true, TSGCFG__Price_Level_2_Active__c = true, TSGCFG__Price_Level_3_Active__c = true, TSGCFG__Sales_Price_Level_1__c = 300, TSGCFG__Cost_Price_Level_1__c = 300, TSGCFG__Printing_Segment__c = '1')
        };
        insert models;
        system.debug('*** models *** ' + models);

        TSGCFG__Price_Book_Field_Setting__c pricebookFieldSetting = new TSGCFG__Price_Book_Field_Setting__c(
            Name = 'Standard', 
            TSGCFG__Active_Price_Field_API_Name__c = 'TSGCFG__Price_Level_1_Active__c', 
            TSGCFG__Cost_Price_Field_API_Name__c = 'TSGCFG__Cost_Price_Level_1__c', 
            TSGCFG__Sales_Price_Field_API_Name__c = 'TSGCFG__Sales_Price_Level_1__c');

        insert pricebookFieldSetting;

        TSGCFG__Configuration__c config = new TSGCFG__Configuration__c(Name = 'Test Config', TSGCFG__Quote__c = qt.id, TSGCFG__Total_Price__c= 200, TSGCFG__Qty__c = 1);
        insert config;

        system.debug('*** config *** ' + config);

        TSGCFG__Quote_Line_Items__c qtItm1 = new TSGCFG__Quote_Line_Items__c(TSGCFG__Quote__c = qt.id, TSGCFG__Qty__c= 1, TSGCFG__Product__c = models[0].Id, TSGCFG__Configuration__c = config.Id, TSGCFG__Total_Price__c = 100, TSGCFG__CPC_B_W__c = 0, TSGCFG__CPC_Color__c = 0, TSGCFG__Volume_B_W__c = 10, TSGCFG__Volume_Color__c = 0);
        
        List<TSGCFG__Quote_Line_Items__c> qtItmList = new List<TSGCFG__Quote_Line_Items__c>{qtItm1};
        system.debug('*** qtItmList *** ' + qtItmList);
        insert qtItmList;

        TSGCFG__Shipping_Information__c ship = new TSGCFG__Shipping_Information__c();
            ship.TSGCFG__Account__c = deal.TSGADX__Company__c;
            ship.TSGCFG__Deal__c = deal.id;
            ship.TSGCFG__Quantity__c = 1;
            ship.TSGCFG__Configuration__c = config.id;
            insert ship;

        system.debug('*** ship *** ' + ship);

        Test.startTest();
        CreateShippingDetailForSync.createShipRecords(deal.id,qt.id);

        ApexPages.currentPage().getParameters().put('Id',deal.Id);
        Apexpages.StandardController stdDeal = new Apexpages.StandardController(deal);
        shippingError obj = new shippingError(stdDeal);

        test.stopTest();
       }


       static testMethod void testShippingError(){
        
        // parent
        Account parentAcc = new Account(Name = 'testAccountparent',ShippingStreet = 'street', ShippingCity = 'city', ShippingState = 'state', ShippingCountry = 'country', ShippingPostalCode = '00000');
        insert parentAcc;

        // child Account
        Account acc = new Account(Name = 'testAccount',ShippingStreet = 'street', ShippingCity = 'city',TSGCFG__Price_Book__c = 'Standard', ShippingState = 'state', ShippingCountry = 'country', ShippingPostalCode = '00000', parentId = parentAcc.id);
        insert acc;

        // deal
        TSGADX__Deal__c deal = new TSGADX__Deal__c(Name = 'testDeal1', TSGADX__Type__c = 'CTI', TSGADX__Deal_Assignment__c = 'Order/Installer',TSGADX__Company__c = acc.id, TSGADX__Price__c = 200 ,TSGADX__Product_Service__c = 'Test deal record', TSGADX__Close_Date__c = system.today(),TSGCFG__Price_Book__c = 'Large Deal');
        insert deal;

        // quote
        TSGCFG__Quote__c qt = new TSGCFG__Quote__c(Name = 'Test Quote', TSGCFG__Deal__c = deal.Id, TSGCFG__Price_Book__c = 'Standard', TSGCFG__Primary__c = TRUE);
        insert qt;

        // configuration
        TSGCFG__Configuration__c config = new TSGCFG__Configuration__c(Name = 'Test Config', TSGCFG__Quote__c = qt.id, TSGCFG__Total_Price__c= 200, TSGCFG__Qty__c = 1);
        insert config;

        TSGCFG__Configuration__c config2 = new TSGCFG__Configuration__c(Name = 'Test Config2', TSGCFG__Quote__c = qt.id, TSGCFG__Total_Price__c= 200, TSGCFG__Qty__c = 1);
        insert config2;

        // shipping information
        TSGCFG__Shipping_Information__c ship = new TSGCFG__Shipping_Information__c();
            ship.TSGCFG__Account__c = deal.TSGADX__Company__c;
            ship.TSGCFG__Deal__c = deal.id;
            ship.TSGCFG__Quantity__c = 1;
            ship.TSGCFG__Configuration__c = config.id;
            insert ship;

        test.startTest();

        ApexPages.currentPage().getParameters().put('Id',deal.Id);
        Apexpages.StandardController stdDeal = new Apexpages.StandardController(deal);
        shippingError obj = new shippingError(stdDeal);

        test.stopTest();
    }
    }