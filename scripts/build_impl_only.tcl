open_project Mini_IO.xpr
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    error "impl_1 did not complete"
}
if {[string first "Complete" [get_property STATUS [get_runs impl_1]]] < 0} {
    error "impl_1 failed: [get_property STATUS [get_runs impl_1]]"
}
puts "VIVADO_BUILD_OK"
puts "BITSTREAM: [file normalize Mini_IO.runs/impl_1/design_mb_wrapper.bit]"
close_project
