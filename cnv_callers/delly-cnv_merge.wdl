version 1.0

workflow DellyMergeCNVSites {
  input {
    File delly_bcf_manifest

    String memory = "16G"
    Int disk_gb = 300
  }

  Array[File] delly_bcfs = read_lines(delly_bcf_manifest)

  call MergeCNVSites {
    input:
      delly_bcfs = delly_bcfs,
      memory = memory,
      disk_gb = disk_gb
  }

  output {
    File delly_cnv_sites_bcf = MergeCNVSites.sites_bcf
  }
}

task MergeCNVSites {
  input {
    Array[File] delly_bcfs

    String memory
    Int disk_gb
  }

  command <<<
    set -euo pipefail

    mkdir -p in out

    bcf_list=~{write_lines(delly_bcfs)}

    while read bcf; do
      ln -s "$bcf" in/
    done < "$bcf_list"

    delly merge \
      -e \
      -p \
      --minsize 20 \
      --maxsize 150000 \
      -o out/delly.cnv.sites.bcf \
      in/*.bcf
  >>>

  output {
    File sites_bcf = "out/delly.cnv.sites.bcf"
  }

  runtime {
    docker: "dellytools/delly:v2.1.0"
    cpu: 1
    memory: memory
    disks: "local-disk " + disk_gb + " HDD"
  }
}
