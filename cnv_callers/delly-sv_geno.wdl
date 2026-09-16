version 1.0

workflow DellySVGenotype {
  input {
    String sample
    File cram
    File cram_index
    File sites_bcf

    String memory = "8G"
    Int disk_gb = 100
  }

  call RunDellySVGenotype {
    input:
      sample = sample,
      cram = cram,
      cram_index = cram_index,
      sites_bcf = sites_bcf,
      memory = memory,
      disk_gb = disk_gb
  }

  output {
    File delly_sv_geno_bcf = RunDellySVGenotype.geno_bcf
    File delly_sv_geno_bcf_index = RunDellySVGenotype.geno_bcf_index
  }
}

task RunDellySVGenotype {
  input {
    String sample
    File cram
    File cram_index
    File sites_bcf

    String memory
    Int disk_gb

    File ref_fasta = "gs://intermed-files-wb-strong-apple-3019/resources/Homo_sapiens_assembly38.fasta"
    File ref_fai = "gs://intermed-files-wb-strong-apple-3019/resources/Homo_sapiens_assembly38.fasta.fai"
    File exclude_bed = "gs://intermed-files-wb-strong-apple-3019/resources/exclude.cnvnator_100bp.GRCh38.20170403.bed"
  }

  command <<<
    set -euo pipefail

    mkdir -p out

    delly call \
      -g ~{ref_fasta} \
      -v ~{sites_bcf} \
      -o out/~{sample}.geno.bcf \
      -x ~{exclude_bed} \
      ~{cram}
  >>>

  output {
    File geno_bcf = "out/~{sample}.geno.bcf"
    File geno_bcf_index = "out/~{sample}.geno.bcf.csi"
  }

  runtime {
    docker: "dellytools/delly:v2.1.0"
    cpu: 1
    memory: memory
    disks: "local-disk " + disk_gb + " HDD"
  }
}
