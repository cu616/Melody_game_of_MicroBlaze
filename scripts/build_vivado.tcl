open_project Mini_IO.xpr
set_property STEPS.SYNTH_DESIGN.TCL.PRE [file normalize scripts/synth_pre.tcl] [get_runs synth_1]
set_property STEPS.OPT_DESIGN.TCL.PRE {} [get_runs impl_1]

# The final demo does not use the old System ILA debug core. Disable its
# generated constraints so Vivado does not try to apply them to a module that is
# no longer present after cleanup.
foreach ila_xdc [get_files -quiet -all *ila_v6_2*/constraints/ila*.xdc] {
    catch {set_property USED_IN_SYNTHESIS false $ila_xdc}
    catch {set_property USED_IN_IMPLEMENTATION false $ila_xdc}
    catch {set_property IS_ENABLED false $ila_xdc}
}

# The final project uses a MicroBlaze block design plus a VGA display bridge.
# RuntimeOptimized keeps rebuilds practical after small RTL cleanups; the board
# clock target is modest enough that the faster strategy is preferred here.
set_property STEPS.SYNTH_DESIGN.ARGS.DIRECTIVE RuntimeOptimized [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY none [get_runs synth_1]
set_property STEPS.OPT_DESIGN.ARGS.DIRECTIVE RuntimeOptimized [get_runs impl_1]
set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE RuntimeOptimized [get_runs impl_1]
set_property STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE RuntimeOptimized [get_runs impl_1]
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    error "synth_1 did not complete"
}
if {[get_property STATUS [get_runs synth_1]] != "synth_design Complete!"} {
    error "synth_1 failed: [get_property STATUS [get_runs synth_1]]"
}

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
file mkdir [file normalize release]
file copy -force [file normalize Mini_IO.runs/impl_1/design_mb_wrapper.bit] [file normalize release/design_mb_wrapper.bit]
close_project
