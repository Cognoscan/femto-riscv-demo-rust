#![no_std]
#![no_main]

use core::arch::global_asm;

global_asm!(r#"
    .section .init, "ax"
    .global _start
_start:
    la sp, _stack_start
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
