const std = @import("std");
const addr = @import("addr.zig");
const intr = @import("intr.zig");

const Allocator = std.mem.Allocator;

pub const page_size: usize = std.mem.page_size;
const max_memory_size = addr.sram4_base - addr.sram_base;

extern var _program_end: anyopaque;

pub fn init() void {
    const memory_base = @ptrToInt(&_program_end);
    // Round upwards to multiple of page size
    const memory_start = -%(-%memory_base & -%page_size);

    // SRAM4 is the end of the striped memory area
    // We end here because we use SRAM4 and SRAM5 as stack
    const memory_end = addr.sram4_base - memory_start;

    global_page_alloc = .{
        .memory = @intToPtr([*]u8, memory_start)[0..memory_end],
    };
}

var global_page_alloc: PageAllocator = undefined;
pub const page_allocator = global_page_alloc.allocator();

/// General purpose page allocator that allocates from a given buffer.
/// FIXME: Not thread-safe. Cannot be used from interrupts.
pub const PageAllocator = struct {
    free_set: PageSet = PageSet.initFull(),
    memory: []u8,

    const PageSet = std.StaticBitSet(@divExact(max_memory_size, page_size));

    pub fn allocator(self: *PageAllocator) Allocator {
        return Allocator.init(self, alloc, resize, free);
    }

    // TODO: memory protection

    fn alloc(self: *PageAllocator, len: usize, ptr_align: u29, len_align: u29, ret_addr: usize) ![]u8 {
        _ = ret_addr;

        // TODO: alignment
        std.debug.assert(ptr_align <= page_size);
        std.debug.assert(len_align <= page_size);
        std.debug.assert(page_size % ptr_align == 0);
        std.debug.assert(len_align == 0 or page_size % len_align == 0);

        const page_len = (len - 1) / page_size + 1;
        if (page_len > @divExact(self.memory.len, page_size)) {
            return error.OutOfMemory;
        }

        var n: usize = 0;
        var start: usize = 0;
        var it = self.free_set.iterator(.{});
        while (it.next()) |i| {
            if (start + n < i) {
                n = 0;
                start = i;
            }
            n += 1;
            if (n >= page_len) {
                break;
            }
        } else {
            return error.OutOfMemory;
        }

        const start_byte = start * page_size;
        const len_bytes = if (len_align == 0) len else (n * page_size);
        const end_byte = start_byte + len_bytes;
        const mem = self.memory[start_byte..end_byte];

        while (n > 0) {
            n -= 1;
            std.debug.assert(self.free_set.isSet(start + n));
            self.free_set.unset(start + n);
        }

        return mem;
    }

    fn resize(self: *PageAllocator, buf: []u8, buf_align: u29, new_len: usize, len_align: u29, ret_addr: usize) ?usize {
        _ = ret_addr;
        _ = buf_align;

        // TODO: alignment
        std.debug.assert(len_align <= page_size);
        std.debug.assert(len_align == 0 or page_size % len_align == 0);

        const start = self.addrToPage(buf.ptr);
        const old_n = (buf.len - 1) / page_size + 1;
        const new_n = (new_len - 1) / page_size + 1;
        if (new_n > @divExact(self.memory.len, page_size)) {
            return null;
        }

        var n = old_n;
        while (n < new_n) : (n += 1) {
            if (!self.free_set.isSet(start + n)) {
                return null;
            }
        }

        while (n > old_n) {
            n -= 1;
            std.debug.assert(self.free_set.isSet(start + n));
            self.free_set.unset(start + n);
        }

        return if (len_align == 0) new_len else new_n * page_size;
    }

    fn free(self: *PageAllocator, buf: []u8, buf_align: u29, ret_addr: usize) void {
        _ = ret_addr;
        _ = buf_align;

        const start = self.addrToPage(buf.ptr);
        var n = (buf.len - 1) / page_size + 1;
        while (n > 0) {
            n -= 1;
            std.debug.assert(!self.free_set.isSet(start + n));
            self.free_set.set(start + n);
        }
    }

    fn addrToPage(self: PageAllocator, ptr: [*]u8) usize {
        return @divExact(@ptrToInt(ptr) - @ptrToInt(self.memory.ptr), page_size);
    }
};
