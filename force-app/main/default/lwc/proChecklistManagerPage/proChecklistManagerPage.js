import { LightningElement, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';

export default class ProChecklistManagerPage extends LightningElement {
    recordId;

    @wire(CurrentPageReference)
    setPageRef(pageRef) {
        if (pageRef && pageRef.state && pageRef.state.c__recordId) {
            this.recordId = pageRef.state.c__recordId;
        }
    }

    get hasRecordId() {
        return !!this.recordId;
    }
}