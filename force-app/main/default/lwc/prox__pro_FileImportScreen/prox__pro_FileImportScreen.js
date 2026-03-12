/*
 * Created by Prodigy Ltd on 27/05/2025.
 *
 * Description: LWC component for CSV file import using configurable metadata. 
 *
 * Last modified by Neethu Ari in Prodigy on 09/06/2025.
*/

import { LightningElement, api } from 'lwc';
import getConfig from '@salesforce/apex/Pro_FileUploadHelper.getConfig';
import processCsvDirect from '@salesforce/apex/Pro_FileUploadHelper.processCsvDirect';
import getExpectedHeaders from '@salesforce/apex/Pro_FileUploadHelper.getExpectedHeaders';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';


export default class Pro_FileImportScreen extends LightningElement {
    @api ConfigDeveloperName;
    configName;
    sampleFileUrl;
    isConfigActive = false;
    fileContent;
    fileName;
    errorMessage;
    successMessage;
    formatsAccepted;
    showSampleHeaderMismatch=false;
    expectedHeaders=[];
    configId;
    showResults = false;
    allResults = [];
    filteredResults = [];
    downloadUrl;
    readyToDownload = false;
    treatBlanksAsNull = false;

    filterText = '';
    columns = [
        { label: 'Line', fieldName: 'lineNumber', type: 'number', initialWidth: 90 },
        { label: 'CSV Line', fieldName: 'originalLine', type: 'text' },
        { label: 'Status', fieldName: 'status', type: 'text' },
        { label: 'Message', fieldName: 'message', type: 'text' }
    ];
    filterOptions = [
        { label: 'All', value: 'All' },
        { label: 'Success', value: 'Success' },
        { label: 'Failed', value: 'Failed' }
    ];
    filterText='All';

    connectedCallback() {
        this.loadConfig();
    }
    renderedCallback() {
        const dropZone = this.template.querySelector('.drop-zone');
        if (dropZone && !dropZone.dataset.initialized) {
            dropZone.addEventListener('dragover', this.handleDragOver.bind(this));
            dropZone.addEventListener('drop', this.handleDrop.bind(this));
            dropZone.dataset.initialized = 'true'; // Prevent duplicate binding
        }
    }

    handleTreatBlanksChange(event) {
        this.treatBlanksAsNull = event.target.checked;
    }

    handleDragOver(event) {
        event.preventDefault(); // Necessary to allow drop
    }

    handleDrop(event) {
        event.preventDefault();
        const files = event.dataTransfer.files;
        if (files.length > 0) {
            this.processDroppedFile(files[0]);
        }
    }

    processDroppedFile(file) {
        if (!file.name.toLowerCase().endsWith('.csv')) {
            this.errorMessage = 'Only CSV files are allowed.';
            return;
        }

        this.fileName = file.name;
        const reader = new FileReader();
        reader.onload = () => {
            this.fileContent = reader.result;

            const firstLine = this.fileContent.split('\n')[0].trim();
            const uploadedHeaders = firstLine.split(',').map(h => h.trim());

            if (!this.validateHeaders(uploadedHeaders)) {
                this.fileContent = null;
                this.fileName = null;
            } else {
                this.errorMessage = '';
            }
        };
        reader.readAsText(file);
    }


    /*
    * Description: Retrieves details like label, activation status, accepted formats, sample file,
    * and expected CSV headers for validation.
    *
    * Last modified by Neethu Ari in Prodigy on 09/06/2025.
    */

    async loadConfig() {
        try {
            const result = await getConfig({ configId: this.ConfigDeveloperName });
            console.log(result);
            this.configName = result.Label;
            this.isConfigActive = result.prox__Active__c;
            this.formatsAccepted=result.prox__Formats_Accepted__c;
            if (result.prox__Sample_File_ID__c) {
                this.sampleFileUrl = `/sfc/servlet.shepherd/document/download/${result.prox__Sample_File_ID__c}`;
            }
            this.configId=result.Id;
            // Fetch expected headers
            this.expectedHeaders = await getExpectedHeaders({ configId: result.Id });
        } catch (error) {
            this.errorMessage = error.body?.message || 'Error loading config.';
        }
    }

