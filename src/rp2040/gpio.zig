const std = @import("std");
const addr = @import("addr.zig");
const regs = @import("regs.zig");

pub const Bank0Io = extern struct {
    gpio: [30]IoPin,
    // TODO: interrupt registers
};
pub const bank0_io = @intToPtr(*volatile Bank0Io, addr.io_bank0_base);

pub const IoPin = extern struct {
    status: packed struct {
        _resv0: u8 align(4),
        out_from_peri: bool,
        out_to_pad: bool,
        _resv1: u2,
        oe_from_peri: bool,
        oe_to_pad: bool,
        _resv2: u3,
        in_from_pad: bool,
        _resv3: u1,
        in_to_peri: bool,
        _resv4: u4,
        irq_from_pad: bool,
        _resv5: u1,
        irq_to_proc: bool,
        _resv6: u5,

        comptime {
            std.debug.assert(@bitSizeOf(@This()) == 32);
        }
    },

    ctrl: regs.Register(packed struct {
        funcsel: enum(u5) {
            xip = 0,
            spi = 1,
            uart = 2,
            i2c = 3,
            pwm = 4,
            sio = 5,
            pio0 = 6,
            pio1 = 7,
            gpck = 8,
            usb = 9,
            none = 0x1f,
        } align(4),

        _resv0: u3 = 0,

        out_val: bool = false,
        out_over: bool = false,

        _resv1: u2 = 0,

        oe_val: bool = false,
        oe_over: bool = false,

        _resv2: u2 = 0,

        in_val: bool = false,
        in_over: bool = false,

        _resv3: u10 = 0,

        irq_val: bool = false,
        irq_over: bool = false,

        _resv4: u2 = 0,

        comptime {
            std.debug.assert(@bitSizeOf(@This()) == 32);
        }
    }),
};

pub const Bank0Pads = extern struct {
    voltage_select: Voltage,
    gpio: [30]Pad,
    swclk: Pad,
    swd: Pad,
};
pub const bank0_pad = @intToPtr(*volatile Bank0Pads, addr.pads_bank0_base);

pub const QspiPads = extern struct {
    voltage_select: Voltage,
    sclk: Pad,
    sd0: Pad,
    sd1: Pad,
    sd2: Pad,
    sd3: Pad,
    ss: Pad,
};
pub const qspi_pad = @intToPtr(*volatile QspiPads, addr.pads_qspi_base);

pub const Pad = regs.Register(packed struct {
    slewfast: bool align(4) = false,
    schmitt: bool = true,
    pde: bool = true,
    pue: bool = false,
    drive: DriveStrength = .@"4mA",
    ie: bool = true,
    od: bool = false,
});

pub const Voltage = enum(u32) {
    @"3v3" = 0,
    @"1v8" = 1,
};
pub const DriveStrength = enum(u2) {
    @"2mA" = 0,
    @"4mA" = 1,
    @"8mA" = 2,
    @"12mA" = 3,
};
