### Makefile for the eclass project
### Generated by Bluespec Workstation on Thu Nov 12 19:54:06 IST 2015

include ./old_vars
include soc_config.inc

TOP_MODULE:=mkriscv
TOP_FILE:=riscv.bsv
TOP_DIR:=./src/core/
WORKING_DIR := $(shell pwd)

ifneq (,$(findstring RV64,$(ISA)))
  define_macros += -D RV64=True
  XLEN=64
endif
ifneq (,$(findstring RV32,$(ISA)))
  define_macros += -D RV32=True
  XLEN=32
endif
ifneq (,$(findstring M,$(ISA)))
  define_macros += -D muldiv=True
endif
ifneq (,$(findstring A,$(ISA)))
  define_macros += -D atomic=True
endif
ifeq ($(VERBOSE),enable)
  define_macros += -D verbose=True
endif
ifeq ($(PERF),enable)
  define_macros	+= -D perf=True
endif
ifeq ($(JTAG),enable)
  define_macros	+= -D JTAG=True
endif
ifeq ($(DEBUG),enable)
  define_macros += -D Debug=True
endif
ifeq ($(OPENOCD),enable)
  define_macros += -D Openocd=True
endif
ifeq ($(SYNTH),SIM)
  define_macros += -D simulate=True
endif

CORE:=./src/core/
#TESTBENCH:=./src/testbench/
LIB:=./src/lib/
VERILATOR_FLAGS = --stats -O3 -CFLAGS -O3 -LDFLAGS -static --x-assign fast --x-initial fast --noassert --cc --bbox-sys -Wno-STMTDLY -Wno-UNOPTFLAT -Wno-WIDTH -Wno-lint -Wno-COMBDLY -Wno-INITIALDLY -Wno-INFINITELOOP
BSVINCDIR:= .:%/Prelude:%/Libraries:%/Libraries/BlueNoC:$(CORE):$(LIB)
default: compile_bluesim link_bluesim 

check-blue:
	@if test -z "$$BLUESPECDIR"; then echo "BLUESPECDIR variable not set"; exit 1; fi; 

check-py:
	@if ! [ -a /usr/bin/python3 ] ; then echo "Python3 is required in /usr/bin to run AAPG" ; exit 1; fi;

###### Setting the variables for bluespec compile #$############################
BSVCOMPILEOPTS:= -check-assert  -keep-fires -opt-undetermined-vals -remove-false-rules -remove-empty-rules -remove-starved-rules 
BSVLINKOPTS:=-parallel-sim-link 8 -keep-fires
VERILOGDIR:=./verilog/
BSVBUILDDIR:=./bsv_build/
BSVOUTDIR:=./bin
################################################################################

########## BSIM COMLILE, LINK AND SIMULATE TARGETS #################################
.PHONY: check-restore
check-restore:
	@if [ "$(define_macros)" != "$(old_define_macros)" ];	then	make clean ;	fi;

.PHONY:  compile_bluesim
compile_bluesim: check-restore check-blue
	@echo "Compiling $(TOP_MODULE) in Bluesim..."
	@mkdir -p $(BSVBUILDDIR) 
	@echo "old_define_macros = $(define_macros)" > old_vars
	bsc -u -sim -simdir $(BSVBUILDDIR) -bdir $(BSVBUILDDIR) -info-dir $(BSVBUILDDIR) $(define_macros) $(BSVCOMPILEOPTS) -p $(BSVINCDIR) -g $(TOP_MODULE) $(TOP_DIR)/$(TOP_FILE) 2>&1 | tee bsv_compile.log
	@echo "Compilation finished"

.PHONY: link_bluesim
link_bluesim:check-blue
	@echo "Linking $(TOP_MODULE) in Bluesim..."
	@mkdir -p $(BSVOUTDIR)
	bsc -e $(TOP_MODULE) -sim -o $(BSVOUTDIR)/out -simdir $(BSVBUILDDIR) -p $(BSVINCDIR) -bdir $(BSVBUILDDIR) $(BSVLINKOPTS) ./src/uncore/debug/RBB_Shakti.c 2>&1 | tee bsv_link.log
	@echo Linking finished

.PHONY: simulate
simulate:
	@echo Simulation...
	@exec ./$(BSVOUTDIR)/out
	@echo Simulation finished
########################################################################################

