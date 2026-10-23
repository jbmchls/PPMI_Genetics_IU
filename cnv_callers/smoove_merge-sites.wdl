version 1.0

workflow SmooveMergeSites {
  input {
    File smoove_vcf_manifest
    File smoove_index_manifest

    String memory = "32G"
    Int disk_gb = 300
    Int cpu = 4
  }

  Array[File] vcfs = read_lines(smoove_vcf_manifest)
  Array[File] indexes = read_lines(smoove_index_manifest)

  call MergeSites {
    input:
      vcfs = vcfs,
      indexes = indexes,
      memory = memory,
      disk_gb = disk_gb,
      cpu = cpu
  }

  output {
    File smoove_sites_vcf = MergeSites.sites_vcf
    File smoove_sites_vcf_index = MergeSites.sites_vcf_index
    File smoove_counts_html = MergeSites.smoove_counts_html
    
  }
}

task MergeSites {
  input {
    Array[File] vcfs
    Array[File] indexes

    String memory
    Int disk_gb
    Int cpu

    File ref_fasta = "gs://intermed-files-wb-strong-apple-3019/resources/Homo_sapiens_assembly38.fasta"
    File ref_fai = "gs://intermed-files-wb-strong-apple-3019/resources/Homo_sapiens_assembly38.fasta.fai"
  }

  command <<<
    set -euo pipefail

    mkdir -p in out tmp
    export TMPDIR="$PWD/tmp"

    vcf_list=~{write_lines(vcfs)}
    index_list=~{write_lines(indexes)}

    paste "$vcf_list" "$index_list" | while IFS="$(printf '\t')" read -r vcf index; do
      ln -s "$vcf" "in/$(basename "$vcf")"
      ln -s "$index" "in/$(basename "$vcf").csi"
    done

    smoove merge \
      --name merged \
      -f ~{ref_fasta} \
      --outdir out \
      in/*.genotyped.vcf.gz

    bcftools sort \
      -T "$TMPDIR" \
      -Oz \
      -o out/merged.sites.sorted.vcf.gz \
      out/merged.sites.vcf.gz

    bcftools index -f out/merged.sites.sorted.vcf.gz
  >>>

  output {
    File sites_vcf = "out/merged.sites.sorted.vcf.gz"
    File sites_vcf_index = "out/merged.sites.sorted.vcf.gz.csi"
    File smoove_counts_html = "out/merged.smoove-counts.html"
  }

  runtime {
    docker: "brentp/smoove"
    cpu: cpu
    memory: memory
    disks: "local-disk " + disk_gb + " HDD"
  }
}
