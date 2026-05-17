project_new hello -overwrite


set_global_assignment -name FAMILY "Cyclone 10 LP"
set_global_assignment -name DEVICE 10CL006YE144C8G
set_global_assignment -name TOP_LEVEL_ENTITY pollard

set_global_assignment -name VERILOG_FILE hello.v
set_global_assignment -name VERILOG_FILE ram.v
set_global_assignment -name VERILOG_FILE math.v
set_global_assignment -name VERILOG_FILE uart.v
# set_global_assignment -name SYSTEMVERILOG_FILE hello.sv

## led 101 is over nceo
set_global_assignment -name CYCLONEII_RESERVE_NCEO_AFTER_CONFIGURATION "USE AS REGULAR IO"


set_location_assignment PIN_101 -to leds[0]
set_location_assignment PIN_100 -to leds[1]
set_location_assignment PIN_99 -to leds[2]
set_location_assignment PIN_98 -to leds[3]

set_location_assignment PIN_91 -to clk 

set_location_assignment PIN_88 -to reset

# set_location_assignment PIN_43 -to pll1_p
# set_location_assignment PIN_44 -to pll1_n
# set_location_assignment PIN_113 -to pll2_n
# set_location_assignment PIN_114 -to pll2_p

# defining pll s through sdc did not work
set_global_assignment -name SDC_FILE hello.sdc

set_location_assignment PIN_11 -to uart_tx

## create pll ip
# ip-make-project -name test_pll -path ./test_pll
# ip-init -name test_pll -type altera_pll
# 
# set_ip_property test_pll CONFIG.reference_clock_frequency 50.0
# set_ip_property test_pll CONFIG.number_of_clocks 2
# 
# set_ip_property test_pll CONFIG.output_clock_frequency0 25.0
# set_ip_property test_pll CONFIG.output_clock_frequency1 100.0
# 
# set_ip_property test_pll CONFIG.pll_type "General"
# set_ip_property test_pll CONFIG.operation_mode "normal"
# set_ip_property test_pll CONFIG.locked_output_clock true
# 
# ip-generate -name test_pll

# set_global_assignment -name IP_FILE ip/test_pll/test_pll.qip

# exec qsys-script --script to generate pll
# exec qsys-script --script=test_pll.tcl

# set result [catch {exec qsys-script --script=test_altpll.tcl} errMsg]
# if {$result != 0} {
#     puts "Warning: qsys-script returned non-zero, but continuing"
#     puts $errMsg
# }
# set_global_assignment -name QSYS_FILE test_altpll.qsys

# exec qsys-generate test_altpll.qsys --synthesis=VERILOG --family="Cyclone 10 LP" --part=10CL006YE144C8G

project_close