.PHONY: generate_verilog 
generate_verilog: check-restore check-blue 
	@echo Compiling mkTbSoc in Verilog for simulations ...
	@mkdir -p $(BSVBUILDDIR); 
	@mkdir -p $(VERILOGDIR); 
	@echo "old_define_macros = $(define_macros)" > old_vars
	bsc -u -verilog -elab -vdir $(VERILOGDIR) -bdir $(BSVBUILDDIR) -info-dir $(BSVBUILDDIR) $(define_macros) -D verilog=True $(BSVCOMPILEOPTS) -verilog-filter ${BLUESPECDIR}/bin/basicinout -p $(BSVINCDIR) -g $(TOP_MODULE) $(TOP_DIR)/$(TOP_FILE) 2>&1 | tee bsv_compile.log
	@cp ${BLUESPECDIR}/Verilog.Vivado/RegFile.v ./verilog/
	@cp ${BLUESPECDIR}/Verilog/FIFO2.v ./verilog/
	@echo Compilation finished

.PHONY: link_vcs
link_vcs: 
	@mkdir -p bin
	@vcs -full64 -l vcs_compile.log -sverilog +vpi +nbaopt +delay_mode_zero +v2k +define+TOP=$(TOP_MODULE) +cli+4 +libext+.v +notimingcheck -y ./$(VERILOGDIR)/ -y ${BLUESPECDIR}/Verilog/ -y ./src/bfm -timescale=1ns/1ps ${BLUESPECDIR}/Verilog/main.v -o out
	@mv csrc out* bin

.PHONY: link_ncverilog
link_ncverilog: 
	@echo "Linking $(TOP_MODULE) using ncverilog..."
	@rm -rf work include bin/work
	@mkdir -p bin 
	@mkdir work
	@echo "define work ./work" > cds.lib
	@echo "define WORK work" > hdl.var
	@ncvlog -sv -cdslib ./cds.lib -hdlvar ./hdl.var +define+TOP=$(TOP_MODULE) ${BLUESPECDIR}/Verilog/main.v -y ./$(VERILOGDIR)/ -y ${BLUESPECDIR}/Verilog/ -y ./src/bfm
	@ncelab  -cdslib ./cds.lib -hdlvar ./hdl.var work.main -timescale 1ns/1ps
	@echo 'ncsim -cdslib ./cds.lib -hdlvar ./hdl.var work.main #> /dev/null' > $(BSVOUTDIR)/out
	@mv work cds.lib hdl.var $(BSVOUTDIR)/
	@chmod +x $(BSVOUTDIR)/out
	@echo Linking finished

.PHONY: link_msim
link_msim: 
	@echo "Linking $(TOP_MODULE) using modelsim..."
	@rm -rf work* bin/*
	@mkdir -p bin 
	vlib work
	vlog -work work +libext+.v+.vqm -y ./src/bfm -y $(VERILOGDIR) -y ${BLUESPECDIR}/Verilog +define+TOP=$(TOP_MODULE) ${BLUESPECDIR}/Verilog/main.v ./$(VERILOGDIR)/$(TOP_MODULE).v  > compile_log
	mv compile_log ./$(BSVOUTDIR)
	mv work ./$(BSVOUTDIR)
	echo 'vsim -quiet -novopt -lib work -do "run -all; quit" -c main' > $(BSVOUTDIR)/out
	@chmod +x $(BSVOUTDIR)/out
	@echo Linking finished

.PHONY: link_verilator
link_verilator: 
	@echo "Linking $(TOP_MODULE) using verilator"
	@mkdir -p bin
	@verilator $(VERILATOR_FLAGS)  -I./src/bfm -I$(VERILOGDIR) -y ./src/bfm -y $(VERILOGDIR) -DTOP=$(TOP_MODULE) ./verilog/main.v -o out
	@mv out bin/

.PHONY: link_iverilog
link_iverilog: 
	@echo "Linking $(TOP_MODULE) using iverilog..."
	@mkdir -p bin 
	@iverilog -v -o bin/out -Wall -y ./src/bfm -y $(VERILOGDIR) -y ${BLUESPECDIR}/Verilog/ -DTOP=$(TOP_MODULE) ${BLUESPECDIR}/Verilog/main.v .$(VERILOGDIR)/$(TOP_MODULE).v
	@echo Linking finished

.PHONY: generate_boot_files
generate_boot_files:
	@mkdir -p bin
	@cd verification/dts/; make create_hex;
	@cut -c1-8 verification/dts/boot.hex > bin/boot.MSB
	@cut -c9-16 verification/dts/boot.hex > bin/boot.LSB

.PHONY: clean
clean:
	rm -rf $(BSVBUILDDIR) *.log $(BSVOUTDIR)

clean_verilog: clean 
	rm -rf verilog/


restore: clean_verilog
