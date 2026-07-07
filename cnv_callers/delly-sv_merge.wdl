version 1.0

workflow DellyMergeSites {
  input {
    File delly_bcf_manifest

    String memory = "16G"
    Int disk_gb = 300
  }

  Array[File] delly_bcfs = read_lines(delly_bcf_manifest)

  call MergeSites {
    input:
      delly_bcfs = delly_bcfs,
      memory = memory,
      disk_gb = disk_gb
  }

  output {
    File delly_sites_bcf = MergeSites.sites_bcf
  }
}

task MergeSites {
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
      --minsize 20 \
      --maxsize 150000 \
      -p \
      -o out/delly.sites.bcf \
      in/*.bcf
  >>>

  output {
    File sites_bcf = "out/delly.sites.bcf"
  }

  runtime {
    docker: "dellytools/delly:v2.1.0"
    cpu: 1
    memory: memory
    disks: "local-disk " + disk_gb + " HDD"
  }
}
