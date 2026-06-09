set xsim_dir [file normalize .vga_capture_xsim]
file mkdir $xsim_dir
cd $xsim_dir
exec xvlog --relax ../Mini_IO.srcs/sources_1/new/rhythm_video_audio.v ../sim/vga_capture_tb.v [file normalize D:/Xilinx/Vivado/2018.3/data/verilog/src/glbl.v]
exec xelab -debug off -relax -mt 2 -L work -L unisims_ver -L unimacro_ver -L secureip work.vga_capture_tb work.glbl -s vga_capture_tb_behav
exec xsim vga_capture_tb_behav -runall
cd ..
puts "VGA_FAST_SIM_DONE"
