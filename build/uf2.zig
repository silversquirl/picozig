//! UF2 build step
//!
//! This file contains a build step to generate a RP2040 UF2 file from an ELF binary
// TODO: finish this

const std = @import("std");

pub const InstallUf2Step = struct {
    step: std.build.Step,
    builder: *std.build.Builder,
    source: std.build.FileSource,
    name: []const u8,
    dest: std.build.GeneratedFile,

    pub fn init(
        builder: *std.build.Builder,
        source: std.build.FileSource,
        name: []const u8,
    ) *InstallUf2Step {
        const self = builder.allocator.create(InstallUf2Step) catch unreachable;
        self.* = .{
            .step = std.build.Step.init(
                .custom,
                builder.fmt("Install UF2 file {s}", .{name}),
                builder.allocator,
                make,
            ),
            .builder = builder,
            .source = source,
            .name = name,
            .dest = .{ .step = &self.step },
        };
        source.addStepDependencies(&self.step);
        return self;
    }

    pub fn getOutputSource(self: *const InstallUf2Step) std.build.FileSource {
        return .{ .generated = &self.dest };
    }

    fn make(step: *std.build.Step) !void {
        const self = @fieldParentPtr(InstallUf2Step, "step", step);

        const inpath = self.builder.pathFromRoot(self.source.getPath(self.builder));
        const outpath = self.builder.pathJoin(&.{
            self.builder.pathFromRoot(self.builder.install_prefix),
            self.name,
        });

        _ = try self.builder.execFromStep(&.{
            "./pico-sdk-1.3.0/tools/elf2uf2/elf2uf2",
            inpath,
            outpath,
        }, &self.step);

        // const inf = try std.fs.cwd().openFile(inpath, .{});
        // defer inf.close();
        // const ehdr = try std.elf.Header.read(inf);

        // if (ehdr.endian != .Little) {
        //     std.debug.print("ELF must be little-endian\n", .{});
        //     return error.BadElf;
        // }
        // if (ehdr.machine != ._ARM) {
        //     std.debug.print("ELF must target ARM\n", .{});
        //     return error.BadElf;
        // }
        // if (ehdr.is_64) {
        //     std.debug.print("ELF must be 32-bit\n", .{});
        //     return error.BadElf;
        // }

        // const outf = try std.fs.cwd().createFile(outpath, .{});
        // defer outf.close();
        // const uf2w = Uf2Writer(std.fs.File.Writer).init(outf.writer());
        // _ = uf2w;
    }
};

pub fn Uf2Writer(comptime Writer: type) type {
    return struct {
        w: Writer,
        buf: [512]u8 = undefined,
        idx: u10 = 0,
        blockn: u32 = 0,
        family_id: ?u32 = 0xe48bff56, // RP2040

        const magic0 = 0x0A324655;
        const magic1 = 0x9E5D5157;
        const magic2 = 0x0AB16F30;

        const Self = @This();

        pub fn init(w: Writer) Self {
            return .{ .w = w };
        }

        pub fn write(self: *Self, addr: u32, data: []const u8, flash: bool) !void {
            var i: u32 = 0;
            while (i < data.len) : (i += 256) {
                const j = std.math.min(data.len, i + 256);
                try self.writeBlock(addr + i, data[i..j], flash);
            }
        }

        fn writeBlock(self: *Self, addr: u32, data: []const u8, flash: bool) !void {
            const flags = Flags{
                .not_main_flash = !flash,
                .familyid_present = self.family_id != null,
            };

            self.begin();

            self.write32(magic0);
            self.write32(magic1);
            self.write32(@bitCast(u32, flags));
            self.write32(addr);
            self.write32(data.len);
            self.write32(self.blockn);
            self.write32(0xaaaa_aaaa); // Total blocks - we'll patch this in later
            self.write32(self.family_id orelse 0);

            // TODO: write data
            self.writeBytes(data);
            self.writeZeros(476 - data.len);

            self.write32(magic2);

            try self.end();

            self.blockn += 1;
        }

        inline fn begin(self: *Self) void {
            std.debug.assert(self.idx == 0);
        }
        inline fn end(self: *Self) !void {
            std.debug.assert(self.idx == 512);
            self.idx = 0;
            try self.w.writeAll(&self.buf);
        }

        inline fn write32(self: *Self, word: u32) void {
            std.mem.writeIntLittle(u32, self.buf[self.idx..][0..4], word);
            self.idx += 4;
        }
        inline fn writeBytes(self: *Self, bytes: []const u8) void {
            std.mem.copy(u8, self.buf[self.idx..], bytes);
            self.idx += bytes.len;
        }
        inline fn writeZeros(self: *Self, count: usize) void {
            std.mem.set(u8, self.buf[self.idx .. self.idx + count]);
            self.idx += count;
        }

        const Flags = packed struct {
            not_main_flash: bool = false,
            _pad0: u7 = 0,

            _pad1: u4 = 0,
            file_container: bool = false,
            familyid_present: bool = false,
            md5_checksum_present: bool = false,
            extension_tags_present: bool = false,

            _pad2: u8 = 0,
            _pad3: u8 = 0,

            comptime {
                std.debug.assert(@sizeOf(Flags) == @sizeOf(u32));
                std.debug.assert(@bitSizeOf(Flags) == @bitSizeOf(u32));
                std.debug.assert(@bitCast(u32, Flags{ .not_main_flash = true }) == 1);
            }
        };
    };
}
