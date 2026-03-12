import { LightningElement, api, track } from 'lwc';
import getAvailableTemplates from '@salesforce/apex/Pro_TemplateMappingController.getAvailableTemplates';
import getFieldMappings from '@salesforce/apex/Pro_TemplateMappingController.getFieldMappings';

export default class ProTemplatePropertyEditor extends LightningElement {
    @track templateOptions = [];
    @track selectedTemplate;
    @track fieldMappings = [];
@track templateLabel;
    @api inputVariables = [];

    connectedCallback() {
        getAvailableTemplates()
            .then((result) => {
                this.templateOptions = result;
                const templateVar = this.inputVariables.find(v => v.name === 'integrationConfigJson');
                if (templateVar && templateVar.value) {
                       try {
            const parsed = JSON.parse(templateVar.value);
            const templateLabel = parsed.template;
            const matched = this.templateOptions.find(opt => opt.label === templateLabel);

            if (matched) {
                this.selectedTemplate = matched.value;      // DeveloperName
                this.templateLabel = matched.label;         // MasterLabel
            }

            this.fieldMappings = parsed.fields || [];
        } catch (e) {
            console.error('Failed to parse input', e);
        }
                }
                if (this.selectedTemplate) {
                    this.loadFields(this.selectedTemplate);
                }
            });
    }

    handleTemplateChange(event) {
        this.selectedTemplate = event.detail.value;
        this.loadFields(this.selectedTemplate);
         const selected = this.templateOptions.find(t => t.value === this.selectedTemplate);
    if (selected) {
        this.templateLabel = selected.label;
    }
    }

    loadFields(templateDevName) {
        getFieldMappings({ templateDevName })
            .then(result => {
                this.fieldMappings = result.map(field => {
                    const existing = this.fieldMappings.find(f => f.destinationField === field.destinationField);
                    return { ...field, value: existing ? existing.value : '' };
                });
                this.emitConfigChange();
            });
    }

    handleInputChange(event) {
        const fieldName = event.target.dataset.field;
        console.log(fieldName);
        const value = event.target.value;
        this.fieldMappings = this.fieldMappings.map(field => {
            if (field.destinationField === fieldName) {
                return { ...field, value };
            }
            return field;
        });
        console
        this.emitConfigChange();
    }

    emitConfigChange() {
        const config = {
            template: this.templateLabel,
            fields: this.fieldMappings.map(f => ({
                destinationField: f.destinationField,dataType: f.dataType,isCustomField: f.isCustomField,
                value: f.value
            }))
        };
console.log('1'+config);
        this.dispatchEvent(new CustomEvent('configuration_editor_input_value_changed', {
            bubbles: true,
            composed: true,
            detail: {
                name: 'integrationConfigJson',
                newValue: JSON.stringify(config),
                newValueDataType: 'String'
            }
        }));
    }
}