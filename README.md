Rust on a tiny RISC-V
=====================

I was going through the fantastic ["From Blinker to RISC-V"][tutorial], making a 
functional RISC-V RV32I processor from scratch, when I got to step 20, "Using 
the GNU toolchain to compile programs - assembly". I looked ahead and saw the 
tutorial continues on to C, and thought, hey, why not Rust instead? And that's 
what we're doing here: compiling Rust programs for an incredibly tiny, 
incredibly simple RISC-V processor. So let's start! I'm using the small, poorly 
written, possibly buggy RISC-V I had from the tutorial here for testing - feel 
free to substitute your own.

As a note, before we begin, I'm taking a lot of knowledge and code from the 
[`riscv-rt`][riscv_rt] crate, which does everything I'm doing here and more 
besides. One key difference though - we'll be using Rust's `global_asm!` and 
`asm!` macros to avoid some (but not all) of the annoyances of needing assembly 
initializer code.

Step 1: Setup for cross-compilation
-----------------------------------

It's a safe bet you're not compiling for RV32I from a RV32I, so step 1 for us is 
setting up to cross-compile. This is actually pretty easy, thanks to 
[`rustup`](https://rustup.rs/). Just add our target with rustup like so:

```sh
rustup target add riscv32i-unknown-none-elf
```

And when we create our new binary with cargo, we mark the build target by 
creating the file `.cargo/config.toml` and putting in:

```toml
target = "riscv32i-unknown-none-elf"
```

That's it! We should be good to start cross-compiling. Let's see how that goes!

Step 2: Make Compilation Succeed
--------------------------------

Well, if we try `cargo build -r` with the basic "hello world" program, that 
immediately fails:

```
error[E0463]: can't find crate for `std`
  |
  = note: the `riscv32i-unknown-none-elf` target may not support the standard library
  = note: `std` is required by `femto_riscv_demo` because it does not declare `#![no_std]`

error: cannot find macro `println` in this scope
 --> src/main.rs:2:5
  |
2 |     println!("Hello, world!");
  |     ^^^^^^^

error: `#[panic_handler]` function required, but not found
```

Ah, right, we don't have a standard library here in bare-metal land. So let's 
take that `#![no_std]` marker mentioned in the error message and put it in the 
program, and get rid of `println` while we're at it.


[tutorial]: https://github.com/BrunoLevy/learn-fpga/tree/master/FemtoRV/TUTORIALS/FROM_BLINKER_TO_RISCV
[riscv_rt]: https://docs.rs/riscv-rt/latest/riscv_rt/