    /**
     * Handles file selection via input[type=file]. Reads the file content,
     * extracts header row and validates it against expected headers.If mismatch is found, resets the file input.
     * 
     * Last modified by Neethu Ari in Prodigy on 09/06/2025.
     */
    handleFileChange(event) {
        const file = event.target.files[0];
        if (file) {
            this.fileName = file.name;
            const reader = new FileReader();
            reader.onload = () => {
                this.fileContent = reader.result;

                // Validate header with detailed diff
                const firstLine = this.fileContent.split('\n')[0].trim();
                const uploadedHeaders = firstLine.split(',').map(h => h.trim());

                if (!this.validateHeaders(uploadedHeaders)) {
                    this.fileContent = null;
                    this.fileName = null;
                    // Clear the input for user to re-upload
                    this.template.querySelector('input[type="file"]').value = '';
                } else {
                    this.errorMessage = '';
                }
            };
            reader.readAsText(file);
        }
    }
     /**
     * Compares uploaded CSV header row against expected headers.
     * Ignores order and performs case-insensitive comparison.
     * 
     * Last modified by Neethu Ari in Prodigy on 09/06/2025.
     */
    validateHeaders(uploadedHeaders) {
        if (!this.expectedHeaders || this.expectedHeaders.length === 0) return true;

        const uploadedNormalized = uploadedHeaders.map(h => h.toLowerCase());
        const expectedNormalized = this.expectedHeaders.map(h => h.toLowerCase());

        const uploadedSet = new Set(uploadedNormalized);
        const expectedSet = new Set(expectedNormalized);

        const missing = this.expectedHeaders.filter(h => !uploadedSet.has(h.toLowerCase()));
        const extra = uploadedHeaders.filter(h => !expectedSet.has(h.toLowerCase()));

        if (missing.length === 0 && extra.length === 0) {
            return true;
        }

        const missingMsg = missing.length ? `Missing: ${missing.join(', ')}` : '';
        const extraMsg = extra.length ? `Extra: ${extra.join(', ')}` : '';
        const details = [missingMsg, extraMsg].filter(Boolean).join(' | ');
        this.errorMessage = `Uploaded file headers do not match the expected format. ${details}.`;
        return false;
    }
    /**
     * Processes the CSV file content by invoking Apex to parse and validate.
     * Displays results in a table and resets file input on success.
     * 
     * Last modified by Neethu Ari in Prodigy on 09/06/2025.
     */

    async processFile() {
        if (!this.fileContent) {
            this.errorMessage = 'Please upload a valid file matching the sample format before processing.';
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: this.errorMessage,
                variant: 'error'
            }));
            return;
        }
        try {
            this.errorMessage = '';
            this.successMessage = '';

            const result = await processCsvDirect({
                configId: this.configId,
                csvContent: this.fileContent,
                treatBlanksAsNull: this.treatBlanksAsNull,
                externalIdOverride: null
            });

            this.allResults = result;
            this.filteredResults = result;
            this.showResults = true;
            this.successMessage = 'File processed. Results below.';
            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: this.successMessage,
                variant: 'success'
            }));

            // Reset file input
            this.fileName = null;
            this.fileContent = null;
            this.template.querySelector('input[type="file"]').value = '';

        } catch (error) {
            this.errorMessage = error.body?.message || 'Error processing file.';
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: this.errorMessage,
                variant: 'error'
            }));
        }
    }


    /**
     * Opens the sample file in a new browser tab for download.
     * 
     * Last modified by Neethu Ari in Prodigy on 09/06/2025.
     */
    downloadSampleFile() {
        window.open(this.sampleFileUrl, '_blank');
    }
    /**
     * Triggers click on hidden file input if config is active.
     * 
     * Last modified by Neethu Ari in Prodigy on 09/06/2025.
     */
    openFileDialog() {
        if (this.isConfigActive) {
            this.template.querySelector('input[type="file"]').click();
        }
    }

     /**
     * Returns true if the import button should be disabled.
     * 
     *Last modified by Neethu Ari in Prodigy on 09/06/2025.
     */
    get isDisabled() {
        return !this.isConfigActive;
    }
     /**
     * Returns true if the sample download button should be disabled.
     * 
     * Last modified by Neethu Ari in Prodigy on 09/06/2025.
     */
    get isSampleDisabled() {
        return !this.isConfigActive || !this.sampleFileUrl;
    }
    /**
     * Filters results table based on selected filter value.
     * 
     * Last modified by Neethu Ari in Prodigy on 09/06/2025.
     */

    handleFilterChange(event) {
        this.filterText = event.detail.value;
        if (this.filterText === 'All') {
            this.filteredResults = this.allResults;
        } else {
            this.filteredResults = this.allResults.filter(row => row.status === this.filterText);
        }
    }
    
    /**
     * Downloads the currently filtered results as a CSV file.
     * 
     * Last modified by Neethu Ari in Prodigy on 09/06/2025.
     */
    downloadFiltered() {
        const csvRows = [
            'Line,CSV Line,Status,Message',
            ...this.filteredResults.map(row =>
                `${row.lineNumber},"${row.originalLine?.replace(/"/g, '""')}","${row.status}","${row.message?.replace(/"/g, '""') || ''}"
            `)
        ];
        const blob = new Blob([csvRows.join('\n')], { type: 'application/octet-stream' });
        const link = document.createElement('a');
        link.href = URL.createObjectURL(blob);
        link.download = 'import_results.csv';
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        }

    
      /**
     * Resets the component state to its initial condition.
     * Clears file data, messages, results, and UI inputs.
     * 
     * Last modified by Neethu Ari in Prodigy on 09/06/2025.
     */
    resetAll() {
            this.fileContent = null;
            this.fileName = null;
            this.errorMessage = '';
            this.successMessage = '';
            this.showResults = false;
            this.allResults = [];
            this.filteredResults = [];
            this.filterText = '';
            this.template.querySelector('input[type="file"]').value = '';
        }
}