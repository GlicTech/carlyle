/**
* @description : This Component is to calculate and generate interest invoices across multiple leases, displaying results per lease.
 
* @author : abhishek.qa@lease-works.com.sndboxfull
* @group : 
* @last modified on : 25-07-2024
* @ last modified by : Anand Agrawal
**/
import { LightningElement, wire } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import InterestInvoiceCalculatorStyle from "@salesforce/resourceUrl/InterestInvoiceCalculatorStyle";
import getLesseeRecords from '@salesforce/apex/InterestInvoiceCalculatorController.getLesseeRecords';
import refreshTransactions from '@salesforce/apex/InterestInvoiceCalculatorController.refreshTransactions';
import { getPicklistValues } from 'lightning/uiObjectInfoApi';
import TYPE_FIELD from '@salesforce/schema/leaseworks__Invoice__c.leaseworks__Invoice_Type__c';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getSetupRecord from '@salesforce/apex/InterestInvoiceCalculatorController.getSetupRecord';

export default class InterestInvoiceCalculator extends LightningElement {

	isSpinner = false;
	isLoading = false;
	openLesseeModal = false;
	openInvoiceTypeModal = false;
	openCalculationValuesModal = false;
	allLeseeChecked = true;
	allInvoiceChecked = true;

	selectedLessee = 'All Selected';
	selectedInvoiceTypes = 'All Selected';
	invoicedateValue ;
	invoiceduedateValue;

	selectedLessees = [];
	selectedInvoiceType = [];
	lesseeRecords = [];
	invoiceTypes = [];
	invoiceTypePicklistValues = [];
 
	initialLesseeLength;	
	monthsValue = [
			'January', 'February', 'March', 'April', 'May', 'June',
			'July', 'August', 'September', 'October', 'November', 'December'
	];

	get monthNameList() {
		// Array of month names
		const months = [
			'January', 'February', 'March', 'April', 'May', 'June',
			'July', 'August', 'September', 'October', 'November', 'December'
		];
		return months.map(month => ({
			label: month,
			value: month
		}));
	}

	// Array of Years
	get yearList() {
		const startYear = 2020;
		const endYear = 2035;
		const years = [];
		for (let year = startYear; year <= endYear; year++) {
			years.push({ label: year.toString(), value: year.toString() });
		}
		return years;
	}

	//For using Lessee Length multiple times 
	get lesseeRecordsLength() {
		return this.lesseeRecords.length;
	}

	//For getting selected records on top 
	get lesseeRecordsSorted() {
		let checkedLessee = this.lesseeRecords.filter(item => item.isChecked);
		let uncheckedLessee = this.lesseeRecords.filter(item => !item.isChecked);
		return [...checkedLessee, ...uncheckedLessee];
	}

	setupRecords;
	showErrorwhenMissingSetup = true;

    @wire(getSetupRecord)
    setupRecords({ error, data }) {
        if (data){
            this.setupRecords = data;
			this.showErrorwhenMissingSetup = false;
        }else{
			this.showToast('Warning', 'The default parameters for interest calculation are missing for your organization. Please contact your IT department or reach out to LW Support to add the missing custom metadata.', 'warning', 'sticky');
            this.showErrorwhenMissingSetup = true;
        }
    }

	@wire(getPicklistValues, { recordTypeId: '012000000000000AAA', fieldApiName: TYPE_FIELD })
		wiredPicklistValues({ error, data }) {
		if (data) {
			this.invoiceTypes = JSON.parse(JSON.stringify(data.values));
			this.invoiceTypes.forEach(ele => {
				ele.isChecked = true;
				this.selectedInvoiceType.push(ele.label);
			});
			this.invoiceTypePicklistValues = this.invoiceTypes.filter(value => {
				return value.label === 'Rent' || 
					value.label === 'Security Deposit' || 
					value.label === 'Aircraft MR' ||
					value.label === 'Other' || 
					value.label === 'Finance Lease' || 
					value.label === 'Default Interest';
			});
			
		}else if (error) {
		}
	}

