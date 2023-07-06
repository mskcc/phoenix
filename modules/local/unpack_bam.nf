process UNPACK_BAM {
    tag "$input_bam"
    label 'process_single'

    conda "bioconda::picard=3.0.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://mskcc/unpack_bam:0.1.0' :
        'docker.io/mskcc/unpack_bam:0.1.0' }"

    input:
    tuple val(meta), path(input_bam)

    output:
    tuple val(meta), path("${meta.id}/*.*")    , emit: fastqs
    path "versions.yml"                        , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script: // This script is bundled with the pipeline, in nf-core/phoenix/bin/
            // TODO: Move picard jar out or create a container with this tool's reqs
    """
    unpack_bam.pl \\
        --input-bam $input_bam \\
        --sample-id ${meta.id} \\
        --picard-jar /opt/common/CentOS_6-dev/picard/v2.13/picard.jar \\
        --output-dir ${meta.id}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        unpack_bam: 0.1.0 
    END_VERSIONS
    """
}