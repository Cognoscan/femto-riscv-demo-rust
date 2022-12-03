#!/bin/sh
xvlog --sv --define SIM RiscvFemto.sv RiscvFemto_tb.sv RiscvMem.sv RiscvUAT.sv
xelab -a -R RiscvFemto_tb
