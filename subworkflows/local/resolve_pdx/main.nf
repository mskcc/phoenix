//
// Perform two alignments - once against mouse, another against human - and
//    run ngs_disambiguate; return only reads from Human
//


include { NGS_DISAMBIGUATE } from '../../../modules/local/disambiguate/main'
include { ALIGNMENT as ALIGNMENT_HUMAN } from '../alignment/main'
include { ALIGNMENT as ALIGNMENT_MOUSE } from '../alignment/main'

workflow RESOLVE_PDX {

    take:
    ch_fastq_input
    ch_fasta_href
    ch_fai_href
    ch_bwa_index_href

    ch_fasta_mref
    ch_fai_mref
    ch_bwa_index_mref

    main:
    ch_versions = Channel.empty()

    ALIGNMENT_HUMAN (
        ch_fastq_input, 
        ch_fasta_href,
        ch_fai_href,
        ch_bwa_index_href
    )
    ch_versions = ch_versions.mix(ALIGNMENT_HUMAN.out.versions)

    ALIGNMENT_MOUSE (
        ch_fastq_input, 
        ch_fasta_mref,
        ch_fai_mref,
        ch_bwa_index_mref
    )
    ch_versions = ch_versions.mix(ALIGNMENT_MOUSE.out.versions) 

    NGS_DISAMBIGUATE (
        ALIGNMENT_HUMAN.out.bam,
        ALIGNMENT_MOUSE.out.bam,
    )
    ch_versions = ch_versions.mix(NGS_DISAMBIGUATE.out.versions)

    emit:
    bam_a = NGS_DISAMBIGUATE.out.bam_disambiguated_a
    bam_b = NGS_DISAMBIGUATE.out.bam_disambiguated_b
    summary = NGS_DISAMBIGUATE.out.summary

    versions = ch_versions                       // channel: [ versions.yml ]
}
