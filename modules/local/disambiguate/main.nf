process NGS_DISAMBIGUATE {
    tag "$meta.id"
    label 'process_high'

    conda "bioconda::ngs-disambiguate=2016.11.10-0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'mskcc/disambiguate:1.0.0' :
        'quay.io/biocontainers/ngs-disambiguate:2016.11.10--0' }"

    input:
    tuple val(meta), path(bam_a) // human
    tuple val(meta), path(bam_b) // mouse

    output:
    tuple val(meta), path("$outputdir/*.disambiguatedSpeciesA.bam")  , emit: bam_disambiguated_a
    tuple val(meta), path("$outputdir/*.disambiguatedSpeciesA.bam")  , emit: bam_disambiguated_b
    tuple val(meta), path("$outputdir/*_summary.txt")                , emit: summary
    path "versions.yml"                                              , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    outputdir = ${prefix}_disambiguated
    """
    ngs_disambiguate --prefix ${prefix} \\
        ${args} \\
        --output-dir $outputdir \\
        --aligner bwa \\
        $bam_a \\
        $bam_b

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ngs_disambiguate: \$(echo \$(ngs_disambiguate --version)
        bwa: \$(bwa --version)
    END_VERSIONS
    """
}
