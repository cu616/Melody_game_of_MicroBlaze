open_project Mini_IO.xpr
set tb_file [file normalize sim/vga_capture_tb.v]
if {[llength [get_files -quiet $tb_file]] > 0} {
    remove_files [get_files $tb_file]
}
set_property top design_mb_wrapper [get_filesets sources_1]
close_project
puts "PROJECT_TOP_RESTORED"
