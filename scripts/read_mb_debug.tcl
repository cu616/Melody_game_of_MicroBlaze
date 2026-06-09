connect -url tcp:127.0.0.1:3121
configparams mdm-detect-bscan-mask 2
targets -set -nocase -filter {name =~ "microblaze*#0" && bscan=="USER2" && jtag_cable_name =~ "Digilent Nexys4DDR 210292A4BE11A"} -index 0
puts "TARGET:"
puts [targets]
puts "PC:"
puts [rrd pc]
puts "GPIO0 CH1 DATA/TRI, CH2 DATA/TRI:"
puts [mrd 0x40000000 4]
puts "SPI0 CR/SR/SSR/TFO/RFO:"
puts [mrd 0x44A00060 8]
