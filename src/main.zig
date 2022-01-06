const std = @import("std");
const rp = @import("rp2040.zig");
const event = @import("event.zig");

comptime {
    rp.intr.exportVectors();
}
pub const _start = rp.intr._start;
pub const os = rp.os;

// FIXME: some weird shit is going on which means I can only compile in debug mode atm and sometimes it just doesn't work.
// Seems to be correlated with picotool displaying two "loading into flash" bars; cba to debug further atm

pub fn main() void {
    rp.regs.resets.unreset(&.{ .io_bank0, .pads_bank0 });

    const sio = rp.regs.sio;

    sio.gpio_oe.clear(25);
    sio.gpio_out.clear(25);

    rp.gpio.bank0_pad.gpio[25].write(.{}); // Ensure pad is in default state
    rp.gpio.bank0_io.gpio[25].ctrl.writeConst(.{ .funcsel = .sio });

    sio.gpio_oe.set(25);

    flash(3, 5);

    event.loop.spawn(mainTask, .{}) catch |err| @panic(@errorName(err));
    nosuspend {
        event.loop.run();
    }
}

pub fn mainTask() void {
    flash(3, 5);
    fibFlash() catch {};
    flash(20, 1);
}

pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace) noreturn {
    var msg_buf: [256]u8 = undefined;
    std.mem.copy(u8, &msg_buf, msg);
    std.mem.doNotOptimizeAway(msg_buf);
    while (true) {
        flash(5, 3);
    }
}

fn fibFlash() !void {
    flash(1, 1);

    // Create an array of fibonacci numbers
    var fibs = std.ArrayList(u32).init(std.heap.page_allocator);
    defer fibs.deinit();
    try fibs.append(0);
    try fibs.append(1);

    // When we inevitably OOM, flash relative to the number of fib numbers we calculated
    defer {
        flash(1, 20);
        flash(fibs.items.len / 10000, 10);
    }

    // Compute until we run out of space
    while (true) {
        const n = fibs.items.len;
        // Not really how fib works but we don't wanna overflow before we've properly tested the allocator
        try fibs.append(fibs.items[n - 1] +% fibs.items[n - 2]);
    }
}

fn flash(n: u32, strobe_speed: u32) void {
    const sio = rp.regs.sio;

    const delay_time = strobe_speed * 30000;

    var i: u32 = 0;
    while (i < n) : (i += 1) {
        sio.gpio_out.set(25);
        delay(delay_time);
        sio.gpio_out.clear(25);
        delay(delay_time);
    }

    delay(5 * delay_time);
}

fn delay(length: u32) void {
    var i: u32 = 0;
    while (i < length) : (i += 1) {
        std.mem.doNotOptimizeAway(i);
    }
}
