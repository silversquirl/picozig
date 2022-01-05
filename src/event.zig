const std = @import("std");
const rp = @import("rp2040.zig");
const Atomic = std.atomic.Atomic;

const task_limit = std.meta.globalOption("picozig_task_limit", usize) orelse 1024;

// TODO: think about multicore

pub const Loop = struct {
    allocator: std.mem.Allocator,
    parent: ?*Loop = null,

    ntask: usize = 0, // Number of tasks currently active on the event loop
    should_wake: Atomic(bool) = Atomic(bool).init(false), // Whether the loop has unprocessed events
    wait_q: TaskQueue = TaskQueue.init(), // All tasks waiting for some event
    cpu_q: TaskQueue = TaskQueue.init(), // All tasks that have simply yielded and are not waiting

    const TaskQueue = std.fifo.LinearFifo(anyframe, .{ .Static = task_limit });

    /// Spawn a new async task
    pub fn spawn(self: *Loop, comptime func: anytype, args: std.meta.ArgsTuple(@TypeOf(func))) !void {
        if (self.taskCount() >= task_limit) return error.OutOfMemory;

        const spawner = struct {
            fn f(self_: *Loop, args_: std.meta.ArgsTuple(@TypeOf(func))) noreturn {
                suspend {}
                @call(.{}, func, args_);
                suspend {
                    self_.allocator.destroy(@frame());
                }
                unreachable;
            }
        }.f;
        const frame = try self.allocator.create(@Frame(spawner));
        frame.* = async spawner(self, args);
        self.cpu_q.writeItemAssumeCapacity(frame);
    }

    /// Pause the current task until an event occurs
    pub fn wait(self: *Loop) void {
        suspend {
            self.wait_q.writeItemAssumeCapacity(@frame());
        }
    }

    /// Yield the current task to allow other tasks to process
    pub fn yield(self: *Loop) void {
        suspend {
            self.cpu_q.writeItemAssumeCapacity(@frame());
        }
    }

    /// Wake the event loop in response to an event
    pub fn wake(self: *Loop) void {
        self.should_wake.store(true, .Release);
    }

    /// Process events until all tasks have run to completion
    pub fn run(self: *Loop) void {
        while (self.taskCount() > 0) {
            // If there are new events, execute wait tasks
            if (self.should_wake.load(.Acquire)) {
                self.should_wake.store(false, .Release);
                while (self.wait_q.readItem()) |task| {
                    resume task;
                }
            }

            if (self.cpu_q.readItem()) |task| {
                // If we have any CPU tasks, execute one
                // We do these one at a time in order to give wait tasks priority
                resume task;

                // Yield to parent, if any
                if (self.parent) |parent| {
                    parent.yield();
                }
            } else if (self.parent) |parent| {
                // If we have a parent, defer to that loop
                parent.wait();
            } else {
                // Otherwise, wait for events from interrupts
                const mask = rp.intr.disable();
                defer rp.intr.restore(mask);
                while (!self.should_wake.load(.Monotonic)) {
                    rp.intr.wait();
                    // Allow interrupt handlers to execute
                    _ = rp.intr.enable();
                    _ = rp.intr.disable();
                }
            }
        }
    }

    inline fn taskCount(self: Loop) usize {
        return self.wait_q.readableLength() + self.cpu_q.readableLength();
    }
};

var loop_alloc = std.heap.GeneralPurposeAllocator(.{}){};
pub var loop = Loop{
    .allocator = loop_alloc.allocator(),
};
