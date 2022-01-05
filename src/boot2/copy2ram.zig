const std = @import("std");
const rp = @import("rp2040");

pub const Boot2Config = struct {
    clkdiv: u32 = 4,
    cmd_read: u8 = 0x03,
    addr_l: u6 = 24, // Must be a multiple of 4
};
const config = std.meta.globalOption("boot2_config", Boot2Config) orelse Boot2Config{};

const program_base = rp.addr.xip_base + 0x100;
const program_start = program_base + @sizeOf(ProgramHeader);
const ProgramHeader = extern struct {
    code: u32,
    rodata: u32,
    data: u32,
    zeroes: u32,
};

export fn _flashboot_stage2() linksection(".boot2") void {
    // Disable SSI so we can do config
    rp.regs.xip_ssi.ssienr = 0;

    // Set baud rate
    rp.regs.xip_ssi.baudr = config.clkdiv;

    // Configure XIP
    rp.regs.xip_ssi.ctrlr0.writeConst(.{
        .spi_frf = .single,
        .dfs_32 = 31, // 32 clocks per frame
        .tmod = .eeprom,
    });
    rp.regs.xip_ssi.spi_ctrlr0.writeConst(.{
        .trans_type = .std,
        .addr_l = @divExact(config.addr_l, 4),
        .inst_l = .@"8bit",
        .xip_cmd = config.cmd_read,
    });
    rp.regs.xip_ssi.ctrlr1.writeConst(.{
        .ndf = 0,
    });

    // Enable SSI again
    rp.regs.xip_ssi.ssienr = 1;

    // Read program header
    const header = @intToPtr(*const ProgramHeader, program_base);
    const program_len = header.code + header.rodata + header.data;

    // Copy data
    const mem = @intToPtr([*]align(4) u8, rp.addr.sram_base);
    const flash = @intToPtr([*]align(4) u8, program_start);
    for (flash[0..program_len]) |b, i| {
        mem[i] = b;
    }

    // Zero memory
    for (mem[program_len .. program_len + header.zeroes]) |*b| {
        b.* = 0;
    }

    // Disable SSI before jumping to user code
    rp.regs.xip_ssi.ssienr = 0;

    if (@returnAddress() == 0) { // We're called from bootrom
        // Set up interrupt vectors
        const vectors_addr = rp.addr.sram_base;
        rp.regs.ppb.vtor = vectors_addr;

        const vectors = @intToPtr([*]usize, vectors_addr);
        asm volatile (
            \\.thumb
            // Set stack pointer
            // FIXME: RPi boot2 does this instead of mov and I'm not sure why
            \\  msr msp, %[stack_ptr]
            // \\  mov sp, %[stack_ptr]
            // Jump to entrypoint (ensuring Thumb mode)
            \\  bx %[entrypoint]
            :
            : [stack_ptr] "r" (vectors[0]),
              [entrypoint] "r" (vectors[1]),
        );

        unreachable;
    }
}
