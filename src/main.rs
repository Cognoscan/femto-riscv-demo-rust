#![no_std]
#![no_main]

use core::arch::global_asm;

global_asm!(r#"
    .section .init, "ax"
    .global _start
_start:
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
    la sp, _stack_start
    mv fp, sp
    jal _start_rust
"#);

#[panic_handler]
fn panic(_: &core::panic::PanicInfo) -> ! {
    loop {}
}

#[link_section = ".init.rust"]
#[export_name = "_start_rust"]
pub extern "C" fn start() -> ! {
    unsafe {
        let uat_write = 0x40_0008 as *mut u8;
        let uat_stat = 0x40_0010 as *const u16;
        loop {
            if core::ptr::read_volatile(uat_stat) != 0 { break; }
        }
        let b = core::ptr::read_volatile(uat_stat) as u8;
        core::ptr::write_volatile(uat_write, b);
    }
    panic!()
}
