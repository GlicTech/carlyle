import { api } from 'lwc';
import LightningModal from 'lightning/modal';

export default class ProChecklistManagerModal extends LightningModal {
    @api recordId;
}