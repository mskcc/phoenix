

include { PICARD_MERGESAMFILES } from '../../../modules/nf-core/picard/mergesamfiles/main'
include { FASTQ_ALIGN_BWA } from '../../nf-core/fastq_align_bwa/main'
include { BAM_MARKDUPLICATES_PICARD } from '../../nf-core/bam_markduplicates_picard/main'

workflow ALIGNMENT {

    take:
    ch_fastq_input
    ch_fasta
    ch_fai
    ch_bwa_index

    main:
    // TODO: Make it so bwa_index is generated if params.bwa_index is not provided?
    // TODO: Better handling of fai and fasta files?
    //    Both TODOs handled in https://github.com/nf-core/atacseq/blob/master/subworkflows/local/prepare_genome.nf
    ch_versions = Channel.empty()

    FASTQ_ALIGN_BWA(
        ch_fastq_input,
        ch_bwa_index,
        true,  // sort bam
        ch_fasta
    )
    ch_versions = ch_versions.mix(FASTQ_ALIGN_BWA.out.versions.first())

    //
    // SUBWORKFLOW: Run MarkDuplicates on bam
    //
    BAM_MARKDUPLICATES_PICARD (
        FASTQ_ALIGN_BWA.out.bam,
        ch_fasta,
        ch_fai
    )
    ch_versions = ch_versions.mix(BAM_MARKDUPLICATES_PICARD.out.versions.first())

    emit:
    bam = BAM_MARKDUPLICATES_PICARD.out.bam
    bai = BAM_MARKDUPLICATES_PICARD.out.bai

    versions = ch_versions
}