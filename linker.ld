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
    KEEP(*(.init.rust));
    . = ALIGN(4);
    *(.text .text.*);
  }
  > BRAM

  .rodata : ALIGN(4)
  {
    *(.rodata .rodata.*);
    . = ALIGN(4);
  } > BRAM

  .data : ALIGN(4)
  {
    _sidata = LOADADDR(.data);
    _sdata = .;
    *(.data .data.*);
    /* Must be called __global_pointer$ for linker relaxations to work. */
    PROVIDE(__global_pointer$ = . + 0x800);
    *(.sdata .sdata.*);
    . = ALIGN(4);
    _edata = .;
  } > BRAM AT > BRAM

  .bss (NOLOAD) :
  {
    _sbss = .;
    *(.sbss .sbss.*);
    *(.bss .bss.*);
    . = ALIGN(4);
    _ebss = .;
  } > BRAM

  /* Our stack */
  .stack (NOLOAD) :
  {
    . = ABSOLUTE(_stack_start);
  } > BRAM

  .eh_frame (INFO) : { KEEP(*(.eh_frame)) }
  .eh_frame_hdr (INFO) : { *(.eh_frame_hdr) }
}

ASSERT(SIZEOF(.stack) > _stack_size, ".stack section is too small.");

