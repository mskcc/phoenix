//
// Check input bam samplesheet and get bam channels
//

include { SAMPLESHEET_CHECK_BAM } from '../../modules/local/samplesheet_check_bam'

workflow INPUT_CHECK_BAM {
    take:
    samplesheet // file: /path/to/samplesheet_bam.csv

    main:
    SAMPLESHEET_CHECK_BAM ( samplesheet )
        .csv
        .splitCsv ( header:true, sep:',' )
        .map { create_bam_channel(it) }
        .set { bams }

    emit:
    bams                                     // channel: [ val(meta), [ bam ] ]
    versions = SAMPLESHEET_CHECK_BAM.out.versions // channel: [ versions.yml ]
}

// Function to get list of [ meta, [ bams ] ]
def create_bam_channel(LinkedHashMap row) {
    // create meta map
    def meta = [:]
    meta.id         = row.sample
    meta.is_pdx     = row.is_pdx.toBoolean()

    // add path(s) of the bam to the meta map
    def bam_meta = []
    if (!file(row.bam).exists()) {
        exit 1, "ERROR: Please check input samplesheet -> BAM file does not exist!\n${row.bam}"
    }
    bam_meta = [ meta, [file(row.bam)] ]
   
    return bam_meta
}
