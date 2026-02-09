public with sharing class shippingError {
    
    public  List<TSGCFG__Configuration__c> config;
    public Boolean hasShippingInfo {get;set;}
    
    public shippingError(ApexPages.StandardController stdController) {
        Id dealId = Apexpages.currentPage().getParameters().get('Id');
        config = [SELECT Id, TSGCFG__Qty__c, (Select Id,TSGCFG__Quantity__c From TSGCFG__Shipping_Information__r) shippingid FROM TSGCFG__Configuration__c Where TSGCFG__Quote__r.TSGCFG__Deal__c = :dealId and TSGCFG__Quote__r.TSGCFG__Primary__c = TRUE];
        system.debug('*** config.size() *** ' + config.size());
        hasShippingInfo = true;
        for (TSGCFG__Configuration__c con : config) {
            system.debug('TSGCFG__Shipping_Information__r.size() : '+con.TSGCFG__Shipping_Information__r.size() + '@@@ : '+con.TSGCFG__Qty__c );
            if(con.TSGCFG__Shipping_Information__r.size()>0){
                Integer i = 0;
                for(TSGCFG__Shipping_Information__c si : con.TSGCFG__Shipping_Information__r){
                    i+= Integer.valueOf(si.TSGCFG__Quantity__c);
                }
                if(i != con.TSGCFG__Qty__c ){
                    hasShippingInfo = false;
                }
                system.debug('i : '+i + '@@@ : '+con.TSGCFG__Qty__c );
            }else if(con.TSGCFG__Shipping_Information__r.size() != con.TSGCFG__Qty__c){
                hasShippingInfo = false;
            }
            
        }
        system.debug('hasShippingInfo :: '+hasShippingInfo);
    }
}