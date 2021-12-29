const std = @import("std");
const rp = @import("rp2040.zig");

comptime {
    rp.intr.exportVectors();
}
pub const _start = rp.intr._start;

pub fn main() void {
    rp.regs.resets.unreset(&.{ .io_bank0, .pads_bank0 });

    const sio = rp.regs.sio;

    sio.gpio_oe.clear(25);
    sio.gpio_out.clear(25);

    rp.gpio.bank0_pad.gpio[25].write(.{}); // Ensure pad is in default state
    rp.gpio.bank0_io.gpio[25].ctrl.writeConst(.{ .funcsel = .sio });

    sio.gpio_oe.set(25);

    while (true) {
        sio.gpio_out.flip(25);

        // ~500ms delay
        var i: u32 = 0;
        while (i < 50_000) : (i += 1) {
            std.mem.doNotOptimizeAway(i);
        }
    }
}
