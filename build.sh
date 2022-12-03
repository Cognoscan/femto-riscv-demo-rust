#!/bin/sh
cargo build --release
cp ./target/riscv32i-unknown-none-elf/release/femto-riscv-demo ./program
objcopy -I elf32-little -O binary ./program ./program.bin
xxd -g 4 -ps -c 4 ./program.bin > ./program.mem
