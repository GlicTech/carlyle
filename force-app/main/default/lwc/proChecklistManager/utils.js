/**
 * Utility functions for proChecklistManager LWC.
 * Handles error reduction, date formatting, and completion calculations.
 */

const PHASE_PRE_CLOSING = 'Pre-Closing';
const PHASE_POST_CLOSING = 'Post-Closing';
const STATUS_COMPLETED = 'Completed';
const STATUS_OPEN = 'Open';
const STATUS_MOVED = 'Moved';
const NECESSARY_NO = 'No';

/**
 * Field configuration map for the completion dialog.
 * Maps field API names to their display properties.
 */
const COMPLETION_FIELD_CONFIG = {
    'pro_Yes_No__c': {
        label: 'Yes / No',
        type: 'combobox',
        options: [
            { label: 'Yes', value: 'Yes' },
            { label: 'No', value: 'No' }
        ],
        required: true
    },
    'pro_Key_Date__c': {
        label: 'Key Date',
        type: 'date',
        required: true
    },
    'pro_Provided_By__c': {
        label: 'Provided By',
        type: 'combobox',
        options: [
            { label: 'Operator', value: 'Operator' },
            { label: 'Carlyle', value: 'Carlyle' }
        ],
        required: true
    },
    'pro_Comment_Notes__c': {
        label: 'Comment / Notes',
        type: 'textarea',
        required: false
    }
};

/**
 * Reduces error payloads from wire adapters or imperative calls
 * into a flat array of user-friendly strings.
 */
function reduceErrors(errors) {
    if (!Array.isArray(errors)) {
        errors = [errors];
    }
    return errors
        .filter((e) => !!e)
        .map((e) => {
            if (typeof e === 'string') {
                return e;
            }
            if (e.body && typeof e.body.message === 'string') {
                return e.body.message;
            }
            if (e.message) {
                return e.message;
            }
            if (e.body && e.body.fieldErrors) {
                const fieldMessages = [];
                Object.values(e.body.fieldErrors).forEach((fieldArr) => {
                    fieldArr.forEach((fe) => fieldMessages.push(fe.message));
                });
                if (fieldMessages.length > 0) {
                    return fieldMessages.join('; ');
                }
            }
            if (e.body && e.body.pageErrors) {
                return e.body.pageErrors.map((pe) => pe.message).join('; ');
            }
            return 'Unknown error';
        })
        .reduce((acc, msg) => {
            if (acc.indexOf(msg) === -1) {
                acc.push(msg);
            }
            return acc;
        }, []);
}

/**
 * Formats an ISO date string or Date object into a localised display string.
 * Returns '--' for null/undefined values.
 */
function formatDate(dateValue) {
    if (!dateValue) {
        return '--';
    }
    try {
        const d = new Date(dateValue + 'T00:00:00');
        if (isNaN(d.getTime())) {
            return '--';
        }
        return d.toLocaleDateString('en-GB', {
            day: '2-digit',
            month: 'short',
            year: 'numeric'
        });
    } catch (e) {
        return '--';
    }
}

/**
 * Formats an ISO date string into DD/MM/YYYY format.
 * Returns empty string for null/undefined values.
 */
function formatDateDDMMYYYY(dateValue) {
    if (!dateValue) {
        return '';
    }
    try {
        const d = new Date(dateValue + 'T00:00:00');
        if (isNaN(d.getTime())) {
            return '';
        }
        const day = String(d.getDate()).padStart(2, '0');
        const month = String(d.getMonth() + 1).padStart(2, '0');
        const year = d.getFullYear();
        return day + '/' + month + '/' + year;
    } catch (e) {
        return '';
    }
}

/**
 * Checks whether a checklist item counts as "done" for progress calculations.
 * An item is done if status is Completed OR necessary is No.
 * STATUS_MOVED is intentionally excluded -- moved items are NOT done.
 */
function isItemDone(item) {
    return (
        item.pro_Status__c === STATUS_COMPLETED ||
        item.pro_Necessary__c === NECESSARY_NO
    );
}

/**
 * Calculates completion stats for a list of checklist items.
 * Excludes moved items from both numerator AND denominator.
 * Returns { completed, total, percentage }.
 */
function calculateCompletion(items) {
    const countable = items.filter(i =>
        i.pro_Status__c !== STATUS_MOVED && i.pro_Necessary__c !== NECESSARY_NO
    );
    const total = countable.length;
    if (total === 0) {
        return { completed: 0, total: 0, percentage: 0 };
    }
    const completed = countable.filter((item) => item.pro_Status__c === STATUS_COMPLETED).length;
    const percentage = Math.round((completed / total) * 100);
    return { completed, total, percentage };
}

/**
 * Determines if a checklist item is overdue.
 * Only Post-Closing items with a past due date that are not completed/unnecessary are overdue.
 */
function isOverdue(item) {
    if (item.pro_Phase__c !== PHASE_POST_CLOSING) {
        return false;
    }
    if (isItemDone(item)) {
        return false;
    }
    if (item.pro_Status__c === STATUS_MOVED) {
        return false;
    }
    if (!item.pro_Key_Date__c) {
        return false;
    }
    const dueDate = new Date(item.pro_Key_Date__c + 'T00:00:00');
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    return dueDate < today;
}

/**
 * Deep-clones an array of SObject records for local editing,
 * stripping Proxy wrappers from wire results.
 */
function cloneItems(items) {
    return items.map((item) => Object.assign({}, item));
}

export {
    PHASE_PRE_CLOSING,
    PHASE_POST_CLOSING,
    STATUS_COMPLETED,
    STATUS_OPEN,
    STATUS_MOVED,
    NECESSARY_NO,
    COMPLETION_FIELD_CONFIG,
    reduceErrors,
    formatDate,
    formatDateDDMMYYYY,
    isItemDone,
    calculateCompletion,
    isOverdue,
    cloneItems
};