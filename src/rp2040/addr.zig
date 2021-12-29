pub const rom_base: usize = 0x0000_0000;

pub const xip_base: usize = 0x1000_0000;
pub const xip_ssi_base: usize = 0x1800_0000;

/// Start of (striped) SRAM mapping
pub const sram_base: usize = 0x2000_0000;
/// SRAM4 mapping (unstriped)
pub const sram4_base: usize = 0x2004_0000;
/// SRAM5 mapping (unstriped)
pub const sram5_base: usize = 0x2004_1000;
/// End of (striped) SRAM mapping
pub const sram_end: usize = 0x2004_2000;
/// Unstriped SRAM0 mapping
pub const sram0_base: usize = 0x2100_0000;
/// Unstriped SRAM1 mapping
pub const sram1_base: usize = 0x2101_0000;
/// Unstriped SRAM2 mapping
pub const sram2_base: usize = 0x2102_0000;
/// Unstriped SRAM3 mapping
pub const sram3_base: usize = 0x2103_0000;

pub const resets_base: usize = 0x4000_c000;

pub const io_bank0_base: usize = 0x4001_4000;
pub const pads_bank0_base: usize = 0x4001_c000;
pub const pads_qspi_base: usize = 0x4002_0000;

pub const sio_base: usize = 0xd000_0000;

pub const ppb_base: usize = 0xe000_0000;
