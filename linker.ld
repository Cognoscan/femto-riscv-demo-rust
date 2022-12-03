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

  /* Our stack */
  .stack (NOLOAD) :
  {
    . = ABSOLUTE(_stack_start);
  } > BRAM

  .eh_frame (INFO) : { KEEP(*(.eh_frame)) }
  .eh_frame_hdr (INFO) : { *(.eh_frame_hdr) }
}

ASSERT(SIZEOF(.stack) > _stack_size, ".stack section is too small.");

