#!/bin/sh
cargo build --release
cd ./target/riscv32i-unknown-none-elf/release/
objcopy -I elf32-little -O verilog ./target/riscv32i-unknown-none-elf/release/femto-riscv-demo ./program.mem
