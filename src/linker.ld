MEMORY {
	FLASH(rx) : ORIGIN = 0x10000000, LENGTH = 16M
	SRAM(rwx) : ORIGIN = 0x20000000, LENGTH = 264K

	BOOT2_SRAM(rwx) : ORIGIN = ORIGIN(SRAM) + LENGTH(SRAM) - 256, LENGTH = 256
}

# FIXME: raspberrypi/pico-sdk#689
ENTRY(_start_lma)
_start_lma = _start - ADDR(.text) + LOADADDR(.text);

SECTIONS {
	.boot2 : {
		KEEP(*(.boot2))
		KEEP(*(.boot2.pad))
		KEEP(*(.boot2.checksum))
		ASSERT(SIZEOF(.boot2) == 256, "boot2 must be exactly 256 bytes");
	} > BOOT2_SRAM AT> FLASH

	.flash_size : {
		KEEP(*(.flash_size));
	} > FLASH

	.vectors : {
		KEEP(*(.vectors))
		ASSERT(SIZEOF(.vectors) > 0, "Missing vector table");
	} > SRAM AT> FLASH

	.text : {
		*(.text.*)
	} > SRAM AT> FLASH

	.rodata : {
		*(.rodata.*)
	} > SRAM AT> FLASH
	.data : {
		*(.data.*)
	} > SRAM AT> FLASH

	.bss : {
		*(.bss.*)
	} > SRAM

	/DISCARD/ : {
		*(.ARM.exidx)
	}
}
