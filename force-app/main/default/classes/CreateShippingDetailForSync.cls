global class CreateShippingDetailForSync {

    webservice static string createShipRecords(String dealId, String quoteId){
        Boolean missingShippingInfo; 
        TSGCFG__Configurator_Setting__c tsgCongif = TSGCFG__Configurator_Setting__c.getOrgDefaults();
        
        if(tsgCongif.Sync_Single_Shipping_Info__c){
            for (TSGCFG__Configuration__c si : [SELECT Id, TSGCFG__Qty__c, (Select Id From TSGCFG__Shipping_Information__r) shippingid FROM TSGCFG__Configuration__c Where TSGCFG__Quote__r.TSGCFG__Deal__c = :dealId and TSGCFG__Quote__r.TSGCFG__Primary__c = True]) {
                if (si.TSGCFG__Shipping_Information__r.size() != si.TSGCFG__Qty__c) {
                    missingShippingInfo = true;
                }else {
                    missingShippingInfo = false;
                }
            }
            
        }else{
            
            missingShippingInfo = false;
            for (TSGCFG__Configuration__c con : [SELECT Id, TSGCFG__Qty__c, (Select Id,TSGCFG__Quantity__c From TSGCFG__Shipping_Information__r) shippingid FROM TSGCFG__Configuration__c Where TSGCFG__Quote__r.TSGCFG__Deal__c = :dealId and TSGCFG__Quote__r.TSGCFG__Primary__c = TRUE]) {
                system.debug('TSGCFG__Shipping_Information__r.size() : '+con.TSGCFG__Shipping_Information__r.size() + '@@@ : '+con.TSGCFG__Qty__c );
                if(con.TSGCFG__Shipping_Information__r.size()>0){
                    Integer i = 0;
                    for(TSGCFG__Shipping_Information__c si : con.TSGCFG__Shipping_Information__r){
                        i+= Integer.valueOf(si.TSGCFG__Quantity__c);
                    }
                    if(i != con.TSGCFG__Qty__c ){
                        missingShippingInfo = true;
                    }
                    system.debug('i : '+i + '@@@ : '+con.TSGCFG__Qty__c );
                }else if(con.TSGCFG__Shipping_Information__r.size() != con.TSGCFG__Qty__c){
                    missingShippingInfo = true;
                }
                
            }
            
        }
        
        
        if(missingShippingInfo != true){
            system.debug('*** missingShippingInfo *** ' + missingShippingInfo);
        try{
            system.debug('Quote Id : '+quoteId+' Deal Id : '+dealId);
            map<id,list<TSGCFG__Quote_Line_Items__c>> configIdItems = new map<id,list<TSGCFG__Quote_Line_Items__c>>();
            map<id,list<TSGCFG__Shipping_Information__c>> configIdShipInfo = new map<id,list<TSGCFG__Shipping_Information__c>>();
            map<id,id> accToPrimaryCont = new map<id,id>();

            // get all QLI and Shipping Infor for Configuration 
            for(TSGCFG__Configuration__c config : [select TSGCFG__Qty__c,
            (Select Id,TSGCFG__Product__c,TSGCFG__Product_Type__c, TSGCFG__Product__r.Name, TSGCFG__Product__r.RecordTypeId, TSGCFG__Product__r.RecordType.Name,TSGCFG__Product__r.TSGCFG__Description__c, TSGCFG__Product__r.TSGCFG__Product_Code__c, TSGCFG__Product_Name__c, TSGCFG__Description__c From TSGCFG__Quote_Line_Items__r order by CreatedDate),
            (select TSGCFG__Quantity__c,TSGCFG__Account__c from TSGCFG__Shipping_Information__r)
            from TSGCFG__Configuration__c where TSGCFG__Quote__c in (Select Id From TSGCFG__Quote__c where TSGCFG__Deal__c = :dealId AND TSGCFG__Deal__r.Has_Quote__c = TRUE AND TSGCFG__Primary__c = TRUE)])
            {
                configIdItems.put(config.id,config.TSGCFG__Quote_Line_Items__r);
                configIdShipInfo.put(config.id,config.TSGCFG__Shipping_Information__r);
            }

            // logic to get primary contact of Account
            for(id confId : configIdShipInfo.keySet()){
                for(TSGCFG__Shipping_Information__c ship : configIdShipInfo.get(confId)){
                    accToPrimaryCont.put(ship.TSGCFG__Account__c,null); 
                }
            }
            for(Contact cont : [select id, accountId from Contact where accountId in : accToPrimaryCont.keySet() and TSGADX__Primary_Contact__c = true]){
                accToPrimaryCont.put(cont.accountId,cont.id);
            }
            
            system.debug('configIdItems : '+configIdItems);
            system.debug('configIdShipInfo : '+configIdShipInfo);
            // delete all recent print details
            list<TSGCFG__Shipping_Print_Detail__c> listTodelete = [Select Id from TSGCFG__Shipping_Print_Detail__c where TSGCFG__Deal__c = :dealId];
            if(listTodelete.size() > 0)
                delete listTodelete;

                list<TSGADX__Deal__c> dealToUpdate = new list<TSGADX__Deal__c>();
              for(TSGADX__Deal__c d : [Select Id, Last_Sync__c From TSGADX__Deal__c Where Id = :dealId])
              {
                  d.Last_Sync__c = Datetime.now();
                  dealToUpdate.add(d);
              }
              upsert dealToUpdate;
              system.debug('*** dealToUpdate *** ' + dealToUpdate);
                
            if(!configIdShipInfo.isEmpty()){
                list<TSGCFG__Shipping_Print_Detail__c> shipDetailList = new list<TSGCFG__Shipping_Print_Detail__c>();
                for(id configId : configIdShipInfo.keySet()){
                    
                    if(configIdShipInfo.get(configId).size() > 0){
                        for(TSGCFG__Shipping_Information__c ship : configIdShipInfo.get(configId)){
                            for(integer count = 1; count <= ship.TSGCFG__Quantity__c; count++){
                                TSGCFG__Shipping_Print_Detail__c shipDetail = new TSGCFG__Shipping_Print_Detail__c();
                                shipDetail.TSGCFG__Account__c = ship.TSGCFG__Account__c;
                                shipDetail.TSGCFG__Configuration__c = configId;
                                shipDetail.TSGCFG__Deal__c = dealId;
                                shipDetail.TSGCFG__Shipping_Information__c = ship.Id;
                                if(accToPrimaryCont.containsKey(ship.TSGCFG__Account__c))
                                    shipDetail.TSGCFG__Primary_Contact__c = accToPrimaryCont.get(ship.TSGCFG__Account__c);
                                shipDetailList.add(shipDetail);
                            }
                        }
                        
                    }
                }
                if(shipDetailList.size() > 0){
                    insert shipDetailList;
                    list<TSGCFG__Shipping_Line_Item__c> lineItems = new list<TSGCFG__Shipping_Line_Item__c>();
                    for(TSGCFG__Shipping_Print_Detail__c ship : shipDetailList){
                        if(configIdItems.get(ship.TSGCFG__Configuration__c).size() > 0){
                            for(TSGCFG__Quote_Line_Items__c QLI : configIdItems.get(ship.TSGCFG__Configuration__c)){
                                TSGCFG__Shipping_Line_Item__c item = new TSGCFG__Shipping_Line_Item__c();
                                item.TSGCFG__Quote_Line_Item__c = QLI.Id;
                                item.TSGCFG__Shipping_Print_Detail__c = ship.id;
                                item.TSGCFG__Product_Type__c = QLI.TSGCFG__Product_Type__c;
                                
                                if(QLI.TSGCFG__Product__c != null) {
                                    item.TSGCFG__Product__c = QLI.TSGCFG__Product__c;
                                    item.TSGCFG__Product_Name__c = QLI.TSGCFG__Product__r.Name;
                                    item.TSGCFG__Product_Code__c = QLI.TSGCFG__Product__r.TSGCFG__Product_Code__c;
                                    item.TSGCFG__Description__c  = QLI.TSGCFG__Product__r.TSGCFG__Description__c;
                                }
                                else {
                                    item.TSGCFG__Product_Name__c = QLI.TSGCFG__Product_Name__c;
                                    item.TSGCFG__Description__c  = QLI.TSGCFG__Description__c;
                                }
                                lineItems.add(item);
                            }
                        }   
                    }
                    if(lineItems.size() > 0)
                        insert lineItems;
                }
            }
            return 'Successfully created!';
        }
        catch(Exception e){
            return 'Following error occurred : '+e.getMessage()+' at line number : '+e.getLineNumber();
        }
        }return null;
    }
}