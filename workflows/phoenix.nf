/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE INPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowPhoenix.initialise(params, log)

// TODO nf-core: Add all file path parameters for the pipeline to the list below
// Check input path parameters to see if they exist
def checkPathParamList = [ params.multiqc_config, params.fasta_href, params.bwa_index_href ]
for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CONFIG FILES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

ch_multiqc_config          = Channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
ch_multiqc_custom_config   = params.multiqc_config ? Channel.fromPath( params.multiqc_config, checkIfExists: true ) : Channel.empty()
ch_multiqc_logo            = params.multiqc_logo   ? Channel.fromPath( params.multiqc_logo, checkIfExists: true ) : Channel.empty()
ch_multiqc_custom_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { INPUT_CHECK } from '../subworkflows/local/input_check'
include { INPUT_CHECK_BAM } from '../subworkflows/local/input_check_bam'
include { UNPACK_BAM } from '../modules/local/unpack_bam'
include { ALIGNMENT } from '../subworkflows/local/alignment/main'
include { RESOLVE_PDX } from '../subworkflows/local/resolve_pdx/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { FASTQC                      } from '../modules/nf-core/fastqc/main'
include { MULTIQC                     } from '../modules/nf-core/multiqc/main'
include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/custom/dumpsoftwareversions/main'
include { TRIMGALORE } from '../modules/nf-core/trimgalore/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Info required for completion email and summary
def multiqc_report = []

workflow PHOENIX {

    ch_versions = Channel.empty()
    ch_fastqs_start = Channel.empty()

    //
    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    // TODO: Add INPUT_CHECK for ch_input_bam
    if (params.input) {
        ch_input = file(params.input)
        INPUT_CHECK (
            ch_input
        )
        ch_versions = ch_versions.mix(INPUT_CHECK.out.versions)
        ch_fastqs_start = INPUT_CHECK.out.reads
    }
    
    //
    // SUBWORKFLOW: If there are any input_bam files, unpack them first
    //
    if (params.input_bam) {
        ch_input_bam = file(params.input_bam)
        INPUT_CHECK_BAM (
            ch_input_bam
        )
        ch_versions = ch_versions.mix(INPUT_CHECK_BAM.out.versions)
        UNPACK_BAM (
            INPUT_CHECK_BAM.out.bams
        )
        ch_versions = ch_versions.mix(UNPACK_BAM.out.versions)
        ch_fastqs_start = ch_fastqs_start.mix(UNPACK_BAM.out.reads)
    }

    //
    // SUBWORKFLOW: TrimGalore if skip_trimming is false;
    //      skip_trimming is by default false, switched to true
    //      with command line argument --skip_trimming
    //
    ch_fastq_input = Channel.empty()    
    if (!params.skip_trimming) {
        TRIMGALORE(
            ch_fastqs_start
        )
        ch_fastq_input = TRIMGALORE.out.reads
        ch_versions = ch_versions.mix(TRIMGALORE.out.versions.first())
    }
    else {
        ch_fastq_input = ch_fastqs_start
    }

    ch_fastq_input
        .branch {
            meta, fastq ->
                ch_fastqs_for_disambiguate: meta.is_pdx
                    return tuple (meta, fastq)
                ch_fastq_input: true
                    return tuple (meta, fastq) 
        }.set { ch_fastqs_split }

    //
    // SUBWORKFLOW: Perform ALIGNMENT to Human Reference
    //     and Mouse Reference if reads are Xenograft
    //
    // Assumes bwa index and fasta fai files are made beforehand
    ch_bwa_index_href = channel.of([ [id:"bwa_index_directory_human"], file(params.bwa_index_href)]).collect()
    ch_fasta_href = channel.of([ [id:"reference_fasta_human"], file(params.fasta_href)]).collect()
    ch_fai_href = channel.of([ [id:"reference_fasta_fai_human"], file(params.fasta_href + ".fai")]).collect()
    ch_bwa_index_mref = channel.of([ [id:"bwa_index_directory_mouse"], file(params.bwa_index_mref)]).collect()
    ch_fasta_mref = channel.of([ [id:"reference_fasta_mouse"], file(params.fasta_mref)]).collect()
    ch_fai_mref = channel.of([ [id:"reference_fasta_fai_mouse"], file(params.fasta_mref + ".fai")]).collect()

    RESOLVE_PDX (
        ch_fastqs_split.ch_fastqs_for_disambiguate, 
        ch_fasta_href,
        ch_fai_href,
        ch_bwa_index_href,
        ch_fasta_mref,      // Mouse FASTA reference
        ch_fai_mref,        // Mouse FASTA FAI reference
        ch_bwa_index_mref   // Mouse BWA Index
    )
    ch_versions = ch_versions.mix(RESOLVE_PDX.out.versions)

    

    ALIGNMENT (
        ch_fastqs_split.ch_fastq_input, 
        ch_fasta_href,
        ch_fai_href,
        ch_bwa_index_href
    )
    ch_versions = ch_versions.mix(ALIGNMENT.out.versions)

    //
    // MODULE: Run FastQC
    //
    FASTQC (
        ch_fastq_input
    )
    ch_versions = ch_versions.mix(FASTQC.out.versions.first())

    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )

    //
    // MODULE: MultiQC
    //
    workflow_summary    = WorkflowPhoenix.paramsSummaryMultiqc(workflow, summary_params)
    ch_workflow_summary = Channel.value(workflow_summary)

    methods_description    = WorkflowPhoenix.methodsDescriptionText(workflow, ch_multiqc_custom_methods_description)
    ch_methods_description = Channel.value(methods_description)

    ch_multiqc_files = Channel.empty()
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml.collect())
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.zip.collect{it[1]}.ifEmpty([]))

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList()
    )
    multiqc_report = MULTIQC.out.report.toList()
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
    }
    NfcoreTemplate.summary(workflow, params, log)
    if (params.hook_url) {
        NfcoreTemplate.IM_notification(workflow, params, summary_params, projectDir, log)
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
