import { LightningElement, api, track, wire } from "lwc";
import { CloseActionScreenEvent } from "lightning/actions";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { refreshApex } from "@salesforce/apex";

import shareRecord from "@salesforce/apex/Pro_RecordSharingController.shareRecord";
import searchUsersAndGroups from "@salesforce/apex/Pro_RecordSharingController.searchUsersAndGroups";
import getExistingShares from "@salesforce/apex/Pro_RecordSharingController.getExistingShares";
import revokeRecordShare from "@salesforce/apex/Pro_RecordSharingController.revokeRecordShare";

export default class ProRecordSharing extends LightningElement {
  @api recordId;

  @track searchKey = "";
  @track results = [];
  @track selectedUsers = [];
  @track accessLevel = "Read";
  @track existingShares = [];

  // hold wired value so we can refresh after Save
  wiredSharesResult;

  // load existing shares reactively when recordId is ready
  @wire(getExistingShares, { recordId: "$recordId" })
  wiredShares(value) {
    this.wiredSharesResult = value;
    const { data, error } = value || {};
    if (data) {
      this.existingShares = data.map((s) => ({
        ...s,
        displayLabel: `${s.Name} — ${s.AccessLevel}`
      }));
    } else if (error) {
      this.existingShares = [];
      this.showToast(
        "Error loading shares",
        (error.body && error.body.message) || "Unknown error",
        "error"
      );
    }
  }

  get accessOptions() {
    return [{ label: "Read Only", value: "Read" }];
  }
  get hasResults() {
    return this.results && this.results.length > 0;
  }
  get comboboxClass() {
    return `slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click ${this.hasResults ? "slds-is-open" : ""}`;
  }
  get hasExistingShares() {
    return Array.isArray(this.existingShares) && this.existingShares.length > 0;
  }
  get hasSelectedUsers() {
    return Array.isArray(this.selectedUsers) && this.selectedUsers.length > 0;
  }

  // Search
  handleKeyChange(event) {
    this.searchKey = event.target.value;
    if (this.searchKey && this.searchKey.length > 2) {
      searchUsersAndGroups({ searchKey: this.searchKey })
        .then((data) => {
          this.results = (data || []).map((r) => ({
            ...r,
            iconName: r.Type === "User" ? "standard:user" : "standard:groups"
          }));
        })
        .catch(() => {
          this.results = [];
        });
    } else {
      this.results = [];
    }
  }

  // Select from dropdown
  handleSelect(event) {
    const recordId = event.currentTarget.dataset.id;
    const recordName = event.currentTarget.dataset.name;
    if (!this.selectedUsers.find((u) => u.Id === recordId)) {
      this.selectedUsers = [
        ...this.selectedUsers,
        {
          Id: recordId,
          Name: recordName,
          iconName: "standard:user",
          Type: "User"
        }
      ];
    }
    this.searchKey = "";
    this.results = [];
  }

  // Remove pill
  handleRemove(event) {
    const recordId = event.detail.name;
    this.selectedUsers = this.selectedUsers.filter((u) => u.Id !== recordId);
  }

  handleAccessChange(event) {
    this.accessLevel = event.detail.value;
  }
  handleCancel() {
    this.dispatchEvent(new CloseActionScreenEvent());
  }

  handleSave() {
    if (!this.selectedUsers.length) {
      this.showToast(
        "Error",
        "Please select at least one External Rep.",
        "error"
      );
      return;
    }

    Promise.all(
      this.selectedUsers.map((u) =>
        shareRecord({
          recordId: this.recordId,
          userOrGroupId: u.Id,
          accessLevel: this.accessLevel
        })
      )
    )
      .then(() => {
        this.showToast("Success", "Record shared successfully.", "success");
        this.selectedUsers = [];
        this.searchKey = "";
        return refreshApex(this.wiredSharesResult);
      })
      .catch((error) => {
        this.showToast(
          "Error sharing record",
          (error.body && error.body.message) || "Unknown error",
          "error"
        );
      });
  }

  handleExistingRemove(event) {
    const userOrGroupId = event.detail.name;
    revokeRecordShare({ recordId: this.recordId, userOrGroupId })
      .then(() => {
        this.existingShares = this.existingShares.filter(
          (s) => s.Id !== userOrGroupId
        );
        this.showToast(
          "Access revoked",
          "Sharing removed successfully.",
          "success"
        );
        return refreshApex(this.wiredSharesResult);
      })
      .catch((error) => {
        this.showToast(
          "Error revoking access",
          (error?.body && error.body.message) || "Unknown error",
          "error"
        );
      });
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}