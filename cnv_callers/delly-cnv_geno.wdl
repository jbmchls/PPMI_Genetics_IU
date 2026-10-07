version 1.0

workflow DellyCNVGenotype {
  input {
    String sample
    File cram
    File cram_index
    File sites_bcf
    File mappability_map

    String memory = "8G"
    Int disk_gb = 100
  }

  call RunDellyCNVGenotype {
    input:
      sample = sample,
      cram = cram,
      cram_index = cram_index,
      sites_bcf = sites_bcf,
      mappability_map = mappability_map,
      memory = memory,
      disk_gb = disk_gb
  }

  output {
    File delly_cnv_geno_bcf = RunDellyCNVGenotype.geno_bcf
    File delly_cnv_geno_bcf_index = RunDellyCNVGenotype.geno_bcf_index
  }
}

task RunDellyCNVGenotype {
  input {
    String sample
    File cram
    File cram_index
    File sites_bcf

    String memory
    Int disk_gb

    File mappability_map = "gs://intermed-files-wb-strong-apple-3019/resources/Homo_sapiens.GRCh38.dna.primary_assembly.fa.r101.s501.blacklist.gz"
    File ref_fasta = "gs://intermed-files-wb-strong-apple-3019/resources/Homo_sapiens_assembly38.fasta"
    File ref_fai = "gs://intermed-files-wb-strong-apple-3019/resources/Homo_sapiens_assembly38.fasta.fai"
  }

  command <<<
    set -euo pipefail

    mkdir -p out

    delly cnv \
      -v ~{sites_bcf} \
      -g ~{ref_fasta} \
      -m ~{mappability_map} \
      -o out/~{sample}.cnv.geno.bcf \
      ~{cram}
  >>>

  output {
    File geno_bcf = "out/~{sample}.cnv.geno.bcf"
    File geno_bcf_index = "out/~{sample}.cnv.geno.bcf.csi"
  }

  runtime {
    docker: "dellytools/delly:v2.1.0"
    cpu: 1
    memory: memory
    disks: "local-disk " + disk_gb + " HDD"
  }
}
