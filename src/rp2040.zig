//! Low-level interfaces for the RP2040

const std = @import("std");
const root = @import("root");

pub const addr = @import("rp2040/addr.zig");
pub const bootrom = @import("rp2040/bootrom.zig");
pub const gpio = @import("rp2040/gpio.zig");
pub const intr = @import("rp2040/intr.zig");
pub const regs = @import("rp2040/regs.zig");

pub const os = struct {
    pub const heap = @import("rp2040/heap.zig");
};
