/*
	Created by Kandisa Technologies
	Date: 29th October
*/
trigger MeterReadingTrigger on MeterReading__c (before insert) {
    
    EA_Settings__c eaSett = EA_Settings__c.getInstance();

    if(trigger.isBefore && trigger.isInsert){
    	// Run Trigger only if Custom Setting is enabled. 
    	if(eaSett.Enable_Mark_Latest_Meter_Reading_Trigger__c)
        	MeterReadingsHelper.updateIsLatest(trigger.new);
    }
}