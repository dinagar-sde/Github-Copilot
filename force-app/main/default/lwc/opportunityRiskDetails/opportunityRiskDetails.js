import { LightningElement, api, wire } from 'lwc';
import { getFieldValue, getRecord } from 'lightning/uiRecordApi';
import RISK_SCORE from '@salesforce/schema/Opportunity.Risk_Score__c';
import RISK_LEVEL from '@salesforce/schema/Opportunity.Risk_Level__c';
import STAGE_LAST_CHANGED from '@salesforce/schema/Opportunity.Stage_Last_Changed_Date__c';
import HIGH_RISK_SINCE from '@salesforce/schema/Opportunity.High_Risk_Since__c';
import LAST_ESCALATION_DATE from '@salesforce/schema/Opportunity.Last_Risk_Escalation_Date__c';

const FIELDS = [RISK_SCORE, RISK_LEVEL, STAGE_LAST_CHANGED, HIGH_RISK_SINCE, LAST_ESCALATION_DATE];

export default class OpportunityRiskDetails extends LightningElement {
    @api recordId;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    opportunity;

    get riskScore() {
        return getFieldValue(this.opportunity.data, RISK_SCORE) ?? 0;
    }

    get riskLevel() {
        return getFieldValue(this.opportunity.data, RISK_LEVEL) || 'Low';
    }

    get riskLevelClass() {
        return `risk-level risk-level_${this.riskLevel.toLowerCase()}`;
    }

    get stageLastChanged() {
        return getFieldValue(this.opportunity.data, STAGE_LAST_CHANGED);
    }

    get highRiskSince() {
        return getFieldValue(this.opportunity.data, HIGH_RISK_SINCE);
    }

    get lastEscalationDate() {
        return getFieldValue(this.opportunity.data, LAST_ESCALATION_DATE);
    }
}