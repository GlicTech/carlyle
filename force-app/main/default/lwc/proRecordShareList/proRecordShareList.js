import { LightningElement, api, wire, track } from 'lwc';
import getExistingShares from '@salesforce/apex/Pro_RecordSharingController.getExistingShares';
import revokeRecordShare from '@salesforce/apex/Pro_RecordSharingController.revokeRecordShare';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

export default class ProRecordShareList extends LightningElement {
    @api recordId;
    @track shares = [];
    wiredResult;
    isLoading = true;

    @wire(getExistingShares, { recordId: '$recordId' })
    wiredShares(value) {
        this.wiredResult = value;
        const { data, error } = value;
        this.isLoading = false;

        if (data) {
            this.shares = data.map(s => ({
                id: s.Id,
                name: s.Name,
                access: s.AccessLevel,
                icon: 'standard:user'
            }));
        } else if (error) {
            this.showToast('Error', error.body?.message || 'Unable to load shares', 'error');
        }
    }

    async handleRevoke(event) {
        const userId = event.target.dataset.id;
        this.isLoading = true;

        try {
            await revokeRecordShare({ recordId: this.recordId, userOrGroupId: userId });
            this.showToast('Access Revoked', 'User access removed successfully.', 'success');
            await refreshApex(this.wiredResult);
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to revoke access', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    get hasShares() {
        return this.shares && this.shares.length > 0;
    }
}