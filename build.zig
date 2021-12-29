const std = @import("std");
const elf = @import("build/elf.zig");
const uf2 = @import("build/uf2.zig");

pub fn build(b: *std.build.Builder) void {
    const target = std.zig.CrossTarget.parse(.{
        .arch_os_abi = "thumb-freestanding",
        .cpu_features = "cortex_m0plus",
    }) catch unreachable;
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("main.elf", "src/main.zig");
    addBoot2(b, exe, target, "copy2ram");
    exe.want_lto = false;
    exe.linker_script = std.build.FileSource.relative("src/linker.ld");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();
    // const uf2_step = uf2.InstallUf2Step.init(b, exe.getOutputSource(), "main.uf2");
    // b.getInstallStep().dependOn(&uf2_step.step);
}

fn addBoot2(b: *std.build.Builder, exe: *std.build.LibExeObjStep, target: std.zig.CrossTarget, variant: []const u8) void {
    const rp_pkg = std.build.Pkg{
        .name = "rp2040",
        .path = std.build.FileSource.relative("src/rp2040.zig"),
    };

    const impl = b.addObject(variant, b.fmt("src/boot2/{s}.zig", .{variant}));
    impl.addPackage(rp_pkg);

    impl.force_pic = true;
    impl.setTarget(target);
    impl.setBuildMode(.ReleaseSmall);

    const checksum = Boot2ChecksumStep.init(b, impl);

    const check = b.addObjectSource(
        b.fmt("{s}_checksum", .{variant}),
        std.build.FileSource{ .generated = &checksum.output },
    );

    check.force_pic = true;
    check.setBuildMode(.ReleaseSmall);
    check.setTarget(target);

    exe.addObject(impl);
    exe.addObject(check);

    // TODO: figure out why static libs make custom sections disappear
    // const lib = b.addStaticLibrary("boot2", null);
    // lib.addObject(impl);
    // lib.addObject(check);
    // exe.linkLibrary(lib);
}

const Boot2ChecksumStep = struct {
    builder: *std.build.Builder,
    step: std.build.Step,
    obj: *std.build.LibExeObjStep,
    output: std.build.GeneratedFile,

    pub fn init(b: *std.build.Builder, obj: *std.build.LibExeObjStep) *Boot2ChecksumStep {
        const self = b.allocator.create(Boot2ChecksumStep) catch unreachable;
        self.* = .{
            .builder = b,
            .step = std.build.Step.init(
                .custom,
                b.fmt("compute checksum for {s}", .{obj.name}),
                b.allocator,
                make,
            ),
            .obj = obj,
            .output = .{ .step = &self.step },
        };
        self.step.dependOn(&obj.step);
        return self;
    }

    fn make(step: *std.build.Step) !void {
        const self = @fieldParentPtr(Boot2ChecksumStep, "step", step);

        // Open ELF file
        var obj_elf = try elf.Elf.open(
            self.builder.allocator,
            self.obj.getOutputSource().getPath(self.builder),
        );
        defer obj_elf.deinit();
        const boot2_sec = obj_elf.getSection(".boot2").?;

        // Read and pad data
        var data = std.mem.zeroes([252]u8);
        var r = try boot2_sec.reader();
        _ = try r.reader().readAll(&data);

        // Compute checksum
        // RP2040 bootrom uses an unusual variant of CRC32, where everything is flipped and reversed
        var crc = std.hash.crc.Crc32.init();
        for (data) |b| {
            crc.update(&.{@bitReverse(u8, b)});
        }
        const checksum = ~@bitReverse(u32, crc.final());

        // Compute output filename
        const out_dir = self.builder.pathFromRoot(
            self.builder.pathJoin(&.{ self.builder.cache_root, "boot2_checksum" }),
        );
        const out_name = self.builder.fmt("{s}-{s}.zig", .{ self.obj.name, try boot2_sec.hash() });
        const out_path = self.builder.pathJoin(&.{ out_dir, out_name });

        // Write output
        try std.fs.cwd().makePath(out_dir);
        const f = try std.fs.createFileAbsolute(out_path, .{});
        defer f.close();
        try f.writer().print(
            \\export const boot2_pad linksection(".boot2.pad") = [1]u8{{0}} ** {};
            \\export const boot2_checksum: u32 linksection(".boot2.checksum") = 0x{x:0>8};
            \\
        , .{ 252 - boot2_sec.shdr.sh_size, checksum });

        // Set generated file
        self.output.path = out_path;
    }
};
