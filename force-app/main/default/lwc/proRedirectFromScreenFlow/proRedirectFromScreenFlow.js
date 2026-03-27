import { LightningElement, api } from "lwc";
export default class ProRedirectFromScreenFlow extends LightningElement {
  @api recordIdToRedirect;
  @api isLoading = false;

  connectedCallback() {
    this.isLoading = true;
    var new_url = window.location.origin + "/" + this.recordIdToRedirect;
    // alert(new_url);
    // window.location.assign(new_url);
    console.log("test");
    window.open(new_url, "_top"); // Forces navigation at the top-level frame
    // window.location.href = new_url;
    //window.location.reload(); // Forces a hard reload
    this.isLoading = false;
  }
  handleclick() {
    var new_url = window.location.origin + "/" + this.recordIdToRedirect;
    // alert(new_url);
    // window.location.assign(new_url);
    window.location.href = new_url;
    window.location.reload(); // Forces a hard reload
  }
}