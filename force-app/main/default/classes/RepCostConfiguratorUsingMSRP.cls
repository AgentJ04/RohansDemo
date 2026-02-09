public class RepCostConfiguratorUsingMSRP {
@InvocableMethod(Label='Handle Rep Cost Calculation using MSRP')
    public static void handleDealerCostCalculation(List<Request> requestParams){
		String manufacturer 	= requestParams[0].manufacturer;
		String productType 		= requestParams[0].productType;
		String costType 		= requestParams[0].costType;
        Decimal upliftPercent 	= requestParams[0].percentageValue;
        
        System.debug(costType);
        String type = 'TSGCFG__Price_Book__c';
        Map<String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe();
        Schema.SObjectType leadSchema = schemaMap.get(type);
        Map<String, Schema.SObjectField> fieldMap = leadSchema.getDescribe().fields.getMap();
        String fieldsToQuery = '';
        Map<String,String> fieldMapUse = new Map<String,String>();
        
        for (String fieldName: fieldMap.keySet()) {
            if(fieldName.contains('tsgcfg__rep_price_level') || fieldName.contains('tsgcfg__cost_price_level') || fieldName.contains('tsgcfg__sales_price_level')){
                fieldsToQuery += ', ' + fieldName;
                //api name vs label
                fieldMapUse.put(fieldName, fieldMap.get(fieldName).getDescribe().getLabel());
            }
        }
        
        fieldMapUse.put('TSGCFG__Suggested_Retail_Price__c', 'MSRP');
        
        String query = 'SELECT Id,TSGCFG__Suggested_Retail_Price__c ' + fieldsToQuery +' FROM TSGCFG__Price_Book__c WHERE TSGCFG__Product_Type__c = :productType AND TSGCFG__Manufacturer__c = :manufacturer';

        List<TSGCFG__Price_Book__c> priceBookList = Database.query(query);
                System.debug(priceBookList);
        List<TSGCFG__Price_Book__c> updateRecords = new List<TSGCFG__Price_Book__c>();
        
        for(TSGCFG__Price_Book__c pBRecord : priceBookList){
            TSGCFG__Price_Book__c pBRec = new TSGCFG__Price_Book__c(Id = pbRecord.Id);
            for(String apiName : fieldMapUse.keySet()){
                if(fieldMapUse.get(apiName).containsIgnoreCase(costType) && apiName.containsIgnoreCase('Cost')){
            		System.debug(fieldMapUse.get(apiName) + ' Reached here with ' + apiName + ' - ' + pbRecord.Id);
                    Decimal costLevel = (Decimal)pBRecord.get('TSGCFG__Suggested_Retail_Price__c');
                    if(costLevel != null){
                         String repCostApiName = '';
                        //System.debug('Old Value:' + costLevel);
                        //Find corresponding rep cost field and put the value on it
                        if(apiName.contains('1') || apiName.contains('2') || apiName.contains('3') || apiName.contains('4') || apiName.contains('5') || apiName.contains('6')){
                            repCostApiName = apiName.replace('cost', 'sales').replace('Cost','sales');
                        }
                        else{
                            repCostApiName = apiName.replace('cost', 'rep').replace('Cost','rep');
                        }
						//System.debug(repCostApiName);
                        pBRec.put(repCostApiName, (costLevel * ((upliftPercent/100) + 1))); 
                        //System.debug('New Value' + pBRec.get(apiName));
                        updateRecords.add(pBRec);
                    }
                }
            }
        }
        
        if(updateRecords.size() > 0){
            update updateRecords;
        }
    }
    
    public class Request{
        @InvocableVariable
        public String manufacturer;
		@InvocableVariable
        public String productType;
		@InvocableVariable
        public String costType;
        @InvocableVariable
        public Decimal percentageValue;
    }
}