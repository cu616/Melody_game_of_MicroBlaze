set_msg_config -id {Synth 8-3331} -suppress
set_msg_config -id {Synth 8-350} -suppress
set_msg_config -id {Synth 8-689} -suppress

# Vivado 2018.3 reports some generated board automation BOARD_PIN metadata as
# non-user properties. Keep the metadata because it maps AXI GPIO interfaces to
# board-level ports; only suppress the noisy message.
set_msg_config -id {Netlist 29-160} -suppress
