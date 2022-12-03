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

[tutorial]: https://github.com/BrunoLevy/learn-fpga/tree/master/FemtoRV/TUTORIALS/FROM_BLINKER_TO_RISCV
[riscv_rt]: https://docs.rs/riscv-rt/latest/riscv_rt/

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
program, and get rid of `println` while we're at it. Now our program is 
literally just:

```rust
#![no_std]

fn main() { }
```

And...it fails, but with only one error now:

```
error: `#[panic_handler]` function required, but not found
```

Ok, we need a "panic handler". What's that? Well, whenever Rust hits a an error 
like a bounds check failure, or whenever you call `panic!()`, it needs a 
function to call with the panic info. We can write one ourselves, the simplest 
one possible: an empty loop that never ends:

```rust
#[panic_handler]
fn panic(_: &core::panic::PanicInfo) -> ! {
    loop {}
}
```

The panic handler's function signature is simple - take in info collected as 
part of the panic (which we'll ignore), and the ! means it must never return 
(because our program must halt in this function). So with that put in, do we 
compile now? ...Nope!

```
error: requires `start` lang_item
```

Hmm...ok, so, we need a `start` function if this is going to compile. Turns out, 
when you're baremetal, nothing is guaranteed, not even getting to `main`. 
`start` is the very-very first instruction the processor will run, and we need 
to provide it. So, let's do away with `main` and put in a specially marked 
`start` instead. Now the program looks like:

```rust
#![no_std]
#![no_main]

#[panic_handler]
fn panic(_: &core::panic::PanicInfo) -> ! {
    loop {}
}

#[no_mangle]
pub extern "C" fn start() -> ! {
    panic!()
}
```

So, we told the compiler we no longer have a `main` with `#![no_main]`, we 
marked it as a C ABI-compatible function with `extern "C"`, and told Rust to not 
mess with the name by adding `#[no_mangle]`. Does it compile now? Yes! So let's 
check the content using llvm-objdump and see what we've got:

```objdump
llvm-objdump -h target/riscv32i-unknown-none-elf/release/femto-riscv-demo

target/riscv32i-unknown-none-elf/release/femto-riscv-demo:      file format elf32-littleriscv

Sections:
Idx Name              Size     VMA      Type
  0                   00000000 00000000
  1 .eh_frame         00000018 00010094 DATA
  2 .riscv.attributes 0000001c 00000000
  3 .debug_abbrev     00000ece 00000000 DEBUG
  4 .debug_info       0002333e 00000000 DEBUG
  5 .debug_aranges    00001b88 00000000 DEBUG
  6 .debug_ranges     0000d728 00000000 DEBUG
  7 .debug_str        000376a2 00000000 DEBUG
  8 .debug_pubnames   000122ce 00000000 DEBUG
  9 .debug_pubtypes   000001d4 00000000 DEBUG
 10 .debug_line       0002771a 00000000 DEBUG
 11 .comment          00000013 00000000
 12 .symtab           00015260 00000000
 13 .shstrtab         000000ae 00000000
 14 .strtab           00000594 00000000
```

...well, it compiled! Looks like there's no code though (there'd be a TEXT Type
section somewhere if there was). This is all debug and data, no code to speak 
of. And if we used the `-d` flag instead of `-h`, llvm-objdump would also show 
no disassembly. Well, hey, at least it compiles! That's progress!

Step 3: Adding a Linker Script
------------------------------

To actually make something stick, it's time to get arcane and tell Rust more 
about our processor's memory layout and where we want the code to be. That means 
we need... a linker script. The linker is responsible for linking together all 
our bits of code and data and ordering it all up correctly in memory. It can't 
really do that if we haven't told it anything about our processor's memory or 
where things should go, yah? So let's do that.

Our linker script starts off by declaring the memory available. My little 
processor only has a measly 1 kiB of memory to its name:

```
MEMORY
{
  BRAM (RWX) : ORIGIN = 0x0000, LENGTH = 0x0800  /* 1kiB RAM */
}
```

