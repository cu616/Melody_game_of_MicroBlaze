connect -url tcp:127.0.0.1:3121
configparams mdm-detect-bscan-mask 2
targets -set -nocase -filter {name =~ "microblaze*#0" && bscan=="USER2" && jtag_cable_name =~ "Digilent Nexys4DDR 210292A4BE11A"} -index 0
mwr 0x4000000C 0x00000000
mwr 0x40000008 0x0000FFFF
puts "GPIO0 LED channel forced to 0xFFFF"
puts [mrd 0x40000000 4]