	connectedCallback() {
		this.getRecord('', true);
		let currentDate = new Date();
		let currentyear = currentDate.getFullYear();
		this.yearValue = currentyear.toString();
		this.monthValue = this.monthsValue[parseInt(currentDate.getMonth() - 1)];
		this.invoicedateValue = currentDate.toISOString().substring(0, 10);
		let futureDate = new Date(currentDate);
        futureDate.setDate(currentDate.getDate() + 30);
		this.invoiceduedateValue = futureDate.toISOString().substring(0, 10);
	}

	renderedCallback() {
		Promise.all([
			loadStyle(this, InterestInvoiceCalculatorStyle)
		])
	}

	//For getting the Invoice Date
	handleInvoiceDateChangeEvent(event) {
		this.invoicedateValue = event.target.value;
		let futureDate = new Date(this.invoicedateValue);
        futureDate.setDate(futureDate.getDate() + 30);
		this.invoiceduedateValue = futureDate.toISOString().substring(0, 10);
	}

	//For getting Lessee Records
	async getRecord(searchValue, isFirstTimeFlag) {
		this.isLoading = true;
		try {
			const result = await getLesseeRecords({ searchKey: searchValue });
			this.lesseeRecords = JSON.parse(JSON.stringify(result));
			this.initialLesseeLength = isFirstTimeFlag ? this.lesseeRecords.length : 0;
			this.allLeseeChecked = this.selectedLessees.length > 0;
			let isAnyLesseeCheck = false;
			this.lesseeRecords.forEach(currentItem => {
				if (isFirstTimeFlag) {
					this.selectedLessees.push(currentItem.Id);
					currentItem.isChecked = this.allLeseeChecked = true;
				} else {
					currentItem.isChecked = this.selectedLessees.includes(currentItem.Id);
					if (currentItem.isChecked && !this.selectedLessees.includes(currentItem.Id)) {
						this.allLeseeChecked = false;
					}
				}
				if (currentItem.isChecked) {
					isAnyLesseeCheck = true;
				}
			});
			if (this.lesseeRecordsLength > this.selectedLessees.length || !isAnyLesseeCheck) {
				this.allLeseeChecked = false;
			}

		} catch (error) {
			console.error('Error fetching lessee records:' + error);
		}
		this.isLoading = false;
	}

	async handleCalculateInterest() {
		try {
			if(this.template.querySelector('.invoiceType').value == '0 Selected'){
				this.showToast('Error', 'Please select Invoice Type.', 'error' , 'dismissible');
			}else if(this.template.querySelector('.lesses').value == '0 Selected'){
				this.showToast('Error', 'Please select Lessees.', 'error', 'dismissible');
			}
			else{
				this.isSpinner = true;
				const result = await refreshTransactions({
					selectedLesseIdList: this.selectedLessees,
					selectedInvoiceTypeLabelList: this.selectedInvoiceType,
					month: this.monthValue,
					year: this.yearValue
				});
				if(result === 'Success'){
				this.isSpinner = false;
				this.showToast('Success', 'The interest calculation request has been successfully submitted. You will receive a notification once processing is complete. Please check your email for updates.', 'success');
				}else{
				this.isSpinner = false;
					this.showToast('Error', 'Interest calculation is in progress. Please wait for the current process to complete before starting a new calculation.', 'error');
				}
			}
		} catch (error) {
			console.error('Error checking batch status:', error);
		}
	}

	//For getting the month and year values from UI
	handleMonthYearChange(event) {
		const { name, value } = event.target;
		if (name === 'monthPicker') {
			this.monthValue = value;
		} else if (name === 'yearPicker') {
			this.yearValue = value;
		}
	}

	//For Showing Invoice Modal
	handleShowInvoice() {
		this.openInvoiceTypeModal = !this.openInvoiceTypeModal;
	}