Here, we've declared the "MEMORY" section of our script, where each line item is 
a section of memory in the processor's address space. We call it "BRAM", though 
any name is accepted, put RWX to mark it as read-write-execute, state the base 
address (or ORIGIN) as 0, and the total LENGTH as 1 kiB, or 0x0800 in hex.

As another example, maybe you've already split things up into ROM and RAM, and 
have, say, 4 kiB for each of those. Easy enough, we just add another line item, 
mark them appropriately, and set the ORIGIN and LENGTH correctly:

```
MEMORY
{
  ROM (RX) : ORIGIN = 0x0000, LENGTH = 4K
  RAM (RW) : ORIGIN = 0x1000, LENGTH = 4K
}
```

Look, we can even use shorthand and call the length 4K.

Anyway, memory declared. Now we need to tell the linker where to put the code. 
We do this with "SECTIONS". Code is, for historical reasons or whatever, called 
".text". We thus:

1. Declare a ".text" section
2. Tell it to KEEP anything matching `*(.init)`, which will put in a section 
	called `.init` at the top of the code, ensuring it executes first.
3. Realign to a 4-byte boundary (which would matter if we had compressed 
	instructions or something in our start function).
4. Put in any remaining text sections with `*(.text .text.*);`
5. Take this bundled-up section and stick it in BRAM. It's the first section 
	we've declared, so it gets to go in at the top of BRAM.

```
SECTIONS
{
	.text :
  {
    KEEP(*(.init));
    . = ALIGN(4);
    *(.text .text.*);
  }
  > BRAM
}
```

You may be thinking, "hey, there's more than just code in a program file. What 
about read-only data, and global variables, and the stack, and the heap, and so 
on?" Well, right now we're just trying to run a loop forever, thanks, so we 
don't need any of that yet. We'll get more than just code eventually, let's take 
it nice and slow.

Anyway, at this point, we need to change how we've marked up our start function. It 
should now look like this instead:

```rust
#[link_section = ".init"]
#[export_name = "_start"]
pub extern "C" fn start() -> ! {
    panic!()
}
```

We've marked the linker section we want it in, and we've forced Rust to set the 
name to _start when it gets exported as compiled code for the linker. This 
replaces `no_mangle` by making it so we don't care what we call it internally - 
it's going to be "_start" and that's that.

Whew, OK, so we've got our linker script, which I'm going to call "linker.ld" 
and put in the root folder of the crate. Now how do we make Rust actually use 
it? We're going to need a build.rs file to tell Rust where it is, where to copy 
it, and that it's part of the build process and thus we need to rebuild if it 
changes. So, make a build.rs in the root of your crate folder and stick this in:

```rust
use std::env;
use std::fs;
use std::path::PathBuf;

fn main() {
    let out_dir = PathBuf::from(env::var("OUT_DIR").unwrap());

    // Put the linker script somewhere the linker can find it.
    fs::write(out_dir.join("linker.ld"), include_bytes!("linker.ld")).unwrap();
    println!("cargo:rustc-link-search={}", out_dir.display());
    println!("cargo:rerun-if-changed=linker.ld");

    println!("cargo:rerun-if-changed=build.rs");
}
```

We still need to make the linker use the script though, and that requires we add 
another section to that .cargo/config.toml file:

```toml
[target.riscv32i-unknown-none-elf]
rustflags = ["-C", "link-arg=-Tlinker.ld"]
```

This tells cargo that when running, we pass an argument to rustc, and that 
argument is an argument it will pass to the linker, and *that*
argument is `-Tlinker.ld`, which means "Use the script linker.ld when linking, 
please."

Ok, cool, linker script in, it should be used, and the start function has been 
marked up. The build completes, let's look at the object file:

