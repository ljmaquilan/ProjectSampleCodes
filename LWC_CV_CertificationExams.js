import { LightningElement, track, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';

import userId from '@salesforce/user/Id';

import getCapabilityOfLoggedInUser from '@salesforce/apex/Utility.getCapabilityOfLoggedInUser';
import getMainCapabilityOfLoggedInUser from '@salesforce/apex/Utility.getMainCapabilityOfLoggedInUser';
import getCertExamsForMainCapability from '@salesforce/apex/CV_AddCertificationExamsController.getCertExamsForMainCapability';
import getCertExamsForSelectedCapability from '@salesforce/apex/CV_AddCertificationExamsController.getCertExamsForSelectedCapability';
import loadDataFromCSV from '@salesforce/apex/CV_AddCertificationExamsController.loadDataFromCSV';
import addNewCertExam from '@salesforce/apex/CV_AddCertificationExamsController.addNewCertExam';
import checkDupeCertExams from '@salesforce/apex/CV_AddCertificationExamsController.checkDupeCertExams';

import CERTIFICATION_EXAM_OBJECT from '@salesforce/schema/Certification_Exam__c';
import CERTIFICATION_EXAM_CATEGORY from '@salesforce/schema/Certification_Exam__c.Category__c';

const columns = [
    { label: 'Category', fieldName: 'Category__c', editable: true },
    { label: 'Name', fieldName: 'Name__c', editable: true },
    { label: 'Cost', fieldName: 'Cost__c', type: 'currency', editable: true },
    { label: 'Description', fieldName: 'CV_Description__c', editable: true },
];

export default class cv_certificationExams extends NavigationMixin(LightningElement) {

    loggedInUserId = userId;

    @track isLoaded = false;

    @track isSaving = false;

    @track usersCapability = [];

    @track certExamCategories = [];

    @track isModalOpen = false;

    @track isModalOpenForCSVUpload = false;

    @track fileData;

    @track fileName;

    @track certData = [];

    @track columns = columns;

    @track rowOffset = 0;

    @track hasMoreThanOneCapability = false;

    @api selectedChildCapability;

    @api selectedCapability;

    @api certExamCategory;

    @api certExamName;

    @api certExamCost;

    @api certExamDescription;

    @wire(getObjectInfo, { objectApiName: CERTIFICATION_EXAM_OBJECT })
    certificationExamInfo;

    @wire(getPicklistValues, { recordTypeId:'$certificationExamInfo.data.defaultRecordTypeId', fieldApiName: CERTIFICATION_EXAM_CATEGORY })
    certificationCategory({ data, error }) {
        if (data){
            this.certExamCategories = data.values;
            console.log(this.certExamCategories);
        }
    }

    connectedCallback(){
        this.retrieveMainCapabilityOfLoggedInUser();
        this.retriveCapabilityOfLoggedInUser();
        this.retrieveCertExamsForMainCapability();
    }

    handleComponentChange(event){
        this.selectedChildCapability = event.detail;
    }

    retrieveMainCapabilityOfLoggedInUser(){
       getMainCapabilityOfLoggedInUser({loggedInUserId: this.loggedInUserId})
        .then((result) => {
            let mainCapability = '';
            if (result) {
                mainCapability = result;
            } 
            this.selectedCapability = mainCapability;
        })
        .catch((error) => {
            this.error = error;
            console.log("error: ", JSON.stringify(this.error));
        });
    }

    retriveCapabilityOfLoggedInUser(){
        getCapabilityOfLoggedInUser({loggedInUserId: this.loggedInUserId})
        .then((result) => {
            let options = [];
            if (result) {
                result.forEach(r => {
                    options.push({
                    label: r,
                    value: r,
                    });
                });
            }
            if(options.length > 1){
                this.hasMoreThanOneCapability = true;
                this.usersCapability = options;
            }else{
                this.selectedCapability = options[0].label;
                this.retrieveCertExamsForSelectedCapability();
            }
        })
        .catch((error) => {
            this.error = error;
            console.log("error: ", JSON.stringify(this.error));
        });
    }

    retrieveCertExamsForMainCapability(){
        getCertExamsForMainCapability({loggedInUserId: this.loggedInUserId})
        .then((result) => {
            this.certData = result;
        })
        .catch((error) => {
            this.error = error;
            console.log("error: ", JSON.stringify(this.error));
        });

    }

    retrieveCertExamsForSelectedCapability(){
        getCertExamsForSelectedCapability({selectedCapability : this.selectedCapability})
        .then((result) => {
            this.certData = result;
        })
        .catch((error) => {
            this.error = error;
            console.log("error: ", JSON.stringify(this.error));
        });

    }

    handleSelectedCapability(event){
        this.selectedCapability = this.usersCapability.find(opt => opt.label === event.detail.value).label;
        this.retrieveCertExamsForSelectedCapability();
    }

    handleSelectedCategory(event){
        this.certExamCategory = this.certExamCategories.find(opt => opt.label === event.detail.value).label;
    }

    handleEnteredCertExamName(event){
        this.certExamName = event.detail.value;
    }

    handleEnteredCertExamCost(event){
        this.certExamCost = event.detail.value;
    }

    handleEnteredCertExamDescription(event){
        this.certExamDescription = event.detail.value;
    }

    handleAddNewCertificationExam(event){
        let capability = this.template.querySelector(".capability");
        let category = this.template.querySelector(".category");
        let name = this.template.querySelector(".name");
        let cost = this.template.querySelector(".cost");

        if(capability.reportValidity() && category.reportValidity() && name.reportValidity() && cost.reportValidity()){
        
            checkDupeCertExams({selectedCapability: this.selectedChildCapability, certExamCategory: this.certExamCategory, certExamName : this.certExamName})

            .then((result) => {
                if (result.length > 0) {
                    const evt = new ShowToastEvent({
                        title: 'Duplicate Record Found!',
                        message: `${this.certExamName} for ${this.certExamCategory} and ${this.selectedChildCapability} already exists in the System`,
                        variant: 'warning'
                    });
                    this.dispatchEvent(evt);
                    this.certExamCategory = '';
                    this.certExamName = '';
                    this.certExamCost = null;
                    this.certExamDescription = '';
                } else {
                    this.openModal();
                } 
            })
            .catch((error) => {
                this.error = error;
                console.log("error: ", JSON.stringify(this.error));
    
                const evt = new ShowToastEvent({
                    title: 'Failed!',
                    message: error.body.message,
                    variant: 'error',
                    mode: 'dismissable'
                });
                this.dispatchEvent(evt); 
            }); 
        }

    }

    openModal(){
        this.isModalOpen = true;
    }

    closeModal(){
        this.isModalOpen = false;
    }

    submitDetails(){
        this.isModalOpen = false;
        this.isSaving = true;

        addNewCertExam({selectedCapability : this.selectedChildCapability, certExamCategory : this.certExamCategory, certExamName : this.certExamName, 
                        certExamCost : this.certExamCost, certExamDescription : this.certExamDescription})
        .then((result) => {
            if (result) {
                const evt = new ShowToastEvent({
                    title: 'Success!',
                    message: 'New certificate has been added!',
                    variant: 'success',
                    mode: 'dismissable'
                });
                this.dispatchEvent(evt);
                this.isSaving = false;
                this.certExamCategory = '';
                this.certExamName = '';
                this.certExamCost = '';
                this.certExamDescription = '';
                this.certData = result;
            }
        })
        .catch((error) => {
            this.isSaving = false;
            this.error = error;
            console.log("error: ", JSON.stringify(this.error));

            const evt = new ShowToastEvent({
                title: 'Failed!',
                message: error.body.message,
                variant: 'error',
                mode: 'dismissable'
            });
            this.dispatchEvent(evt); 
        });

    }

    openfileUpload(event) {
        const file = event.target.files[0]
        var reader = new FileReader()
        reader.onload = () => {
            var base64 = reader.result.split(',')[1]
            this.fileData = base64;
            this.fileName = file.name;
        }
        reader.readAsDataURL(file)
    }
    
    submitCSVFile(){
        this.isModalOpenForCSVUpload = false;
        this.isLoaded = true;

        /*UNCOMMENT LINES 241-242 AND REMOVE LINE 244 ONCE QRM TRIGGER IS FIXED*/
        // const uploadedFiles = event.detail.files;
        // loadDataFromCSV({loggedInUserId : this.loggedInUserId, selectedCapability : this.selectedCapability, contentDocumentId : uploadedFiles[0].documentId})

        loadDataFromCSV({selectedCapability : this.selectedChildCapability, fileData: this.fileData})
        .then((result) => {
            let returnMessage = '';
            if(result){
                const evt = new ShowToastEvent({
                    title: 'Success!',
                    message: 'New certificates have been uploaded!',
                    variant: 'success',
                    mode: 'dismissable'
                });
                this.dispatchEvent(evt);
                this.isLoaded = false;
                this.fileData = '';
                this.certData = result;
            }
        })
        .catch((error) => {
            this.isLoaded = false;
            this.error = error;
            console.log("error: ", JSON.stringify(this.error));

            const evt = new ShowToastEvent({
                title: 'Failed!',
                message: error.body.message,
                variant: 'error',
                mode: 'dismissable'
            });
            this.fileData = '';
            this.dispatchEvent(evt); 
        });

        this.fileName = '';
    }

    handleUploadCSVFile(event){
        if(this.fileName != ''){
            if(this.fileName.endsWith(".csv") || this.fileName.endsWith(".CSV")){
                this.openModalForCSVUpload();
            }else {
                const evt = new ShowToastEvent({
                    title: 'Failed!',
                    message: 'Invalid extension. File must be in .csv extension!',
                    variant: 'error',
                    mode: 'dismissable'
                });
                this.dispatchEvent(evt);
            }
        }
    }

    openModalForCSVUpload(){
        this.isModalOpenForCSVUpload = true;
    }

    closeModalForCSVUpload(){
        this.isModalOpenForCSVUpload = false;
    }

}
