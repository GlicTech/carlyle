import { LightningElement, wire, track } from "lwc";
import getAllRecordShares from "@salesforce/apex/Pro_RecordSharingReportController.getAllRecordShares";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { NavigationMixin } from "lightning/navigation";

export default class ProRecordSharingReport extends NavigationMixin(
  LightningElement
) {
  @track groupedList = [];
  @track searchKey = "";
  isLoading = true;

  @wire(getAllRecordShares)
  wiredShares({ data, error }) {
    this.isLoading = false;
    if (data) {
      const grouped = this.groupByObject(data);

      // Precompute safe keys and labels for each record and group
      this.groupedList = Object.keys(grouped).map((key) => ({
        key,
        label: `${key} Records (${grouped[key].length})`,
        records: grouped[key].map((r) => ({
          ...r,
          keyValue: `${r.RecordId}_${r.UserOrGroupId}`
        }))
      }));
    } else if (error) {
      this.showToast("Error", "Failed to load sharing data", "error");
    }
  }

  groupByObject(data) {
    const grouped = {};
    data.forEach((row) => {
      if (!grouped[row.ObjectType]) grouped[row.ObjectType] = [];
      grouped[row.ObjectType].push(row);
    });
    return grouped;
  }

  handleSearch(event) {
    this.searchKey = event.target.value.toLowerCase();
  }

  // filteredGroups is derived for display based on search input
  get filteredGroups() {
    if (!this.searchKey) return this.groupedList;

    return this.groupedList
      .map((group) => ({
        ...group,
        records: group.records.filter(
          (r) =>
            (r.RecordName &&
              r.RecordName.toLowerCase().includes(this.searchKey)) ||
            (r.UserOrGroupName &&
              r.UserOrGroupName.toLowerCase().includes(this.searchKey))
        )
      }))
      .filter((group) => group.records.length > 0);
  }

  navigateToRecord(event) {
    const recId = event.currentTarget.dataset.id;
    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: { recordId: recId, actionName: "view" }
    });
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}