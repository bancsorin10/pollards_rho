
# questa_path=/home/sorin/intelFPGA_lite/24.1std/questa_fse/bin
# quartus_path=/home/sorin/intelFPGA_lite/24.1std/quartus/bin
questa_path=/home/sorin/altera_lite/25.1std/
quartus_path=/home/sorin/altera_lite/25.1std/quartus/bin
workdir=simulation_wd


all: build program

build:
	quartus_sh --flow compile hello

program:
	quartus_pgm -c USB-Blaster -m JTAG -o "p;hello.sof"

configure:
	quartus_sh -t hello.tcl


simulation:
	rm -rf $(workdir)
	vlog -work $(workdir) hello.v math.v uart.v
	vsim -c $(workdir).test_pollard -do "run -all"
