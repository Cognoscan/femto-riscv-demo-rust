#![no_std]
#![no_main]

static mut UAT_VAL: u8 = 5;
static mut UAT_STAT: u16 = 0;

use core::arch::global_asm;

global_asm!(r#"
    .section .init, "ax"
    .global _start
_start:
    .option push
    .option norelax
    la gp, __global_pointer$
    .option pop
    la sp, _stack_start
    mv fp, sp
    la t0, _sidata
    la t1, _sdata
    la t2, _edata
    beq t1, t2, 101f
100: // loop for data
    lw t3, 0(t0)
    sw t3, 0(t1)
    addi t0, t0, 4
    addi t1, t1, 4
    bne t1, t2, 100b
101: // end of loop for data
    la t1, _sbss
    la t2, _ebss
    beq t1, t2, 201f
200: // loop for bss
    sw zero, 0(t1)
    addi t1, t1, 4
    bne t1, t2, 200b
201: // end of loop for bss

    li tp, 0
    li t0, 0
    li t1, 0
    li t2, 0
    li t3, 0
    li t4, 0
    li t5, 0
    li t6, 0
    li s1, 0
    li s2, 0
    li s3, 0
    li s4, 0
    li s5, 0
    li s6, 0
    li s7, 0
    li s8, 0
    li s9, 0
    li s10, 0
    li s11, 0
    li a0, 0
    li a1, 0
    li a2, 0
    li a3, 0
    li a4, 0
    li a5, 0
    li a6, 0
    li a7, 0
    jal _start_rust
"#);

#[panic_handler]
fn panic(_: &core::panic::PanicInfo) -> ! {
    loop {}
}

#[link_section = ".init.rust"]
#[export_name = "_start_rust"]
pub extern "C" fn start() -> ! {
    panic!()
}
