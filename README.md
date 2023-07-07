# [phoenix]

[![AWS CI](https://img.shields.io/badge/CI%20tests-full%20size-FF9900?labelColor=000000&logo=Amazon%20AWS)](https://nf-co.re/phoenix/results)[![Cite with Zenodo](http://img.shields.io/badge/DOI-10.5281/zenodo.XXXXXXX-1073c8?labelColor=000000)](https://doi.org/10.5281/zenodo.XXXXXXX)

[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A522.10.1-23aa62.svg)](https://www.nextflow.io/)
[![run with conda](http://img.shields.io/badge/run%20with-conda-3EB049?labelColor=000000&logo=anaconda)](https://docs.conda.io/en/latest/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)

## Introduction

**phoenix** is a bioinformatics pipeline that ...

<!-- TODO nf-core:
   Complete this sentence with a 2-3 sentence summary of what types of data the pipeline ingests, a brief overview of the
   major pipeline sections and the types of output it produces. You're giving an overview to someone new
   to nf-core here, in 15-20 seconds. For an example, see https://github.com/nf-core/rnaseq/blob/master/README.md#introduction
-->

<!-- TODO nf-core: Include a figure that guides the user through the major workflow steps. Many nf-core
     workflows use the "tube map" design for that. See https://nf-co.re/docs/contributing/design_guidelines#examples for examples.   -->
<!-- TODO nf-core: Fill in short bullet-pointed list of the default steps in the pipeline -->

1. Given a bam, unpacks the bam into fastqs
2. Given xenografts, disambiguates between mouse and human reads
3. If `skip_trimming` is `false` (default), trims fastq reads through `trimgalore` 
4. Uses the typical alignment pipeline provided by `nf-core/subworkflows/fastq_align_bwa`, then `MarkDuplicates`
5. Read QC ([`FastQC`](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/))
6. Present QC for raw reads ([`MultiQC`](http://multiqc.info/))

## Usage

> **Note**
> If you are new to Nextflow and nf-core, please refer to [this page](https://nf-co.re/docs/usage/installation) on how
> to set-up Nextflow.

First, prepare a samplesheet with your input data that looks as follows:

`samplesheet.csv`:

```csv
sample,is_pdx,fastq_1,fastq_2
CONTROL_REP1,true,AEG588A1_S1_L002_R1_001.fastq.gz,AEG588A1_S1_L002_R2_001.fastq.gz
```

Each row represents a pair of fastq files (paired end).

Similarly, a samplesheet containing bam input data is accepted. It should look as follows:

`samplesheet_bam.csv`:

```csv
sample,is_pdx,bam
CONTROL_REP1,true,my_data.bam
```

### JUNO Config

For use with MSKCC's JUNO cluster, set these environment variables:
```
export NXF_SINGULARITY_CACHEDIR=/juno/work/ci/singularity_cachedir_nxf

module load java/jdk-11.0.11
module load singularity/3.7.1
```

Now, you can run the pipeline using:

```bash
nextflow run main.nf \
   -profile juno,singularity \
   <--input samplesheet.csv AND/OR --input_bam samplesheet_bam.csv> \
   --outdir <OUTDIR>
```

### General Use

Finally, edit `conf/resources.config` to include the required reference genome and the directory of the corresponding `bwa` index.

```java 
// conf/resources.config
params {
    fasta_href = "/path/to/human/genome/genome.fa"
    bwa_index_href = "/path/to/human/genome"   // bwa index usually same location as genome.fa

    fasta_mref = "/path/to/mouse/genome/genome.fa"
    bwa_index_mref = "/path/to/mouse/genome"   // bwa index usually same location as genome.fa
}
```

Now, you can run the pipeline using:

```bash
nextflow run main.nf \
   -profile resources,<docker/singularity/.../institute> \
   <--input samplesheet.csv AND/OR --input_bam samplesheet_bam.csv> \
   --outdir <OUTDIR>
```

NOTE: `samplesheet.csv` can contain both pdx and non-pdx samples.
NOTE: You can use the input arguments `--input` and `--input_bam` individually or at the same time when running `phoenix`.

> **Warning:**
> Please provide pipeline parameters via the CLI or Nextflow `-params-file` option. Custom config files including those
> provided by the `-c` Nextflow option can be used to provide any configuration _**except for parameters**_;
> see [docs](https://nf-co.re/usage/configuration#custom-configuration-files).

For more details, please refer to the [usage documentation](https://nf-co.re/phoenix/usage) and the [parameter documentation](https://nf-co.re/phoenix/parameters).

## Pipeline output

Currently, all output is placed into the directory defined by `--outdir`.
