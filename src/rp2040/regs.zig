const std = @import("std");
const addr = @import("addr.zig");

pub const ResetRegisters = extern struct {
    reset: Resets,
    wdsel: Resets,
    reset_done: Resets,

    pub fn unreset(self: *volatile ResetRegisters, fields: []const Resets.Field) void {
        self.reset.clear(fields);
        while (!self.reset_done.all(fields)) {}
    }

    pub const Resets = BitSet(enum {
        adc,
        busctrl,
        dma,
        i2c0,
        i2c1,
        io_bank0,
        io_qspi,
        jtag,
        pads_bank0,
        pads_qspi,
        pio0,
        pio1,
        pll_sys,
        pll_usb,
        pwm,
        rtc,
        spi0,
        spi1,
        syscfg,
        sysinfo,
        tbman,
        timer,
        uart0,
        uart1,
        usbctrl,
    });
};
pub const resets = @intToPtr(*volatile ResetRegisters, addr.resets_base);

pub const SioRegisters = extern struct {
    cpuid: u32,

    gpio_in: u32,
    gpio_hi_in: u32,
    _pad0: u32,

    gpio_out: Set,
    gpio_oe: Set,
    gpio_hi_out: Set,
    gpio_hi_oe: Set,

    // TODO: ...

    pub const Set = extern struct {
        val: u32,
        o_set: u32,
        o_clr: u32,
        o_xor: u32,

        pub fn get(self: *volatile Set, x: u5) bool {
            return @truncate(u1, self.val >> x) != 0;
        }
        pub fn set(self: *volatile Set, x: u5) void {
            const mask = @as(u32, 1) << x;
            self.o_set = mask;
        }
        pub fn clear(self: *volatile Set, x: u5) void {
            const mask = @as(u32, 1) << x;
            self.o_clr = mask;
        }
        pub fn flip(self: *volatile Set, x: u5) void {
            const mask = @as(u32, 1) << x;
            self.o_xor = mask;
        }
    };
};
pub const sio = @intToPtr(*volatile SioRegisters, addr.sio_base);

pub const PpbRegisters = RegisterTable(.{
    // TODO: register types

    .syst_csr = .{ 0x010, u32 },
    .syst_rvr = .{ 0x014, u32 },
    .syst_cvr = .{ 0x018, u32 },
    .syst_calib = .{ 0x01c, u32 },

    .nvic_iser = .{ 0x100, u32 },
    .nvic_icer = .{ 0x180, u32 },
    .nvic_ispr = .{ 0x200, u32 },
    .nvic_icpr = .{ 0x280, u32 },
    .nvic_ipr0 = .{ 0x400, u32 },
    .nvic_ipr1 = .{ 0x404, u32 },
    .nvic_ipr2 = .{ 0x408, u32 },
    .nvic_ipr3 = .{ 0x40c, u32 },
    .nvic_ipr4 = .{ 0x410, u32 },
    .nvic_ipr5 = .{ 0x414, u32 },
    .nvic_ipr6 = .{ 0x418, u32 },
    .nvic_ipr7 = .{ 0x41c, u32 },

    .cpuid = .{ 0xd00, u32 },
    .icsr = .{ 0xd04, u32 },
    .vtor = .{ 0xd08, u32 },
    .aircr = .{ 0xd0c, u32 },
    .scr = .{ 0xd10, u32 },
    .ccr = .{ 0xd14, u32 },
    .shpr2 = .{ 0xd1c, u32 },
    .shpr3 = .{ 0xd20, u32 },
    .shcsr = .{ 0xd24, u32 },

    .mpu_type = .{ 0xd90, u32 },
    .mpu_ctrl = .{ 0xd94, u32 },
    .mpu_rnr = .{ 0xd98, u32 },
    .mpu_rbar = .{ 0xd9c, u32 },
    .mpu_rasr = .{ 0xda0, u32 },
});
pub const ppb = @intToPtr(*volatile PpbRegisters, addr.ppb_base + 0xe000);

