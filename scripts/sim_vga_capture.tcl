create_project vga_capture_tmp ./.vga_capture_tmp -part xc7a100tcsg324-1 -force
add_files Mini_IO.srcs/sources_1/new/rhythm_video_audio.v
add_files -fileset sim_1 sim/vga_capture_tb.v
set_property top vga_capture_tb [get_filesets sim_1]
launch_simulation
run all
close_sim
close_project
