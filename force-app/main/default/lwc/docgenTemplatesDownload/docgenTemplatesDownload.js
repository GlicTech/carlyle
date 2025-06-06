import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import downloadTemplates from '@salesforce/apex/DocGenTempsDownload.downloadTemplates';
import JSZipResource from '@salesforce/resourceUrl/JSZip';
import { loadScript } from 'lightning/platformResourceLoader';

export default class DocgenTemplatesDownload extends LightningElement {
    @track isLoading = false;
    zipInitialized = false;
    jsZip;
    get isSaveDisabled() {
        return this.isLoading;
    }
    handleCloseModal() {
        const modal = this.template.querySelector('.slds-modal');
        modal.classList.remove('slds-fade-in-open');
        const backdrop = this.template.querySelector('.slds-backdrop');
        backdrop.classList.remove('slds-backdrop_open');
        
        this.dispatchEvent(new CustomEvent('closemodal'));
    }
    handleDownload() {
        this.isLoading = true;
        downloadTemplates()
        .then(result => {
            console.log('Message:', result);
                loadScript(this, JSZipResource + '/JSZip/jszip.min.js')
                    .then(() => {
                        this.jsZip = new window.JSZip();
                        this.zipInitialized = true;
                        this.createZipFile(result);
                    })
                    .catch(error => {
                        this.showNotification('Error', 'Error loading JSZip library.', 'error');
                    });
        })
        .catch(err => {
            this.showNotification('Error',err.body.message,'error');
        })
        
    }
    createZipFile(fileData) {
        if (!fileData || fileData.length === 0) {
            this.showNotification('Info', 'No files to download.', 'info');
            this.isLoading = false;
            return;
        }
        const zip = this.jsZip;
        // Add files to the ZIP
        fileData.forEach((file) => {
            try {
                const binaryData = this.base64ToUint8Array(file.body);
                zip.file(`${file.name}.${file.type}`, binaryData); // Add file to the ZIP
            } catch (error) {
                console.error('Error processing file:', error);
                this.showNotification('Info', error, 'info');
            }
        });

        // Generate the ZIP file
        zip.generateAsync({ type: 'blob' })
            .then((content) => {
                const element = document.createElement('a');
                element.href = URL.createObjectURL(content);
                element.download = `Templates_${new Date().toISOString().split('T')[0]}.zip`;
                document.body.appendChild(element);
                element.click();
                document.body.removeChild(element);

                this.showNotification('Success', 'Your download has started.', 'success');
            })
            .catch((error) => {
                this.showNotification('Error', 'Failed to generate ZIP file.', 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
    base64ToUint8Array(base64) {
        const binaryString = atob(base64);
        const length = binaryString.length;
        const bytes = new Uint8Array(length);
        for (let i = 0; i < length; i++) {
            bytes[i] = binaryString.charCodeAt(i);
        }
        return bytes;
    }
    showNotification(_title, _message, _variant) {
        const evt = new ShowToastEvent({
          title: _title,
          message: _message,
          variant: _variant,
        });
        this.dispatchEvent(evt);
      }
}