	//For closing Invoice Modal
	handleCloseInvoiceModal() {
		this.openInvoiceTypeModal = false;
	}

	//For Showing Lessee Modal
	handleShowLessee() {
		this.openLesseeModal = !this.openLesseeModal;
	}

	//For closing Lessee Modal
	handleCloseLesseeModal() {
		this.openLesseeModal = false;
	}

	handleShowCalculationValues() {
		this.openCalculationValuesModal = !this.openCalculationValuesModal;
	}

	handleCloseCalculationValues() {
		this.openCalculationValuesModal = false;
	}

	//For getting the updated values from search box on Lessee Modal
	handleSearchKeyword(event) {
		this.getRecord(event.target.value, false);
	}

	//For selecting all Lessees
	handleSelectAllLessee(event) {
		this.allLeseeChecked = event.target.checked;
		this.selectedLessees = [];
		this.lesseeRecords.forEach(record => {
			record.isChecked = this.allLeseeChecked;
			if (this.allLeseeChecked) {
				this.selectedLessees.push(record.Id);
			}
		});
	}

	//For select and manage single lessee 
	handleOptionLesseeChange(event) {
		const dataId = event.target.dataset.id;
		const childChecked = event.target.checked;
		let count = 0;
		if (!childChecked && this.selectedLessees.includes(dataId) && this.selectedLessees.indexOf(dataId) > -1) {
			this.selectedLessees.splice(this.selectedLessees.indexOf(dataId), 1);
		}
		this.lesseeRecords.forEach(ele => {
			if (ele.Id == dataId) {
				ele.isChecked = childChecked;
			}
			if (ele.isChecked) {
				count++;
				if (!this.selectedLessees.includes(ele.Id)) {
					this.selectedLessees.push(ele.Id);
				}
			}
		});
		this.allLeseeChecked = this.lesseeRecordsLength == count;
	}

	//For save data from lessee modal
	handleSaveLesseeModal() {
		let selectedLesseeLength = this.selectedLessees.length;
		if (selectedLesseeLength !== this.initialLesseeLength) {
			this.selectedLessee = `${selectedLesseeLength} Selected`;
		}
		this.openLesseeModal = false;
		this.getRecord('');
	}

	//For selecting all Invoice types
	handleSelectAllInvoice(event) {
		this.allInvoiceChecked = event.target.checked;
		this.invoiceTypePicklistValues.forEach(ele => {
			ele.isChecked = this.allInvoiceChecked;
		});
	}

	//For select and manage single Invoice Type
	handleOptionInvoiceChange(event) {
		const dataLabel = event.target.dataset.label;
		const childInvChecked = event.target.checked;
		let count = 0;

		this.invoiceTypePicklistValues.forEach(ele => {
			if (ele.label === dataLabel) {
				ele.isChecked = childInvChecked;
			}
			if (ele.isChecked) {
				count++;
			}
		});

		this.allInvoiceChecked = count === this.invoiceTypePicklistValues.length;
	}

	//For save data from invoice type modal
	saveInvoiceModal() {
		this.selectedInvoiceType = [];
		this.invoiceTypePicklistValues.forEach(ele => {
			if (ele.isChecked) {
				this.selectedInvoiceType.push(ele.label);
			}
		});

		let checkedRecordsLength = this.selectedInvoiceType.length;
		if (checkedRecordsLength !== this.invoiceTypePicklistValues.length) {
			this.selectedType = this.selectedInvoiceType;
		}
		this.selectedInvoiceTypes = checkedRecordsLength + ' Selected';
		this.openInvoiceTypeModal = false;
	}

	//For refreshing on click of reset button
	onReset() {
		window.location.reload();
	}

	//For Showing toast Message or Error
	showToast(title, message, variant, mode) {
		const event = new ShowToastEvent({
			title: title,
			message: message,
			variant: variant,
			mode : mode
		});
		this.dispatchEvent(event);
	}

}