import { LightningElement, api } from 'lwc';
import getConfig from '@salesforce/apex/Pro_FileUploadHelper.getConfig';
import processCsvDirect from '@salesforce/apex/Pro_FileUploadHelper.processCsvDirect';

export default class Pro_FileImportScreen extends LightningElement {
    @api recordId;
    configName;
    sampleFileUrl;
    isConfigActive = false;
    fileContent;
    fileName;
    errorMessage;
    successMessage;

    connectedCallback() {
        this.loadConfig();
    }

    async loadConfig() {
        try {
            const result = await getConfig({ configId: this.recordId });
            this.configName = result.Name__c;
            this.isConfigActive = result.Active__c;

            if (result.Sample_File_Id__c) {
                this.sampleFileUrl = `/sfc/servlet.shepherd/document/download/${result.Sample_File_Id__c}`;
            }
        } catch (error) {
            this.errorMessage = error.body?.message || 'Error loading config.';
        }
    }

    handleFileChange(event) {
        const file = event.target.files[0];
        if (file) {
            this.fileName = file.name;
            const reader = new FileReader();
            reader.onload = () => {
                this.fileContent = reader.result;
            };
            reader.readAsText(file);
        }
    }

    async processFile() {
        try {
            this.errorMessage = '';
            this.successMessage = '';
            await processCsvDirect({ configId: this.recordId, csvContent: this.fileContent });
            this.successMessage = 'File processed successfully';
        } catch (error) {
            this.errorMessage = error.body?.message || 'Error processing file.';
        }
    }

    downloadSampleFile() {
        window.open(this.sampleFileUrl, '_blank');
    }

    openFileDialog() {
        if (this.isConfigActive) {
            this.template.querySelector('input[type="file"]').click();
        }
    }

    get isDisabled() {
        return !this.isConfigActive;
    }

    get isSampleDisabled() {
        return !this.isConfigActive || !this.sampleFileUrl;
    }

}