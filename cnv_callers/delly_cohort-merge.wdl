version 1.0

workflow DellyMergeGenotypes {
  input {
    File delly_bcf_manifest

    # "SV" or "CNV"
    String variant_mode = "SV"

    String merge_memory = "16G"
    Int merge_disk_gb = 300
    Int merge_cpu = 8

    String filter_memory = "16G"
    Int filter_disk_gb = 300

    Int chunk_size = 200
  }

  Array[File] delly_bcfs = read_lines(delly_bcf_manifest)

  call MergeGenotypes {
    input:
      genotype_bcfs = delly_bcfs,
      chunk_size = chunk_size,
      memory = merge_memory,
      disk_gb = merge_disk_gb,
      cpu = merge_cpu
  }

  call GermlinePostprocess {
    input:
      cohort_bcf = MergeGenotypes.cohort_bcf,
      cohort_bcf_index = MergeGenotypes.cohort_bcf_index,
      variant_mode = variant_mode,
      memory = filter_memory,
      disk_gb = filter_disk_gb
  }

  output {
    File cohort_bcf = MergeGenotypes.cohort_bcf
    File cohort_bcf_index = MergeGenotypes.cohort_bcf_index

    File germline_bcf = GermlinePostprocess.germline_bcf
    File germline_bcf_index = GermlinePostprocess.germline_bcf_index
  }
}


task MergeGenotypes {
  input {
    Array[File] genotype_bcfs

    Int chunk_size
    String memory
    Int disk_gb
    Int cpu
  }

  command <<<
    set -euo pipefail

    mkdir -p chunks out

    bcf_list=~{write_lines(genotype_bcfs)}

    # Split the 1045 samples into manageable groups.
    split \
      -l ~{chunk_size} \
      -a 4 \
      "$bcf_list" \
      chunks/list_

    : > chunks/merged_chunks.list

    for chunk_list in chunks/list_*; do
      chunk_id=$(basename "$chunk_list")
      chunk_bcf="chunks/merged_${chunk_id}.bcf"

      bcftools merge \
        --no-index \
        --force-single \
        -m id \
        -O b \
        --threads ~{cpu} \
        -l "$chunk_list" \
        -o "$chunk_bcf"

      echo "$chunk_bcf" >> chunks/merged_chunks.list
    done

    # Merge the intermediate cohort chunks.
    bcftools merge \
      --no-index \
      --force-single \
      -m id \
      -O b \
      --threads ~{cpu} \
      -l chunks/merged_chunks.list \
      -o out/delly.cohort.bcf

    bcftools index -f out/delly.cohort.bcf
  >>>

  output {
    File cohort_bcf = "out/delly.cohort.bcf"
    File cohort_bcf_index = "out/delly.cohort.bcf.csi"
  }

  runtime {
    docker: "quay.io/biocontainers/bcftools:1.21--h3a4d415_1"
    cpu: cpu
    memory: memory
    disks: "local-disk " + disk_gb + " HDD"
  }
}


task GermlinePostprocess {
  input {
    File cohort_bcf
    File cohort_bcf_index
    String variant_mode

    String memory
    Int disk_gb
  }

  command <<<
    set -euo pipefail

    mkdir -p out

    if [[ "~{variant_mode}" == "SV" ]]; then

      delly filter \
        -f germline \
        -o out/delly.germline.bcf \
        ~{cohort_bcf}

    elif [[ "~{variant_mode}" == "CNV" ]]; then

      delly classify \
        -f germline \
        -o out/delly.germline.bcf \
        ~{cohort_bcf}

    else
      echo "ERROR: variant_mode must be SV or CNV" >&2
      exit 1
    fi
  >>>

  output {
    File germline_bcf = "out/delly.germline.bcf"
    File germline_bcf_index = "out/delly.germline.bcf.csi"
  }

  runtime {
    docker: "dellytools/delly:v2.1.0"
    cpu: 1
    memory: memory
    disks: "local-disk " + disk_gb + " HDD"
  }
}
