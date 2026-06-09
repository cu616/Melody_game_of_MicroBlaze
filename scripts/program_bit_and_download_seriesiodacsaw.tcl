connect -url tcp:127.0.0.1:3121
targets -set -nocase -filter {name =~ "xc7a100t*" && jtag_cable_name =~ "Digilent Nexys4DDR 210292A4BE11A"} -index 0
fpga -file F:/FPGA/mircoCom/Genneral/Mini_IO/release/design_mb_wrapper.bit
after 1000
configparams mdm-detect-bscan-mask 2
targets -set -nocase -filter {name =~ "microblaze*#0" && bscan=="USER2" && jtag_cable_name =~ "Digilent Nexys4DDR 210292A4BE11A"} -index 0
rst -processor
targets -set -nocase -filter {name =~ "microblaze*#0" && bscan=="USER2" && jtag_cable_name =~ "Digilent Nexys4DDR 210292A4BE11A"} -index 0
dow F:/FPGA/mircoCom/Genneral/Mini_IO/release/SeriesIODacSaw.elf
targets -set -nocase -filter {name =~ "microblaze*#0" && bscan=="USER2" && jtag_cable_name =~ "Digilent Nexys4DDR 210292A4BE11A"} -index 0
con