pub const XipSsiRegisters = RegisterTable(.{
    // TODO: register types

    .ctrlr0 = .{
        0x00, Register(packed struct {
            // TODO: enums
            dfs: u4 align(4) = 0,
            frf: u2 = 0,
            scph: u1 = 0,
            scpol: u1 = 0,
            tmod: enum(u2) { txrx, tx, rx, eeprom } = 0,
            slv_oe: bool = false,
            srl: u1 = 0,
            cfs: u4 = 0,
            dfs_32: u5 = 0,
            spi_frf: enum(u2) { single, dual, quad } = .single,
            _resv0: u1 = 0,
            sste: u1 = 0,
        }),
    },

    .ctrlr1 = .{ 0x04, Register(packed struct {
        ndf: u16 align(4) = 0,
    }) },

    .ssienr = .{ 0x08, u32 },
    .mwcr = .{ 0x0c, u32 },
    .ser = .{ 0x10, u32 },
    .baudr = .{ 0x14, u32 },
    .txftlr = .{ 0x18, u32 },
    .rxftlr = .{ 0x1c, u32 },
    .txflr = .{ 0x20, u32 },
    .rxflr = .{ 0x24, u32 },
    .sr = .{ 0x28, u32 },
    .imr = .{ 0x2c, u32 },
    .isr = .{ 0x30, u32 },
    .risr = .{ 0x34, u32 },
    .txoicr = .{ 0x38, u32 },
    .rxoicr = .{ 0x3c, u32 },
    .rxuicr = .{ 0x40, u32 },
    .msticr = .{ 0x44, u32 },
    .icr = .{ 0x48, u32 },
    .dmacr = .{ 0x4c, u32 },
    .dmatdlr = .{ 0x50, u32 },
    .dmardlr = .{ 0x54, u32 },
    .idr = .{ 0x58, u32 },
    .ssi_version_id = .{ 0x5c, u32 },
    .dr0 = .{ 0x60, u32 },
    .rx_sample_dly = .{ 0xf0, u32 },

    .spi_ctrlr0 = .{
        0xf4, Register(packed struct {
            // TODO: enums
            trans_type: enum(u2) { std, std_frf, frf } align(4) = 0,
            addr_l: u4 = 0, // multiples of 4
            _resv0: u2 = 0,
            inst_l: enum(u2) { none, @"4bit", @"8bit", @"16bit" } = .none,
            _resv1: u1 = 0,
            wait_cycles: u5 = 0,
            spi_ddr_en: bool = false,
            inst_ddr_en: bool = false,
            spi_rxds_en: bool = false,
            _resv2: u5 = 0,
            xip_cmd: u8 = 0,
        }),
    },

    .txd_drive_edge = .{ 0xf8, u32 },
});
pub const xip_ssi = @intToPtr(*volatile XipSsiRegisters, addr.xip_ssi_base);

pub fn RegisterTable(comptime desc: anytype) type {
    var reg_names = std.meta.fieldNames(@TypeOf(desc));
    const max_offset = @field(desc, reg_names[reg_names.len - 1])[0];

    var fields: [max_offset / 4]std.builtin.TypeInfo.StructField = undefined;

    var reg_i = 0;
    var pad_i = 0;
    for (fields) |*field, field_i| {
        var name = reg_names[reg_i];
        const rdesc = @field(desc, name);
        if (field_i * 4 == rdesc[0]) {
            reg_i += 1;
        } else {
            name = std.fmt.comptimePrint("_pad_{}", .{pad_i});
            pad_i += 1;
        }

        field.* = .{
            .name = name,
            .field_type = rdesc[1],
            .default_value = null,
            .is_comptime = false,
            .alignment = @alignOf(rdesc[1]),
        };
    }

    return @Type(.{ .Struct = .{
        .layout = .Extern,
        .fields = &fields,
        .decls = &.{},
        .is_tuple = false,
    } });
}

pub fn Register(comptime FieldsType: type) type {
    std.debug.assert(@bitSizeOf(FieldsType) <= 32);
    return extern struct {
        reg: u32,

        pub const Fields = FieldsType;
        const FieldsInt = std.meta.Int(.unsigned, @bitSizeOf(Fields));
        const Self = @This();

        pub inline fn read(self: *const volatile Self) Fields {
            return @bitCast(Fields, @intCast(FieldsInt, self.reg));
        }
        pub inline fn write(self: *volatile Self, fields: Fields) void {
            self.reg = @bitCast(FieldsInt, fields);
        }
        pub inline fn update(self: *volatile Self, fields: anytype) void {
            var copy = self.read();
            inline for (comptime std.meta.fieldNames(@TypeOf(fields))) |name| {
                @field(copy, name) = @field(fields, name);
            }
            self.write(copy);
        }

        // FIXME: This shouldn't be needed. Zig and/or LLVM should be able to optimize write, but
        //        we might need to wait for stage2 inline function semantics (see ziglang/zig#7772)
        pub inline fn writeConst(self: *volatile Self, comptime fields: Fields) void {
            self.reg = comptime @bitCast(FieldsInt, fields);
        }
    };
}

pub fn BitSet(comptime FieldType: type) type {
    return extern struct {
        bits: u32,

        pub const Field = FieldType;
        const Self = @This();
        const reg_mask: u32 = (1 << std.meta.fields(FieldType).len) - 1;

        inline fn mask(fields: []const Field) u32 {
            var m: u32 = 0;
            for (fields) |f| {
                m |= @as(u32, 1) << @enumToInt(f);
            }
            return m;
        }

        pub inline fn any(self: *const volatile Self, fields: []const Field) bool {
            return self.bits & mask(fields) != 0;
        }
        pub inline fn all(self: *const volatile Self, fields: []const Field) bool {
            const m = mask(fields);
            return self.bits & m == m;
        }

        pub inline fn set(self: *volatile Self, fields: []const Field) void {
            self.bits |= mask(fields);
        }
        pub inline fn setExcept(self: *volatile Self, fields: []const Field) void {
            self.bits |= mask(fields) ^ reg_mask;
        }

        pub inline fn clear(self: *volatile Self, fields: []const Field) void {
            self.bits &= mask(fields) ^ reg_mask;
        }
        pub inline fn clearExcept(self: *volatile Self, fields: []const Field) void {
            self.bits &= mask(fields);
        }
    };
}
