import { LightningElement, api } from 'lwc';

/**
 * Renders a single field-set cell as "Label: value", formatting the value
 * according to its Apex-provided type (currency, date, number, boolean, ...).
 * Kept intentionally dumb so the parent stays field-set driven.
 */
export default class ArFieldCell extends LightningElement {
    @api field; // { label, name, type, value }

    get hasValue() {
        return this.field && this.field.value !== null && this.field.value !== undefined && this.field.value !== '';
    }

    get isEmpty() {
        return !this.hasValue;
    }

    get isCurrency() {
        return this.field.type === 'currency';
    }
    get isPercent() {
        return this.field.type === 'percent';
    }
    get isNumber() {
        return this.field.type === 'number';
    }
    get isDate() {
        return this.field.type === 'date';
    }
    get isDatetime() {
        return this.field.type === 'datetime';
    }
    get isBoolean() {
        return this.field.type === 'boolean';
    }
    get isText() {
        return !this.isCurrency && !this.isPercent && !this.isNumber && !this.isDate && !this.isDatetime && !this.isBoolean;
    }

    // lightning-formatted-number expects a fraction (0.05 => 5%). Salesforce
    // percent fields store the whole number (5), so divide for display.
    get percentValue() {
        const n = Number(this.field.value);
        return Number.isNaN(n) ? null : n / 100;
    }

    get booleanValue() {
        return this.field.value === true || this.field.value === 'true';
    }
}