//! Interrupt handlers

const std = @import("std");
const root = @import("root");
const addr = @import("addr.zig");
const regs = @import("regs.zig");

pub var vectors linksection(".vectors") = std.meta.globalOption("vectors", VectorTable) orelse VectorTable{};
pub fn exportVectors() void {
    // Abuse type memoization to ensure this is only called once
    _ = ExportVectorsHelper();
}
fn ExportVectorsHelper() type {
    return struct {
        comptime {
            @export(vectors, .{ .name = "vectors", .section = ".vectors" });
        }
    };
}

pub const VectorTable = extern struct {
    // Main stack pointer initial value
    sp_main: usize = addr.sram5_base,

    // Exceptions
    reset: Handler = _start,
    nmi: Handler = invalid,
    hardfault: Handler = invalid,
    _resv0: [7]Handler = [1]Handler{invalid} ** 7,
    svcall: Handler = invalid,

    _resv1: [2]Handler = [1]Handler{invalid} ** 2,

    // System interrupts
    pendsv: Handler = invalid,
    systick: Handler = invalid,

    // External interrupts
    timer_0: Handler = invalid,
    timer_1: Handler = invalid,
    timer_2: Handler = invalid,
    timer_3: Handler = invalid,
    pwm_wrap: Handler = invalid,
    usbctrl: Handler = invalid,
    xip: Handler = invalid,
    pio0_0: Handler = invalid,
    pio0_1: Handler = invalid,
    pio1_0: Handler = invalid,
    pio1_1: Handler = invalid,
    dma_0: Handler = invalid,
    dma_1: Handler = invalid,
    io_bank0: Handler = invalid,
    io_qspi: Handler = invalid,
    sio_proc0: Handler = invalid,
    sio_proc1: Handler = invalid,
    clocks: Handler = invalid,
    spi0: Handler = invalid,
    spi1: Handler = invalid,
    uart0: Handler = invalid,
    uart1: Handler = invalid,
    adc_fifo: Handler = invalid,
    i2c0: Handler = invalid,
    i2c1: Handler = invalid,
    rtc: Handler = invalid,

    pub const Handler = fn () callconv(.C) void;
};

/// Invalid interrupt handler
fn invalid() callconv(.C) void {
    while (true) {
        @breakpoint();
    }
}

/// Default reset interrupt handler
pub export fn _start() callconv(.C) noreturn {
    // Reset all the things
    regs.resets.reset.setExcept(&.{
        // Disabling the CPU clock seems like a bad idea
        .pll_sys,

        // This would cause issues if we're booted from flash
        .io_qspi,
        .pads_qspi,

        // This would cause issues for pico-debug
        .pll_usb,
        .usbctrl,
        .syscfg,
    });

    // TODO: unreset stuff

    root.main();
    while (true) {
        @breakpoint();
    }
}
