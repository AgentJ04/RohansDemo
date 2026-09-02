import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getOverview from '@salesforce/apex/AccountEquipmentController.getOverview';

/**
 * Account Equipment Overview
 * Renders every piece of equipment on the account as a multi-column card:
 * Equipment Details | Accessories | Lease Details | Meter Readings | CSMA Details.
 * All displayed fields are controlled by the AR_* field sets (see the Apex controller).
 */
export default class AccountEquipmentOverview extends NavigationMixin(LightningElement) {
    @api recordId;

    data;
    error;
    isLoading = true;
    _expanded = {}; // equipmentId -> boolean (undefined = expanded by default)

    @wire(getOverview, { recordId: '$recordId' })
    wiredOverview({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.data = data;
            this.error = undefined;
            this.initExpanded();
        } else if (error) {
            this.error = this.reduceError(error);
            this.data = undefined;
        }
    }

    // First equipment section open, all subsequent ones collapsed.
    initExpanded() {
        const state = {};
        (this.data.equipment || []).forEach((eq, index) => {
            state[eq.id] = index === 0;
        });
        this._expanded = state;
    }

    get hasEquipment() {
        return this.data && this.data.equipment && this.data.equipment.length > 0;
    }

    // Decorate each equipment record with its collapse state for the template.
    get equipmentCards() {
        if (!this.hasEquipment) {
            return [];
        }
        return this.data.equipment.map((eq) => {
            const expanded = this._expanded[eq.id] === true;
            return {
                ...eq,
                expanded,
                toggleIcon: expanded ? 'utility:chevrondown' : 'utility:chevronright',
                toggleTitle: expanded ? 'Collapse' : 'Expand'
            };
        });
    }

    handleToggle(event) {
        const id = event.currentTarget.dataset.id;
        const current = this._expanded[id] === true;
        this._expanded = { ...this._expanded, [id]: !current };
    }

    handleExpandAll() {
        this.setAll(true);
    }

    handleCollapseAll() {
        this.setAll(false);
    }

    setAll(value) {
        const state = {};
        (this.data.equipment || []).forEach((eq) => {
            state[eq.id] = value;
        });
        this._expanded = state;
    }

    get showEmpty() {
        return this.data && !this.hasEquipment;
    }

    get equipmentBadgeLabel() {
        const count = this.data ? this.data.equipmentCount : 0;
        return `${count} ${count === 1 ? 'Equipment' : 'Equipment'}`;
    }

    get headerTitle() {
        if (!this.data) {
            return '';
        }
        const num = this.data.accountNumber || '';
        const addr = this.data.address || '';
        return addr ? `${num} - ${addr}` : num;
    }

    handleEquipmentNav(event) {
        const recordId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId,
                objectApiName: 'TSGADX__Equipment__c',
                actionName: 'view'
            }
        });
    }

    reduceError(error) {
        if (Array.isArray(error.body)) {
            return error.body.map((e) => e.message).join(', ');
        } else if (error.body && typeof error.body.message === 'string') {
            return error.body.message;
        }
        return 'Unknown error loading equipment.';
    }
}