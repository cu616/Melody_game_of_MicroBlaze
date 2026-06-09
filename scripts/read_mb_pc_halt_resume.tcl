connect -url tcp:127.0.0.1:3121
configparams mdm-detect-bscan-mask 2
targets -set -nocase -filter {name =~ "microblaze*#0" && bscan=="USER2" && jtag_cable_name =~ "Digilent Nexys4DDR 210292A4BE11A"} -index 0
stop
puts "PC after halt:"
puts [rrd pc]
puts "MSR:"
puts [rrd msr]
puts "First words at reset vector:"
puts [mrd 0x00000000 8]
puts "Main text words:"
puts [mrd 0x00000050 8]
con