```objdump
target/riscv32i-unknown-none-elf/release/femto-riscv-demo:      file format elf32-littleriscv

Sections:
Idx Name                                                Size     VMA      Type
  0                                                     00000000 00000000
  1 .text                                               000000c4 00000000 TEXT
  2 .rodata..Lanon.fc0a1066aa4fa77f512f6c4b34f043aa.0   0000000e 000000c4 DATA
  3 .rodata..Lanon.fc0a1066aa4fa77f512f6c4b34f043aa.1   0000000b 000000d2 DATA
  4 .rodata..Lanon.fc0a1066aa4fa77f512f6c4b34f043aa.2   00000010 000000e0 DATA
  5 .rodata..Lanon.70a4e2c603b3c5e600a4a08141e4d272.2   00000000 000000f0 DATA
  6 .rodata..Lanon.70a4e2c603b3c5e600a4a08141e4d272.232 00000010 000000f0 DATA
  7 .eh_frame                                           00000070 00000100 DATA
  8 .riscv.attributes                                   0000001c 00000000
  9 .debug_abbrev                                       00000ece 00000000 DEBUG
 10 .debug_info                                         0002333e 00000000 DEBUG
 11 .debug_aranges                                      00001b88 00000000 DEBUG
 12 .debug_ranges                                       0000d728 00000000 DEBUG
 13 .debug_str                                          000376a2 00000000 DEBUG
 14 .debug_pubnames                                     000122ce 00000000 DEBUG
 15 .debug_pubtypes                                     000001d4 00000000 DEBUG
 16 .debug_line                                         0002771a 00000000 DEBUG
 17 .comment                                            00000013 00000000
 18 .symtab                                             00015580 00000000
 19 .shstrtab                                           000001b0 00000000
 20 .strtab                                             000007af 00000000
```

Hey, look at that, a TEXT section! And it starts with `<_start>` if I look at 
the disassembly with `-d`:

```objdump
Disassembly of section .text:

00000000 <_start>:
       0: 37 05 00 00   lui     a0, 0
       4: 13 05 45 0c   addi    a0, a0, 196
       8: b7 05 00 00   lui     a1, 0
       c: 13 86 05 0e   addi    a2, a1, 224
      10: 93 05 e0 00   li      a1, 14
      14: 97 00 00 00   auipc   ra, 0
      18: e7 80 80 02   jalr    40(ra)
      1c: 73 10 00 c0   unimp

... lots more after here ...
```

There's a bunch more code stuck in afterwards. I wonder if we can shrink that at 
all? Well... first, let's try putting this into the RISC-V and running it! How 
do we do that?

Step 4: Loading the program
---------------------------

So, I was all set to say it's easy - just use objcopy to convert the compiled 
file (an ELF file) into the verilog memory format, buuuuut alas, that doesn't 
quite work yet. objcopy supports verilog as an output format, such that you can 
do `objcopy -I elf32-little -O verilog ./infile ./outfile.mem`, but it defaults 
to 1 byte wide memories only. The 4-byte output, enabled with 
`--verilog-data-width 4`, is both big-endian and gets the address offsets wrong. 
There's [a bug about this](verilog_bug) that may be merged and in objcopy by the 
time you read this, but watch out for it. Oh, and if you're thinking, "why not 
just read a byte at a time", the synthesis tools won't be happy with whatever 
memory style you come up with. You can kind of finagle it with yosys, but Vivado 
will turn everything into registers and cry.

[verilog_bug]: https://sourceware.org/bugzilla/show_bug.cgi?id=25202

So, for now, no easy tool for us. Instead we'll turn the file into raw binary, 
then we'll turn that into a verilog memory file - I'm going to use `xxd` for 
this, but there's a zillion ways to change binary to 4-byte-wide hex, choose 
whatever. My result is this script:

```sh
#!/bin/sh
cargo build --release
objcopy -I elf32-little -O binary ./target/riscv32i-unknown-none-elf/release/femto-riscv-demo ./program.bin
xxd -g 4 -ps -c 4 ./program.bin > ./program.mem
```

RISC-V is little-endian and xxd will preserve that ordering, but the verilog 
`$readmemh` command will read things big-endian. Thus, our memory also needs a 
byte-swap. One more annoyance. I modified the memory with some logic for 
byte-reversal, and used these byte-reversed variables instead of the usual:

```systemverilog
// Byte reversal
logic [31:0] memOut;
logic [31:0] memIn;
logic [3:0] strobeIn;
always_comb for (int i=0; i<4; i++) rData[8*i+:8] = memOut[8*(3-i)+:8];
always_comb for (int i=0; i<4; i++) memIn[8*(3-i)+:8] = wData[8*i+:8];
always_comb for (int i=0; i<4; i++) strobeIn[3-i] = wStrb[i];
```

