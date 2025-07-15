import { LightningElement, api, track } from 'lwc';
import { subscribe, onError } from 'lightning/empApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

export default class PopupComponent extends NavigationMixin(LightningElement) {
    channelName = '/event/OutofOffice_Confirmation_Dialog__e';
    subscription = {};
    isModalOpen = false;
    @api recordId;
    taskRecorId;
    userName;
    outOfOfficeDate;

    connectedCallback() {
        this.registerErrorListener();
        this.handleSubscribe();
    }

    handleSubscribe() {
        const messageCallback = (response) => {
            // Get the relevant data
            const username = response.data.payload.AssignedToUser_ID__c;
            const taskRecorId = response.data.payload.TaskId__c;
            const outOfOfficeMSG = response.data.payload.Out_Of_Office_MSG__c;

            // Extract only the last date if there's a range
            const lastDate = outOfOfficeMSG.includes('-') 
                ? outOfOfficeMSG.split('- ').pop() 
                : outOfOfficeMSG.split(': ').pop();

            if (this.recordId === taskRecorId) {
                this.outOfOfficeDate = `(${lastDate}`;
                this.userName = username;
                this.isModalOpen = true; // Open modal for multiple users
            }
        };

        subscribe(this.channelName, -1, messageCallback).then(response => {
            this.subscription = response;
        });
    }

    navigateToEditPage() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.recordId,
                objectApiName: 'Task',
                actionName: 'edit'
            }
        });
    }

    registerErrorListener() {
        onError(error => {
            console.error('Received error from server: ', JSON.stringify(error));
        });
    }

    handleYesClick() {
        this.isModalOpen = false;
    }

    handleNoClick() {
        this.navigateToEditPage();
        this.isModalOpen = false;
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(evt);
    }
}