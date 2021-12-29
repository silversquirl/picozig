const std = @import("std");
const host_endian = @import("builtin").cpu.arch.endian();

pub const Elf = struct {
    allocator: std.mem.Allocator,
    source: std.io.StreamSource,
    owned_file: ?std.fs.File = null,
    hdr: std.elf.Header,
    sections: []const std.elf.Elf64_Shdr,
    strtab: []const u8,

    pub fn open(allocator: std.mem.Allocator, path: []const u8) !Elf {
        // Open file
        const f = try std.fs.openFileAbsolute(path, .{});
        errdefer f.close();
        var source = std.io.StreamSource{ .file = f };

        // Read headers
        const hdr = try std.elf.Header.read(&source);
        const sections = try readSectionHeaders(allocator, &source, hdr);

        // Create elf struct so we can read the string table
        var self = Elf{
            .allocator = allocator,
            .source = source,
            .owned_file = f,

            .hdr = hdr,
            .sections = sections,
            .strtab = undefined,
        };

        // Read string table
        const strtab_sec = Section{ .elf = &self, .shdr = self.sections[self.hdr.shstrndx] };
        self.strtab = try strtab_sec.read(self.allocator);

        return self;
    }

    fn readSectionHeaders(
        allocator: std.mem.Allocator,
        source: *std.io.StreamSource,
        hdr: std.elf.Header,
    ) ![]const std.elf.Elf64_Shdr {
        const headers = try allocator.alloc(std.elf.Elf64_Shdr, hdr.shnum);
        errdefer allocator.free(headers);

        try source.seekTo(hdr.shoff);

        for (headers) |*shdr| {
            if (hdr.is_64) {
                try source.reader().readNoEof(std.mem.asBytes(shdr));

                if (hdr.endian != host_endian) {
                    std.mem.bswapAllFields(std.elf.Elf64_Shdr, shdr);
                }
            } else {
                var shdr32: std.elf.Elf32_Shdr = undefined;
                try source.reader().readNoEof(std.mem.asBytes(&shdr32));

                if (hdr.endian != host_endian) {
                    std.mem.bswapAllFields(std.elf.Elf32_Shdr, &shdr32);
                }

                inline for (comptime std.meta.fieldNames(std.elf.Elf64_Shdr)) |name| {
                    @field(shdr, name) = @field(shdr32, name);
                }
            }
        }

        return headers;
    }

    pub fn deinit(self: Elf) void {
        self.allocator.free(self.strtab);
        self.allocator.free(self.sections);
        if (self.owned_file) |owned_file| {
            owned_file.close();
        }
    }

    pub fn getSection(self: *Elf, section: []const u8) ?Section {
        for (self.sections) |shdr| {
            const name = std.mem.sliceTo(self.strtab[shdr.sh_name..], 0);
            if (std.mem.eql(u8, name, section)) {
                return Section{ .elf = self, .shdr = shdr };
            }
        }
        return null;
    }
};

pub const Section = struct {
    elf: *Elf,
    shdr: std.elf.Elf64_Shdr,

    pub fn read(self: Section, allocator: std.mem.Allocator) ![]const u8 {
        if (self.shdr.sh_type == std.elf.SHT_NOBITS) {
            return &[_]u8{};
        }

        const bytes = try allocator.alloc(u8, self.shdr.sh_size);
        errdefer allocator.free(bytes);
        var r = try self.reader();
        try r.reader().readNoEof(bytes);

        return bytes;
    }

    /// Valid until the source is seeked again
    pub fn reader(self: Section) !std.io.LimitedReader(std.io.StreamSource.Reader) {
        try self.elf.source.seekTo(self.shdr.sh_offset);
        return std.io.limitedReader(self.elf.source.reader(), self.shdr.sh_size);
    }

    /// Hashes the section with sha256 and returns the first 32 hex digits
    pub fn hash(self: Section) ![32]u8 {
        const Hasher = std.crypto.hash.sha2.Sha256;

        var hasher = Hasher.init(.{});
        var r = try self.reader();
        while (true) {
            var buf: [1024]u8 = undefined;
            const count = try r.read(&buf);
            if (count == 0) break;
            hasher.update(buf[0..count]);
        }

        var digest: [Hasher.digest_length]u8 = undefined;
        hasher.final(&digest);

        const hex_digits = "0123456789abcdef";
        var hex: [32]u8 = undefined;
        for (hex) |*x, i| {
            const nibble = if (i & 1 == 0)
                digest[i / 2] >> 4
            else
                digest[i / 2] & 0xf;
            x.* = hex_digits[nibble];
        }
        return hex;
    }
};
