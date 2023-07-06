process UNPACK_BAM {
    tag "$input_bam"
    label 'process_high'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://mskcc/unpack_bam:0.1.0' :
        'docker.io/mskcc/unpack_bam:0.1.0' }"

    input:
    tuple val(meta), path(input_bam)

    output:
    tuple val(meta), path("${meta.id}/rg*/*.fastq.gz")    , emit: reads
    path "${meta.id}/*.*"                                 , emit: results
    path "versions.yml"                                   , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script: // This script is bundled with the pipeline, in nf-core/phoenix/bin/
            // TODO: Move picard jar out or create a container with this tool's reqs
    """
    mkdir -p unpack_bam/tmpdir
    perl $PWD/bin/unpack_bam.pl \\
        --input-bam $input_bam \\
        --sample-id ${meta.id} \\
        --tmp-dir unpack_bam/tmpdir \\
        --picard-jar /opt/common/CentOS_6-dev/picard/v2.13/picard.jar \\
        --output-dir ${meta.id}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        unpack_bam: 0.1.0 
    END_VERSIONS
    """
}