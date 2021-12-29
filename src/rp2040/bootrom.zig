//! Bootrom library interface
//!
//! The RP2040 has a 16k bootrom that contains some useful functions.
//! This file provides interfaces to those functions.
const std = @import("std");
const root = @import("root");

pub var version: u8 = undefined; // Boot ROM version

pub fn init() void {
    // Check magic
    if (!bootrom.validateMagic()) {
        @panic("Invalid magic");
    }

    // Store bootrom version
    version = bootrom.version;

    // TODO: Load functions and data
}

pub fn panic(msg: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
    _ = msg;
    _ = stack_trace;
    @breakpoint();
    while (true) {
        asm volatile ("wfi");
    }
}

const BootromHeader = extern struct {
    stack_ptr: u32,
    boot_reset_handler: u32,
    boot_nmi_handler: u32,
    boot_hardfault_handler: u32,

    magic: [3]u8,
    version: u8,

    func_table: u16,
    data_table: u16,
    table_lookup_fun: u16,

    const SelfPtr = *allowzero const BootromHeader;

    pub inline fn validateMagic(self: SelfPtr) bool {
        return self.magic[0] == 'M' and
            self.magic[1] == 'u' and
            self.magic[2] == '\x01';
    }

    pub inline fn lookup(self: SelfPtr, comptime T: type, table: u16, code: *const [2]u8) T {
        const table_ptr = @intToPtr([*]const u16, table);
        const id = code[0] | @as(u16, code[1]) << 8;
        const tableLookupFn = @intToPtr(fn ([*]const u16, u32) *anyopaque, self.table_lookup_fun);
        const result = tableLookupFn(table_ptr, id);
        return @ptrCast(T, result);
    }
};

/// DO NOT USE unless you know what you're doing. Only exposed to save a bit of space in boot2
pub const bootrom = @intToPtr(*allowzero const BootromHeader, 0x0000_0000);
