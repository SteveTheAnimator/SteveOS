ENTRY(_start)

SECTIONS
{
    /* Kernel is loaded at 0x10000 (64KB) physical address */
    . = 0x10000;
    
    /* Assembly entry point first */
    .text : ALIGN(4096)
    {
        *(.text.start)
        *(.text)
    }
    
    /* Read-only data */
    .rodata : ALIGN(4096)
    {
        *(.rodata)
    }
    
    /* Initialized data */
    .data : ALIGN(4096)
    {
        *(.data)
    }
    
    /* Uninitialized data */
    .bss : ALIGN(4096)
    {
        *(COMMON)
        *(.bss)
    }
}