
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


config: configure

simulation:
	rm -rf $(workdir)
	vlog -work $(workdir) math.v ram.v test_bench.v gcd_rewrite.v uart.v
	vsim -c $(workdir).test_gcd_rew -do "run -all"
	vsim -c -voptargs="+acc=rn" $(workdir).test_pollard -do "run -all"
	vsim -c $(workdir).test_mul -do "run -all"
	vsim -c $(workdir).test_clear -do "run -all"
	vsim -c $(workdir).test_copy -do "run -all"
	vsim -c $(workdir).test_shift -do "run -all"
	vsim -c $(workdir).test_full_add -do "run -all"
	vsim -c $(workdir).test_constant_add -do "run -all"
	vsim -c $(workdir).test_compare -do "run -all"
	vsim -c $(workdir).test_full_sub -do "run -all"
	vsim -c -voptargs="+acc=rn" $(workdir).test_gcd -do "run -all"

sim: simulation
