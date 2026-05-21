import { LightningElement, api, track } from 'lwc';
import getDocumentInfo from '@salesforce/apex/WSM_DocConverterService.getDocumentInfo';
import validateIntegrationAccess from '@salesforce/apex/WSM_DocConverterService.validateIntegrationAccess';

export default class WsmDocConverter extends LightningElement {
    // Flow Screen Inputs
    @api contentDocumentIds;
    @api recordId;
    @api apiKey;
    @api endpointUrl;
    @api sfClientId;
    @api sfClientSecret;
    @api hideDeleteOriginals = false;

    // Flow Screen Outputs
    @api orderedContentDocumentIds = [];
    @api outputFileName = 'Converted Documents.pdf';
    @api mergeFiles = false;
    @api uploadIndividual = false;
    @api deleteOriginals = false;

    // Internal State
    @track documents = [];
    isLoading = true;
    errorMessage = '';
    accessWarning = '';
    editableFileName = 'Converted Documents.pdf';
    _mergeFiles = true;
    _uploadIndividual = false;
    _deleteOriginals = false;

    async connectedCallback() {
        this.editableFileName = this.outputFileName || 'Converted Documents.pdf';
        this._mergeFiles = true;
        this._uploadIndividual = this.uploadIndividual === true;

        if (this.contentDocumentIds && this.contentDocumentIds.length) {
            await this._loadDocuments([...this.contentDocumentIds]);
        } else {
            this.isLoading = false;
        }
    }

    // --- Document Loading ---
    async _loadDocuments(ids) {
        try {
            const infos = await getDocumentInfo({ contentDocumentIds: ids });
            this.documents = infos.map((info, index) => ({
                ...info,
                position: index + 1,
                isFirst: index === 0,
                isLast: index === infos.length - 1,
                isPdf: (info.fileType || '').toUpperCase() === 'PDF',
                typeLabel: (info.fileType || '').toUpperCase() === 'PDF'
                    ? 'PDF'
                    : (info.fileExtension || info.fileType || 'Unknown').toUpperCase() + ' → PDF',
                formattedSize: this._formatSize(info.contentSize)
            }));
            this._syncOutputs();
            this._validateAccess(ids);
        } catch (error) {
            this.errorMessage = this._extractError(error);
        } finally {
            this.isLoading = false;
        }
    }

    async _validateAccess(ids) {
        try {
            const warning = await validateIntegrationAccess({
                sfClientId: this.sfClientId,
                sfClientSecret: this.sfClientSecret,
                contentDocumentIds: ids
            });
            if (warning) {
                this.accessWarning = warning;
            }
        } catch (error) {
            this.accessWarning = 'Unable to verify integration access: ' + this._extractError(error);
        }
    }

    // --- Getters ---
    get hasDocuments() { return this.documents.length > 0; }
    get isEmpty() { return this.documents.length === 0 && !this.isLoading; }
    get documentCountLabel() {
        return `${this.documents.length} file${this.documents.length !== 1 ? 's' : ''}`;
    }
    get showMergeOptions() { return this.documents.length > 1; }
    get showUploadIndividualOption() { return this._mergeFiles && this.documents.length > 1; }
    get showDeleteOption() { return this.hideDeleteOriginals !== true; }

    // --- Reorder Handlers ---
    handleMoveUp(event) {
        const idx = parseInt(event.currentTarget.dataset.index, 10);
        if (idx <= 0) return;
        const docs = [...this.documents];
        [docs[idx - 1], docs[idx]] = [docs[idx], docs[idx - 1]];
        this.documents = docs;
        this._refreshPositions();
        this._syncOutputs();
    }

    handleMoveDown(event) {
        const idx = parseInt(event.currentTarget.dataset.index, 10);
        if (idx >= this.documents.length - 1) return;
        const docs = [...this.documents];
        [docs[idx], docs[idx + 1]] = [docs[idx + 1], docs[idx]];
        this.documents = docs;
        this._refreshPositions();
        this._syncOutputs();
    }

    handleRemoveDocument(event) {
        const idx = parseInt(event.currentTarget.dataset.index, 10);
        this.documents = this.documents.filter((_, i) => i !== idx);
        this._refreshPositions();
        this._syncOutputs();
    }

    // --- Option Handlers ---
    handleFileNameChange(event) {
        this.editableFileName = event.target.value;
        this._syncOutputs();
    }

    handleMergeChange(event) {
        this._mergeFiles = event.target.checked;
        if (!this._mergeFiles) {
            this._uploadIndividual = false;
        }
        this._syncOutputs();
    }

    handleUploadIndividualChange(event) {
        this._uploadIndividual = event.target.checked;
        this._syncOutputs();
    }

    handleDeleteOriginalsChange(event) {
        this._deleteOriginals = event.target.checked;
        this._syncOutputs();
    }

    // --- Output Sync ---
    _syncOutputs() {
        this.orderedContentDocumentIds = this.documents.map(d => d.contentDocumentId);

        let name = (this.editableFileName || '').trim();
        if (!name) name = 'Converted Documents.pdf';
        if (!name.toLowerCase().endsWith('.pdf')) name += '.pdf';
        this.outputFileName = name;

        this.mergeFiles = this._mergeFiles;
        this.uploadIndividual = this._uploadIndividual;
        this.deleteOriginals = this._deleteOriginals;
    }

    // --- Helpers ---
    _refreshPositions() {
        const len = this.documents.length;
        this.documents = this.documents.map((doc, i) => ({
            ...doc,
            position: i + 1,
            isFirst: i === 0,
            isLast: i === len - 1
        }));
    }

    _formatSize(bytes) {
        if (!bytes || bytes === 0) return '0 B';
        if (bytes < 1024) return bytes + ' B';
        if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
        return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
    }

    _extractError(error) {
        if (!error) return 'Unknown error';
        if (typeof error === 'string') return error;
        if (error.body && error.body.message) return error.body.message;
        if (error.message) return error.message;
        return JSON.stringify(error);
    }
}