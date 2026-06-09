setws Mini_IO.sdk
importprojects Mini_IO.sdk/HelloWorld_bsp
importprojects Mini_IO.sdk/SeriesIODacSaw
projects -build -type bsp -name HelloWorld_bsp
projects -build -type app -name SeriesIODacSaw
file mkdir [file normalize release]
file copy -force [file normalize Mini_IO.sdk/SeriesIODacSaw/Debug/SeriesIODacSaw.elf] [file normalize release/SeriesIODacSaw.elf]
puts "SDK_BUILD_OK"
puts "ELF: [file normalize Mini_IO.sdk/SeriesIODacSaw/Debug/SeriesIODacSaw.elf]"
