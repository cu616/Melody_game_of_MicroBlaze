read_verilog Mini_IO.srcs/sources_1/new/rhythm_video_audio.v
synth_design -top album_art_track_rom -part xc7a100tcsg324-1
set brams [get_cells -hier -filter {REF_NAME =~ RAMB*}]
puts "ALBUM_ART_BRAM_COUNT=[llength $brams]"
report_utilization
puts "ALBUM_ART_SYNTH_OK"
