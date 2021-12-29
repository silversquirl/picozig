//! This file handles checksumming and linking of the boot stage2
//! It requires very special build settings; see build.zig for more info

const std = @import("std");
const impls = @import("impls");
// const impls = struct {
//     pub const copy2ram = "/home/silver/Downloads/boot2_ram_memcpy.bin";
// };

// This file is technically the entrypoint, but @root contains the actual entrypoint
pub usingnamespace @import("@root");

const impl = std.meta.globalOption("boot2_impl", DeclEnum(impls)) orelse .copy2ram;

export const boot2: [256]u8 linksection(".boot2") = blk: {
    const path = @field(impls, @tagName(impl));
    const code = @embedFile(path).*;

    const padding = [1]u8{0} ** (252 - code.len);
    const padded: [252]u8 = code ++ padding;

    // RP2040 bootrom uses an unusual variant of CRC32, where everything is flipped and reversed
    var crc = std.hash.crc.Crc32.init();
    for (padded) |b| {
        crc.update(&.{@bitReverse(u8, b)});
    }
    const final = ~@bitReverse(u32, crc.final());
    break :blk padded ++ std.mem.toBytes(final);
};

fn DeclEnum(comptime ns: type) type {
    const decls = std.meta.declarations(ns);
    var fields: [decls.len]std.builtin.TypeInfo.EnumField = undefined;
    for (decls) |decl, i| {
        fields[i] = .{
            .name = decl.name,
            .value = i,
        };
    }
    return @Type(.{ .Enum = .{
        .layout = .Auto,
        .tag_type = std.math.IntFittingRange(0, fields.len - 1),
        .fields = &fields,
        .decls = &.{},
        .is_exhaustive = true,
    } });
}
