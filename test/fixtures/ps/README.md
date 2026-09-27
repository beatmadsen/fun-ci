Listings recorded from real `ps`, which `test/unit/evidence/test_process_table.rb`
parses: `bsd.txt` from macOS, `procps.txt` from procps-ng 4.0.4 in the
maven:3.9-eclipse-temurin-21 image, both from
`ps -A -o pid=,ppid=,pgid=,etime=,args=`, and `busybox.txt` from alpine:3.20,
whose busybox takes neither `-A` nor `=`, from `ps -o pid,ppid,pgid,etime,args`.
