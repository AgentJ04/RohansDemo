@isTest
public class shippingErrorTest {
    public static final String MODEL = 'Model';
    public static final String MODEL_RTID = Schema.SObjectType.TSGCFG__Price_Book__c.getRecordTypeInfosByName().get(MODEL).getRecordTypeId();
    
    
    
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