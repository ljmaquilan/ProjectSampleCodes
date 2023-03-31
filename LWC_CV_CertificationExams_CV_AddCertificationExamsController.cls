/** 
 * @description       : Apex Controller Class for cv_certificationExams LWC
 * @author            : Lorraine Policarpio (lpolicarpio@deloitte.com) 
 * @last modified on  : 02-14-2023 
 * @last modified by  : Lorraine Policarpio (lpolicarpio@deloitte.com)
 * 
 * Modifications Log 
 * Ver   Date         Author                                            Modification 
 * 1.0   02-14-2023   Lorraine Policarpio (lpolicarpio@deloitte.com)    Initial Version 
**/ 

public without sharing class CV_AddCertificationExamsController {

    /** 
    * @description: Adds a new Certification Exam record 
    * @author   Lorraine Policarpio (lpolicarpio@deloitte.com) | 02-14-2023 
    * @param    loggedInUserId - User ID of the logged in user,
                selectedCapability - Capability which the logged in user has selected, 
                certExamCategory - category in which the Certification Exam is under, 
                certExamName - name of the Certification Exam,
                certExamCost - total cost of the Certification Exam,
                certExamDescription - description of the Certification Exam
    * @return   listOfCertExamsForCapability - List of the Certification Exams for the selected Capability
    **/ 
    @AuraEnabled
    public static List<Certification_Exam__c> addNewCertExam(String selectedCapability, String certExamCategory, String certExamName, Decimal certExamCost, String certExamDescription){

        List<Certification_Exam__c> listOfCertExamsForCapability = new List<Certification_Exam__c>();

        try{

            Certification_Exam__c newCertExamRecord = new Certification_Exam__c();
            newCertExamRecord.Capability__c = selectedCapability;
            newCertExamRecord.Category__c = certExamCategory;
            newCertExamRecord.Name__c = certExamName;
            newCertExamRecord.Cost__c = certExamCost;                                
            newCertExamRecord.CV_Description__c = certExamDescription;
        
            Database.insert(newCertExamRecord);
            listOfCertExamsForCapability = getCertExamsForSelectedCapability(selectedCapability);

        }catch (Exception e) {
            System.debug('The following exception has occurred in CV_AddCertificationsController.addNewCertExam() at line: ' + e.getLineNumber() + ' - ' + e.getMessage());
            throw new AuraHandledException('ERROR at line ' + e.getLineNumber() + ' ---> ' + e.getMessage());
        }

        return listOfCertExamsForCapability;

    }

    /** 
    * @description: Processes the uploaded CSV file containing the Certification Exam/s details 
    * @author   Lorraine Policarpio (lpolicarpio@deloitte.com) | 02-14-2023 
    * @param    selectedCapability - Capability which the logged in user has selected, 
                fileData - String which contains the data in the uploaded CSV file
                // contentDocumentId - document ID of the uploaded CSV file //UNCOMMENT ONCE QRM TRIGGER IS FIXED
    * @return   listOfCertExamsForCapability - List of the Certification Exams for the selected Capability
    **/ 
    @AuraEnabled
    // public static List<Certification_Exam__c> loadDataFromCSV(String selectedCapability, String fileData, Id contentDocumentId){ //UNCOMMENT ONCE QRM TRIGGER IS FIXED
    public static CertificationExamWrapper loadDataFromCSV(String selectedCapability, String fileData){
        String invalidHeaders = 'Invalid headers. File must be in set in the ff headers: Category, Name, Cost, Description.';
        String invalidValueFormat = 'Invalid cost format. Please use a number type.';

        String expectedHeader = 'Category,Name,Cost,Description';

        List<Certification_Exam__c> listOfCertExamsForCapability = new List<Certification_Exam__c>();
        List<Certification_Exam__c> listOfCertExams = new List<Certification_Exam__c>();
        Map<String, Certification_Exam__c> certificationExamMap = new Map<String, Certification_Exam__c>();
        List<Certification_Exam__c> dupeCertExamsList = new List<Certification_Exam__c>();
        List<String> certCategoryList = new List<String>();
        List<String> certNameList = new List<String>();
        CertificationExamWrapper certExamsWrapper;
        String dupeCertCapabCategoryNameKey = '';
        String certCapabCategoryNameKey = '';
        Boolean dupeExists = false;

        if(String.isNotBlank(fileData)){
        /*UNCOMMENT LINES 74-75 ONCE QRM TRIGGER IS FIXED AND REMOVE LINES 71, 78*/
        // if(contentDocumentId != null){ 
            // ContentVersion contentVersionObj = [SELECT Id, VersionData FROM ContentVersion WHERE ContentDocumentId = :contentDocumentId];
            // List <String> listOfRecordsFromCSV = contentVersionObj.VersionData.toString().split('n');

            List<String> listOfRecordsFromCSV = new List<String>();

            if(Test.isRunningTest()){
                listOfRecordsFromCSV = fileData.split('\n');
            }else{
                listOfRecordsFromCSV = EncodingUtil.base64Decode(fileData).toString().split('\r\n');
            }

            if(!listOfRecordsFromCSV.isEmpty()){
                
                String listOfHeadersFromCSV = listOfRecordsFromCSV[0].normalizeSpace();
                
                if(String.isNotBlank(listOfHeadersFromCSV)){

                    //Check if the headers are all valid
                    if(listOfHeadersFromCSV.contains(expectedHeader)){

                        listOfRecordsFromCSV.remove(0);

                        for (String thisRecordFromCSV : listOfRecordsFromCSV) {
                            
                            if (String.isNotBlank(thisRecordFromCSV)){

                                Certification_Exam__c newCertExamRecord = new Certification_Exam__c();
                                List<String> currentRow = thisRecordFromCSV.split(',');

                                if(String.isNotBlank(currentRow[0])){

                                    newCertExamRecord.Capability__c = selectedCapability;
                                    newCertExamRecord.Category__c = currentRow[0];
                                    newCertExamRecord.Name__c = currentRow[1];
								
                                    //Check if the Cost for the current row is a valid numerical value
                                    if(String.isNotBlank(currentRow[2]) && currentRow[2].isNumeric()){

                                        newCertExamRecord.Cost__c = Decimal.valueOf(currentRow[2]);
                                        
                                        if(currentRow.size()>3){
                                            newCertExamRecord.CV_Description__c = currentRow[3];
                                        }
                                       	
                                        certCategoryList.add(newCertExamRecord.Category__c);
                                        certNameList.add(newCertExamRecord.Name__c);
                                        
                                        certCapabCategoryNameKey = selectedCapability + '-' + newCertExamRecord.Category__c + '-' + newCertExamRecord.Name__c;

                                        certificationExamMap.put(certCapabCategoryNameKey, newCertExamRecord);

                                    }else{
                                        throw Utility.newMessageException(invalidValueFormat);
                                    }
                                }
                                
                            }
                        }
                        
                        for(Certification_Exam__c eachdupeCertExam : [SELECT Capability__c, Category__c, Name__c FROM Certification_Exam__c
                                                                  WHERE Capability__c = :selectedCapability AND Category__c IN :certCategoryList AND Name__c IN :certNameList]) {

                            dupeCertCapabCategoryNameKey = eachdupeCertExam.Capability__c + '-' + eachdupeCertExam.Category__c + '-' + eachdupeCertExam.Name__c;
                                                                          
                             if(certificationExamMap.containsKey(dupeCertCapabCategoryNameKey)) {
                                 certificationExamMap.remove(dupeCertCapabCategoryNameKey);
                                 dupeExists = true;
                             }                                             
                        }
                                               
                        try{    
                            
                            //if there are records to insert whether or not duplicates are found
                            if(!certificationExamMap.isEmpty()){
                                
                                Database.insert(certificationExamMap.values());
                            	listOfCertExamsForCapability = getCertExamsForSelectedCapability(selectedCapability);
                            	certExamsWrapper = new CertificationExamWrapper(listOfCertExamsForCapability, dupeExists);
                                
                            }
                            
                            //if all records inserted are all duplicates
                            else if(certificationExamMap.isEmpty() && dupeExists == true) {
                                
                                listOfCertExamsForCapability = getCertExamsForSelectedCapability(selectedCapability);
                            	certExamsWrapper = new CertificationExamWrapper(listOfCertExamsForCapability, dupeExists);
                                
                            }
                        }catch (Exception e) {
                            System.debug('The following exception has occurred in CV_AddCertificationsController.loadDataFromCSV() at line: ' + e.getLineNumber() + ' - ' + e.getMessage());
                            throw new AuraHandledException('ERROR at line ' + e.getLineNumber() + ' ---> ' + e.getMessage());
                        } 

                    }else{
                        throw Utility.newMessageException(invalidHeaders);
                    }

                }
            }
                 
        }

        return certExamsWrapper;
    }

    /** 
    * @description: Gets the Certification Exams for the main Capability of the logged in User
    * @author   Lorraine Policarpio (lpolicarpio@deloitte.com) | 02-14-2023 
    * @param    loggedInUserId - User ID of the logged in user
    * @return   listOfCertExamsForMainCapability - List of the Certification Exams of the logged in User for their main Capability
    **/ 
    @AuraEnabled
    public static List<Certification_Exam__c> getCertExamsForMainCapability(Id loggedInUserId){

        List<Certification_Exam__c> listOfCertExamsForMainCapability = new List<Certification_Exam__c>();

        try{
            
            String selectedCapability = Utility.getMainCapabilityOfLoggedInUser(loggedInUserId);
    
            Certification_Exam__c certExam;
            for(Certification_Exam__c thisCertExam : [SELECT Category__c, Name__c, Cost__c, CV_Description__c FROM Certification_Exam__c WHERE Capability__c = :selectedCapability ORDER BY Category__c, Name__c]){
                
                if(thisCertExam != null){
                    certExam = thisCertExam;
                    listOfCertExamsForMainCapability.add(certExam);
                }

            }

        }catch (Exception e) {
            System.debug('The following exception has occurred in CV_AddCertificationsController.getCertExamsForMainCapability() at line: ' + e.getLineNumber() + ' - ' + e.getMessage());
            throw new AuraHandledException('ERROR at line ' + e.getLineNumber() + ' ---> ' + e.getMessage());
        } 
       
        return listOfCertExamsForMainCapability;

    }

    /** 
    * @description: Gets the Certification Exams for the specified Capability
    * @author   Lorraine Policarpio (lpolicarpio@deloitte.com) | 02-14-2023 
    * @param    selectedCapability - Capability in which the Certification Exams that will be retrieved belongs to
    * @return   listOfCertExamsForCapability - List of the Certification Exams of the logged in User for the selected Capability
    **/ 
    @AuraEnabled
    public static List<Certification_Exam__c> getCertExamsForSelectedCapability(String selectedCapability){

        List<Certification_Exam__c> listOfCertExamsForCapability = new List<Certification_Exam__c>();

        try{

            Certification_Exam__c certExam;
            for(Certification_Exam__c thisCertExam : [SELECT Category__c, Name__c, Cost__c, CV_Description__c FROM Certification_Exam__c WHERE Capability__c = :selectedCapability ORDER BY Name__c]){
                
                if(thisCertExam != null){
                    certExam = thisCertExam;
                    listOfCertExamsForCapability.add(certExam);
                }

            }

        }catch (Exception e) {
            System.debug('The following exception has occurred in CV_AddCertificationsController.getCertExamsForSelectedCapability() at line: ' + e.getLineNumber() + ' - ' + e.getMessage());
            throw new AuraHandledException('ERROR at line ' + e.getLineNumber() + ' ---> ' + e.getMessage());
        } 

        return listOfCertExamsForCapability;

    }
    
    /** 
    * @description: Checks duplicate Certification Exam
    * @author   Joana Felisarta (jfelisarta@deloitte.com) | 03-29-2023 
    * @param    selectedCapability - Capability of the Certification Exam that was selected
    * @param    certExamCategory - Certification Exam Category that was selected
    * @param    certExamName - Certification Exam Name that was entered
    * @return   list of duplicate Certification Exam record
    **/ 

    @AuraEnabled
    public static List<Certification_Exam__c> checkDupeCertExams(String selectedCapability, String certExamCategory, String certExamName) {

        return [SELECT Id FROM Certification_Exam__c WHERE Capability__c = :selectedCapability AND Category__c = :certExamCategory AND Name__c = :certExamName];
        
    }
    
    /** 
    * @description: Certification Exam Wrapper Class to store the list of certification exams and a boolean dupeExists variable
    * @author   Joana Felisarta (jfelisarta@deloitte.com) | 03-30-2023 
    * @param    certExams - List of certification Exams 
    * @param    dupeExists - Boolean variable to identify if similar cert exam already exists in the system
    **/  
    
    public class CertificationExamWrapper {
        @AuraEnabled public List<Certification_Exam__c> certExams;
        @AuraEnabled public Boolean dupeExists;
        
        CertificationExamWrapper(List<Certification_Exam__c> certExams, Boolean dupeExists) {
            
            this.certExams = certExams;
            this.dupeExists = dupeExists;
           
        } 
        
    }

}
