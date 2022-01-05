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

	.program_header : {
		_code_len = ADDR(.rodata) - ADDR(.vectors);
		ASSERT(_code_len == LOADADDR(.rodata) - LOADADDR(.vectors),
			"vma code length does not match lma");
		LONG(_code_len);

		_rodata_len = ADDR(.data) - ADDR(.rodata);
		ASSERT(_rodata_len == LOADADDR(.data) - LOADADDR(.rodata),
			"vma rodata length does not match lma");
		LONG(_rodata_len);

		_data_len = ADDR(.bss) - ADDR(.data);
		LONG(_data_len);

		LONG(SIZEOF(.bss))

		ASSERT(
			_code_len + _rodata_len + _data_len + SIZEOF(.bss) == _program_end - _program_start,
			"Program size must match sum of section sizes"
		);
	} > FLASH

	.vectors : {
		_program_start = .;

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

	_program_end = .;

	/DISCARD/ : {
		*(.ARM.exidx)
	}
}
