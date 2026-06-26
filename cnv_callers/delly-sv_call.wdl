version 1.0

workflow DellySV {
  input {
    String sample
    File cram
    File cram_index

    String memory = "8G"
    Int disk_gb = 100
  }

  call RunDellySV {
    input:
      sample = sample,
      cram = cram,
      cram_index = cram_index,
      memory = memory, 
      disk_gb = disk_gb
  }

  output {
    File delly_sv_bcf = RunDellySV.bcf
    File delly_sv_bcf_index = RunDellySV.bcf_index
  }
}

task RunDellySV {
  input {
    String sample
    File cram
    File cram_index

    String memory
    Int disk_gb

    File ref_fasta = "gs://iu-share-loni-2/ref/Homo_sapiens_assembly38.fasta"
    File ref_fai = "gs://iu-share-loni-2/ref/Homo_sapiens_assembly38.fasta.fai"
    File exclude_bed = "gs://intermed-files-wb-strong-apple-3019/resources/exclude.cnvnator_100bp.GRCh38.20170403.bed"
  }

  command <<<
    set -euo pipefail

    mkdir -p out

    delly call \
      -o out/~{sample}.delly.bcf \
      -x ~{exclude_bed} \
      -g ~{ref_fasta} \
      ~{cram}

  >>>

  output {
    File bcf = "out/~{sample}.delly.bcf"
    File bcf_index = "out/~{sample}.delly.bcf.csi"
  }

  runtime {
    docker: "dellytools/delly:v2.1.0"
    cpu: 1
    memory: memory
    disks: "local-disk " + disk_gb + " HDD"
  }
}