Check out the memory under [verilog/RiscvMem.sv](verilog/RiscvMem.sv) for the 
full source.

Anyway, with that done, we can kick off a simulation of the processor and see 
what it does. I've got a script for using Vivado's simulator under 
[verilog/riscv.sh](verilog/riscv.sh), and view the VCD output in GTKWave. To 
each their own.

And lo, looking at the sim, it appears to work! It slides through some panic 
handler code, then sits endlessly looping at a single instruction. Huzzah!

![A signal trace showing the program counter changing until it hits 0x20, then 
stopping, while the processor's state machine loops. We are parked.](images/step4.png)

Well, wait... why did the I/O registers change? Our code just loops. Ok, we'll 
look at that, as soon as I get this code a bit smaller...

Step 5: Shrinking Code Size
---------------------------

This is short - we want to tell the compile to make this code smaller as much as 
possible, and we can do that easily within Cargo.toml. We'll tune our "release" 
profile that we've been building with, so all of the following will go under a 
section called `[profile.release]`.

I have a few ideas about what settings to use already, but I'll also check the
[Rust Embedded Book's section][rust-emb-opt] on optimizations. I see it 
recommends I turn *on* the debug setting, because debug info is automatically 
stripped when we turn the ELF file into binary data anway. It also recommends, 
if we're going for size, to try out `opt-level = "z"` and maybe "`codegen_units 
	= 1`.

[rust-emb-opt]: https://docs.rust-embedded.org/book/unsorted/speed-vs-size.html

Ok, I'm going to do all that, and also throw in link-time optimization, because 
I've heard that's good for shrinking Rust executable size. Might not even be 
necessary here, but let's go nuts and put in `lto = true`.

Finally, we don't have a stack to unwind, and when we panic I'm ok with going 
straight to halting, so let's also change the panic approch to "abort" instead 
of the default of "unwind" with `panic = "abort"`. 

So, that gives us:

```toml
[profile.release]
panic = "abort"
codegen-units = 1
debug = 0
lto = true
opt-level = "z"
```

And when we re-run the compilation, lo, the code is small!

```objdump
./program:      file format elf32-littleriscv

Disassembly of section .text:

00000000 <_start>:
       0: 97 00 00 00   auipc   ra, 0
       4: e7 80 00 01   jalr    16(ra)
       8: 73 10 00 c0   unimp

0000000c <_ZN4core9panicking9panic_fmt17hbd94a77ab017a2b1E>:
       c: 6f 00 00 00   j       0xc <.Lline_table_start0+0xc>

00000010 <_ZN4core9panicking5panic17h4c83c909d6b71295E>:
      10: 13 01 01 ff   addi    sp, sp, -16
      14: 23 26 11 00   sw      ra, 12(sp)
      18: 97 00 00 00   auipc   ra, 0
      1c: e7 80 40 ff   jalr    -12(ra)
      20: 73 10 00 c0   unimp
```

Awesome, now let's return to whatever's going on with this small code hitting 
the I/O outputs...

Step 6: Adding a Stack
----------------------

As you can tell by the name of this step, I know what the culprit is already: 
the program is pushing data to the stack, but we never told it where the stack 
is and so it makes assumptions. How did I figure that out, I don't hear you ask? 
Well, I looked at the VCD dump in GTKWave and saw the exact instruction that hit 
the LED register:

![A negative memory address is being written to at the end of instruction 0x14](images/step6.png)

It's instruction 0x14, and that's in the panic handler. Looking over the 
disassembly with llvm-objdump, I saw the instruction `sw ra, 12(sp)`. And 
cracking open the [RISC-V Assembler's manual][asm-manual] (or really, the assembly reference 
of your choice), we see `sp` is the stack pointer register. So, uh, let's fix 
that and add a stack for it to point to!

[asm-manual]" https://github.com/riscv-non-isa/riscv-asm-manual/blob/master/riscv-asm.md

So, stacks. They grow down around these parts, and you're thus expected to put 
the stack wayyyy at the upper end of your memory space. Going to the linker 
script, we'll do a bit of math to declare where that is, sticking this between our 
MEMORY and SECTIONS declarations:

```
PROVIDE(_stack_start = ORIGIN(BRAM) + LENGTH(BRAM));
PROVIDE(_stack_size = 64);
```

This declares a linker symbol, `_stack_start`, which is a little value we get to 
refer to later, in assembly language. We also define what we want the stack size 
to be, at minimum, so we can check later and make sure our stack isn't too small 
due to the size of everything else.

We'll also make a fake section (under SECTIONS) for the stack, telling the 
linker to not load it. And finally, we'll add an ASSERT to make sure the stack 
is big enough. The linker script should now look like this:

```
MEMORY
{
	BRAM (RWX) : ORIGIN = 0x0000, LENGTH = 1K  /* 1kiB RAM */
}

PROVIDE(_stack_start = ORIGIN(BRAM) + LENGTH(BRAM));
PROVIDE(_stack_size = 64);

SECTIONS
{

  /* Our code */
	.text :
  {
    KEEP(*(.init));
    . = ALIGN(4);
    *(.text .text.*);
  }
  > BRAM

  /* Our stack */
  .stack (NOLOAD) :
  {
    . = ABSOLUTE(_stack_start);
  } > BRAM
}

ASSERT(SIZEOF(.stack) > _stack_size, ".stack section is too small.");
```

And let's just compile to make sure that's all good and...

```
error: linking with `rust-lld` failed: exit status: 1
  |
  = note: rust-lld: error: section '.eh_frame' will not fit in region 'BRAM': overflowed by 88 bytes
          rust-lld: error: section '.eh_frame' will not fit in region 'BRAM': overflowed by 88 bytes


error: could not compile `femto-riscv-demo` due to previous error

```

Shoot. Ok. `.eh_frame`. Ehhhh. It's some kind of "Exception Frame". I'm going to 
defer to the wizards who wrote `riscv-rt` on this one and grab their bit of 
linker script to handle these shenanigans. At the end of SECTIONS, let's add:

```
.eh_frame (INFO) : { KEEP(*(.eh_frame)) }
.eh_frame_hdr (INFO) : { *(.eh_frame_hdr) }
```

This seems to mark the exception frame and header as INFO, and makes it not show 
up in the final binary we load. Now compilation completes, and we can move on to 
setting up the stack pointer.

Our little start function in Rust is no longer good enough for this, we're going 
to want to directly write some assembly. So let's start this off by moving our 
Rust start function: change start to be named "_start_rust" and in section 
".init.rust", and add a `KEEP(*(.init.rust));` to our linker's text section right 
after the `KEEP(*(.init));`.

```rust
#[link_section = ".init"]
#[export_name = "_start"]
pub extern "C" fn start() -> ! {
    panic!()
}
```

Now let's add that assembly in! Here's the neat part about Rust 1.59 onward - we 
can just put in global assembly right in the code, no .S file or scripting 
required. Just `global_asm!` and we're off to the races.

Our assembly needs to declare the section it's in, that it's a global label, and 
give our starting label. Then, to make sure we've got it in the right order, 
I've stuck a `ebreak` instruction in there so we've got something to look for in 
the compiled binary.

```rust
use core::arch::global_asm;

global_asm!(r#"
    .section .init, "ax"
    .global _start
_start:
    ebreak
"#);
```

And the disassembly?

```objdump
./program:      file format elf32-littleriscv

Disassembly of section .text:

00000000 <_start>:
       0: 73 00 10 00   ebreak

00000004 <_start_rust>:
       4: 97 00 00 00   auipc   ra, 0
       8: e7 80 00 01   jalr    16(ra)
       c: 73 10 00 c0   unimp
```

Nice. Now we replace that `ebreak` with loading the stack pointer and going to 
the start of the rust program:

```asm
la sp, _stack_start
jal _start_rust
```

And there, we've got our stack pointer! And we're no longer writing to the I/O 
memory space by mistake!

![The entire code executes to the idle loop without the LEDs or UART changing 
state at all](images/step6_end.png)

Step 7: The Rest
----------------

More to Come








