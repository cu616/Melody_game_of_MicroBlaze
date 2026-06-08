connect -url tcp:127.0.0.1:3121
configparams mdm-detect-bscan-mask 2
targets -set -nocase -filter {name =~ "microblaze*#0" && bscan=="USER2" && jtag_cable_name =~ "Digilent Nexys4DDR 210292A4BE11A"} -index 0
rst -processor
targets -set -nocase -filter {name =~ "microblaze*#0" && bscan=="USER2" && jtag_cable_name =~ "Digilent Nexys4DDR 210292A4BE11A"} -index 0
dow F:/FPGA/mircoCom/Genneral/Mini_IO/Mini_IO.sdk/SeriesIODacSaw/Debug/SeriesIODacSaw.elf
targets -set -nocase -filter {name =~ "microblaze*#0" && bscan=="USER2" && jtag_cable_name =~ "Digilent Nexys4DDR 210292A4BE11A"} -index 0
con
