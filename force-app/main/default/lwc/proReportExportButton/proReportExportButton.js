// proReportExportButton.js
import { LightningElement, api } from 'lwc';
//import exportCsv from '@salesforce/apex/ProReportExportService.exportCsv';

export default class proReportExportButton extends LightningElement {
  @api configDevName; 
  downloading = false;

  async handleClick() {
    try {
      this.downloading = true;
      const res = await exportCsv({ configDevName: this.configDevName });

      // Build a Blob and trigger download in browser
      const byteChars = atob(res.base64Csv);
      const byteNumbers = new Array(byteChars.length);
      for (let i = 0; i < byteChars.length; i++) byteNumbers[i] = byteChars.charCodeAt(i);
      const blob = new Blob([new Uint8Array(byteNumbers)], { type: 'text/csv;charset=utf-8;' });

      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = res.fileName || 'export.csv';
      document.body.appendChild(a);
      a.click();
      a.remove();
      URL.revokeObjectURL(url);

      this.dispatchEvent(new CustomEvent('done', { detail: { rowCount: res.rowCount, columns: res.columns } }));
    } catch (e) {
      console.error(e);
      this.dispatchEvent(new CustomEvent('error', { detail: e?.body?.message || e.message }));
    } finally {
      this.downloading = false;
    }
  }

  get label() {
  return this.downloading ? 'Preparing CSV…' : 'Download CSV';
}
}