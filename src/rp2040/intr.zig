//! Interrupt handlers

const std = @import("std");
const root = @import("root");
const addr = @import("addr.zig");
const heap = @import("heap.zig");
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

/// Disable interrupts. Returns previous state
pub inline fn disable() bool {
    const prev = asm (
        \\mrs %[prev], PRIMASK
        : [prev] "=r" (-> bool),
    );
    asm volatile ("cpsid i");
    return prev;
}
/// Enable interrupts. Returns previous state
pub inline fn enable() bool {
    const prev = asm (
        \\mrs %[prev], PRIMASK
        : [prev] "=r" (-> bool),
    );
    asm volatile ("cpsie i");
    return prev;
}
/// Restore interrupt mask
pub inline fn restore(mask: bool) void {
    asm volatile (
        \\msr PRIMASK, %[prev]
        :
        : [prev] "r" (mask),
    );
}
/// Wait for an interrupt to occur
pub inline fn wait() void {
    asm volatile ("wfi");
}

pub const VectorTable = extern struct {
    // Main stack pointer initial value
    sp_main: usize = addr.sram5_base,

    // Exceptions
    reset: Handler = _start,
    nmi: Handler = invalid("nmi"),
    hardfault: Handler = invalid("hardfault"),
    _resv0: [7]Handler = [1]Handler{invalid("resv0")} ** 7,
    svcall: Handler = invalid("svcall"),

    _resv1: [2]Handler = [1]Handler{invalid("resv1")} ** 2,

    // System interrupts
    pendsv: Handler = invalid("pendsv"),
    systick: Handler = invalid("systick"),

    // External interrupts
    timer_0: Handler = invalid("timer_0"),
    timer_1: Handler = invalid("timer_1"),
    timer_2: Handler = invalid("timer_2"),
    timer_3: Handler = invalid("timer_3"),
    pwm_wrap: Handler = invalid("pwm_wrap"),
    usbctrl: Handler = invalid("usbctrl"),
    xip: Handler = invalid("xip"),
    pio0_0: Handler = invalid("pio0_0"),
    pio0_1: Handler = invalid("pio0_1"),
    pio1_0: Handler = invalid("pio1_0"),
    pio1_1: Handler = invalid("pio1_1"),
    dma_0: Handler = invalid("dma_0"),
    dma_1: Handler = invalid("dma_1"),
    io_bank0: Handler = invalid("io_bank0"),
    io_qspi: Handler = invalid("io_qspi"),
    sio_proc0: Handler = invalid("sio_proc0"),
    sio_proc1: Handler = invalid("sio_proc1"),
    clocks: Handler = invalid("clocks"),
    spi0: Handler = invalid("spi0"),
    spi1: Handler = invalid("spi1"),
    uart0: Handler = invalid("uart0"),
    uart1: Handler = invalid("uart1"),
    adc_fifo: Handler = invalid("adc_fifo"),
    i2c0: Handler = invalid("i2c0"),
    i2c1: Handler = invalid("i2c1"),
    rtc: Handler = invalid("rtc"),

    pub const Handler = fn () callconv(.C) noreturn;

    comptime {
        std.debug.assert(@offsetOf(VectorTable, "reset") == 1 * 4);
        std.debug.assert(@offsetOf(VectorTable, "systick") == 15 * 4);
        std.debug.assert(@offsetOf(VectorTable, "timer_0") == (16 + 0) * 4);
        std.debug.assert(@offsetOf(VectorTable, "rtc") == (16 + 25) * 4);
    }
};

/// Invalid interrupt handler
fn invalid(comptime name: []const u8) fn () callconv(.C) noreturn {
    return struct {
        fn f() callconv(.C) noreturn {
            @breakpoint();
            @panic(std.fmt.comptimePrint("Invalid exception occurred: {s}", .{name}));
        }
    }.f;
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

    heap.init();

    root.main();
    while (true) {
        @breakpoint();
    }
}
