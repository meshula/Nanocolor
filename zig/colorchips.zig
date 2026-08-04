//! Color Chip Generator for Nanocolor Zig
//!
//! Generates SMPTE 2065-1 / ACES color chips and reference patterns
//! in any nanocolor color space.
//! 
//! License: MIT
//! Copyright (c) 2025 Nick Porcino
//! Permission is hereby granted, free of charge, to any person obtaining a copy
//! of this software and associated documentation files (the "Software"), to deal
//! in the Software without restriction, including without limitation the rights
//! to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//! copies of the Software, and to permit persons to whom the Software is
//! furnished to do so, subject to the following conditions:
//! //! The above copyright notice and this permission notice shall be included in
//! // all copies or substantial portions of the Software.
//! //! THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//! // IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//! //! // FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//! // AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//! // LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//! //! // OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//! // THE SOFTWARE.
//! 

const std = @import("std");
const nanocolor = @import("nanocolor.zig");
const print = std.debug.print;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

// MARK: - Color Chip Structures

pub const ColorChip = struct {
    name: []const u8,
    rgb: nanocolor.RGB,
    description: []const u8,

    pub fn init(name: []const u8, rgb: nanocolor.RGB, description: []const u8) ColorChip {
        return ColorChip{
            .name = name,
            .rgb = rgb,
            .description = description,
        };
    }

    pub fn format(self: ColorChip, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("{s}: RGB({d:.6}, {d:.6}, {d:.6})", .{ self.name, self.rgb.r, self.rgb.g, self.rgb.b });
    }
};

pub const ColorChipSet = struct {
    name: []const u8,
    color_space: []const u8,
    chips: []const ColorChip,

    pub fn init(name: []const u8, color_space: []const u8, chips: []const ColorChip) ColorChipSet {
        return ColorChipSet{
            .name = name,
            .color_space = color_space,
            .chips = chips,
        };
    }

    pub fn transformTo(self: ColorChipSet, allocator: Allocator, target_space: []const u8, lib: *nanocolor.ColorSpaceLibrary) !ColorChipSet {
        const src_space = lib.getNamedColorSpace(self.color_space) orelse return error.UnknownSourceColorSpace;
        const dst_space = lib.getNamedColorSpace(target_space) orelse return error.UnknownTargetColorSpace;

        var transformed_chips = ArrayList(ColorChip).init(allocator);
        defer transformed_chips.deinit();

        for (self.chips) |chip| {
            const transformed_rgb = try nanocolor.transformColor(dst_space, src_space, chip.rgb);
            try transformed_chips.append(ColorChip.init(chip.name, transformed_rgb, chip.description));
        }

        const owned_chips = try transformed_chips.toOwnedSlice();
        return ColorChipSet.init(self.name, target_space, owned_chips);
    }

    pub fn toCSV(self: ColorChipSet, allocator: Allocator) ![]u8 {
        var lines = ArrayList([]const u8).init(allocator);
        defer lines.deinit();

        const header1 = try std.fmt.allocPrint(allocator, "# {s} in {s}", .{ self.name, self.color_space });
        try lines.append(header1);
        try lines.append("Name,R,G,B,Description");

        for (self.chips) |chip| {
            const line = try std.fmt.allocPrint(allocator, "{s},{d},{d},{d},{s}", .{ chip.name, chip.rgb.r, chip.rgb.g, chip.rgb.b, chip.description });
            try lines.append(line);
        }

        return std.mem.join(allocator, "\n", lines.items);
    }

    pub fn toJSON(self: ColorChipSet, allocator: Allocator) ![]u8 {
        var json_lines = ArrayList([]const u8).init(allocator);
        defer json_lines.deinit();

        try json_lines.append("{");
        const name_line = try std.fmt.allocPrint(allocator, "  \"name\": \"{s}\",", .{self.name});
        try json_lines.append(name_line);
        const space_line = try std.fmt.allocPrint(allocator, "  \"color_space\": \"{s}\",", .{self.color_space});
        try json_lines.append(space_line);
        try json_lines.append("  \"chips\": [");

        for (self.chips, 0..) |chip, i| {
            const comma = if (i < self.chips.len - 1) "," else "";
            const chip_line = try std.fmt.allocPrint(allocator, "    {{\"name\": \"{s}\", \"rgb\": [{d}, {d}, {d}], \"description\": \"{s}\"}}{s}", .{ chip.name, chip.rgb.r, chip.rgb.g, chip.rgb.b, chip.description, comma });
            try json_lines.append(chip_line);
        }

        try json_lines.append("  ]");
        try json_lines.append("}");

        return std.mem.join(allocator, "\n", json_lines.items);
    }

    pub fn toText(self: ColorChipSet, allocator: Allocator) ![]u8 {
        var lines = ArrayList([]const u8).init(allocator);
        defer lines.deinit();

        const header = try std.fmt.allocPrint(allocator, "# {s} in {s}", .{ self.name, self.color_space });
        try lines.append(header);
        try lines.append("============================================================");

        for (self.chips) |chip| {
            const chip_line = try std.fmt.allocPrint(allocator, "{}", .{chip});
            try lines.append(chip_line);
            if (chip.description.len > 0) {
                const desc_line = try std.fmt.allocPrint(allocator, "    {s}", .{chip.description});
                try lines.append(desc_line);
            }
        }

        try lines.append("");
        const total_line = try std.fmt.allocPrint(allocator, "Total: {d} color chips", .{self.chips.len});
        try lines.append(total_line);

        return std.mem.join(allocator, "\n", lines.items);
    }
};

// MARK: - Predefined Color Chip Sets

const acescg_colorchecker_chips = [_]ColorChip{
    // Row 1 (top)
    ColorChip.init("dark_skin", nanocolor.RGB.init(0.4325, 0.3127, 0.2411), "ColorChecker patch 1"),
    ColorChip.init("light_skin", nanocolor.RGB.init(0.7787, 0.5925, 0.4733), "ColorChecker patch 2"),
    ColorChip.init("blue_sky", nanocolor.RGB.init(0.3570, 0.4035, 0.5733), "ColorChecker patch 3"),
    ColorChip.init("foliage", nanocolor.RGB.init(0.3369, 0.4219, 0.2797), "ColorChecker patch 4"),
    ColorChip.init("blue_flower", nanocolor.RGB.init(0.5479, 0.5434, 0.8156), "ColorChecker patch 5"),
    ColorChip.init("bluish_green", nanocolor.RGB.init(0.4708, 0.7749, 0.6411), "ColorChecker patch 6"),

    // Row 2
    ColorChip.init("orange", nanocolor.RGB.init(0.9309, 0.4471, 0.1330), "ColorChecker patch 7"),
    ColorChip.init("purplish_blue", nanocolor.RGB.init(0.2906, 0.3299, 0.6549), "ColorChecker patch 8"),
    ColorChip.init("moderate_red", nanocolor.RGB.init(0.7285, 0.3447, 0.4019), "ColorChecker patch 9"),
    ColorChip.init("purple", nanocolor.RGB.init(0.3174, 0.2210, 0.3394), "ColorChecker patch 10"),
    ColorChip.init("yellow_green", nanocolor.RGB.init(0.6157, 0.8067, 0.2482), "ColorChecker patch 11"),
    ColorChip.init("orange_yellow", nanocolor.RGB.init(0.9847, 0.7369, 0.1090), "ColorChecker patch 12"),

    // Row 3
    ColorChip.init("blue", nanocolor.RGB.init(0.2131, 0.2373, 0.6580), "ColorChecker patch 13"),
    ColorChip.init("green", nanocolor.RGB.init(0.2744, 0.5175, 0.2297), "ColorChecker patch 14"),
    ColorChip.init("red", nanocolor.RGB.init(0.6910, 0.1926, 0.1395), "ColorChecker patch 15"),
    ColorChip.init("yellow", nanocolor.RGB.init(0.9892, 0.9011, 0.1060), "ColorChecker patch 16"),
    ColorChip.init("magenta", nanocolor.RGB.init(0.7380, 0.3039, 0.6192), "ColorChecker patch 17"),
    ColorChip.init("cyan", nanocolor.RGB.init(0.1864, 0.6377, 0.7554), "ColorChecker patch 18"),

    // Row 4 (grayscale)
    ColorChip.init("white", nanocolor.RGB.init(0.9131, 0.9131, 0.9131), "ColorChecker patch 19 - White"),
    ColorChip.init("neutral_8", nanocolor.RGB.init(0.5894, 0.5894, 0ColorChip.init("neutral_8", nanocolor.RGB.init(0.5894, 0.5894, 0.5894), "ColorChecker patch 20 - 80% gray"),
    ColorChip.init("neutral_65", nanocolor.RGB.init(0.3668, 0.3668, 0.3668), "ColorChecker patch 21 - 65% gray"),
    ColorChip.init("neutral_5", nanocolor.RGB.init(0.1903, 0.1903, 0.1903), "ColorChecker patch 22 - 50% gray (18%)"),
    ColorChip.init("neutral_35", nanocolor.RGB.init(0.0898, 0.0898, 0.0898), "ColorChecker patch 23 - 35% gray"),
    ColorChip.init("black", nanocolor.RGB.init(0.0313, 0.0313, 0.0313), "ColorChecker patch 24 - Black"),
};

const smpte_color_bars = [_]ColorChip{
    ColorChip.init("white", nanocolor.RGB.init(1.0, 1.0, 1.0), "100% white"),
    ColorChip.init("yellow", nanocolor.RGB.init(1.0, 1.0, 0.0), "100% yellow"),
    ColorChip.init("cyan", nanocolor.RGB.init(0.0, 1.0, 1.0), "100% cyan"),
    ColorChip.init("green", nanocolor.RGB.init(0.0, 1.0, 0.0), "100% green"),
    ColorChip.init("magenta", nanocolor.RGB.init(1.0, 0.0, 1.0), "100% magenta"),
    ColorChip.init("red", nanocolor.RGB.init(1.0, 0.0, 0.0), "100% red"),
    ColorChip.init("blue", nanocolor.RGB.init(0.0, 0.0, 1.0), "100% blue"),
    ColorChip.init("black", nanocolor.RGB.init(0.0, 0.0, 0.0), "0% black"),
};

const grayscale_patches = [_]ColorChip{
    ColorChip.init("white_100", nanocolor.RGB.init(1.0, 1.0, 1.0), "100% white"),
    ColorChip.init("gray_90", nanocolor.RGB.init(0.9, 0.9, 0.9), "90% gray"),
    ColorChip.init("gray_80", nanocolor.RGB.init(0.8, 0.8, 0.8), "80% gray"),
    ColorChip.init("gray_70", nanocolor.RGB.init(0.7, 0.7, 0.7), "70% gray"),
    ColorChip.init("gray_60", nanocolor.RGB.init(0.6, 0.6, 0.6), "60% gray"),
    ColorChip.init("gray_50", nanocolor.RGB.init(0.5, 0.5, 0.5), "50% gray"),
    ColorChip.init("gray_40", nanocolor.RGB.init(0.4, 0.4, 0.4), "40% gray"),
    ColorChip.init("gray_30", nanocolor.RGB.init(0.3, 0.3, 0.3), "30% gray"),
    ColorChip.init("gray_20", nanocolor.RGB.init(0.2, 0.2, 0.2), "20% gray"),
    ColorChip.init("gray_18", nanocolor.RGB.init(0.18, 0.18, 0.18), "18% gray (photographic mid-gray)"),
    ColorChip.init("gray_10", nanocolor.RGB.init(0.1, 0.1, 0.1), "10% gray"),
    ColorChip.init("black_0", nanocolor.RGB.init(0.0, 0.0, 0.0), "0% black"),
};

const spectral_primaries = [_]ColorChip{
    ColorChip.init("red_700nm", nanocolor.RGB.init(1.0, 0.0, 0.0), "Approximate 700nm red"),
    ColorChip.init("orange_600nm", nanocolor.RGB.init(1.0, 0.5, 0.0), "Approximate 600nm orange"),
    ColorChip.init("yellow_580nm", nanocolor.RGB.init(1.0, 1.0, 0.0), "Approximate 580nm yellow"),
    ColorChip.init("green_530nm", nanocolor.RGB.init(0.0, 1.0, 0.0), "Approximate 530nm green"),
    ColorChip.init("cyan_485nm", nanocolor.RGB.init(0.0, 1.0, 1.0), "Approximate 485nm cyan"),
    ColorChip.init("blue_450nm", nanocolor.RGB.init(0.0, 0.0, 1.0), "Approximate 450nm blue"),
    ColorChip.init("violet_400nm", nanocolor.RGB.init(0.5, 0.0, 1.0), "Approximate 400nm violet"),
};

fn getPredefinedChipSets() [4]ColorChipSet {
    return [_]ColorChipSet{
        ColorChipSet.init("ColorChecker Classic", "acescg", &acescg_colorchecker_chips),
        ColorChipSet.init("SMPTE Color Bars", "lin_srgb", &smpte_color_bars),
        ColorChipSet.init("Grayscale Patches", "lin_srgb", &grayscale_patches),
        ColorChipSet.init("Spectral Primaries", "lin_srgb", &spectral_primaries),
    };
}

fn generateBlackbodySeries(allocator: Allocator, start_temp: f32, end_temp: f32, steps: u32) !ColorChipSet {
    var chips = ArrayList(ColorChip).init(allocator);
    defer chips.deinit();

    var i: u32 = 0;
    while (i < steps) : (i += 1) {
        const temp = start_temp + (end_temp - start_temp) * @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(steps - 1));
        const yxy = nanocolor.kelvinToYxy(temp, 1.0);
        const xyz = nanocolor.yxyToXYZ(yxy);

        // Note: This would need a way to get linear sRGB color space
        // For now, we'll use the XYZ values directly scaled down
        const rgb = nanocolor.RGB.init(
            @min(1.0, xyz.x / 0.95047), // Approximate conversion
            @min(1.0, xyz.y),
            @min(1.0, xyz.z / 1.08883),
        );

        const name = try std.fmt.allocPrint(allocator, "blackbody_{d}K", .{@as(u32, @intFromFloat(temp))});
        const desc = try std.fmt.allocPrint(allocator, "Blackbody at {d}K", .{@as(u32, @intFromFloat(temp))});
        try chips.append(ColorChip.init(name, rgb, desc));
    }

    const owned_chips = try chips.toOwnedSlice();
    return ColorChipSet.init("Blackbody Temperature Series", "lin_srgb", owned_chips);
}

// MARK: - Command Line Interface

const ChipSetType = enum {
    colorchecker,
    smpte_bars,
    grayscale,
    spectral,
    blackbody,

    fn fromString(str: []const u8) ?ChipSetType {
        const map = std.ComptimeStringMap(ChipSetType, .{
            .{ "colorchecker", .colorchecker },
            .{ "smpte_bars", .smpte_bars },
            .{ "grayscale", .grayscale },
            .{ "spectral", .spectral },
            .{ "blackbody", .blackbody },
        });
        return map.get(str);
    }
};

const OutputFormat = enum {
    text,
    csv,
    json,

    fn fromString(str: []const u8) ?OutputFormat {
        const map = std.ComptimeStringMap(OutputFormat, .{
            .{ "text", .text },
            .{ "csv", .csv },
            .{ "json", .json },
        });
        return map.get(str);
    }
};

const Config = struct {
    chip_set: ChipSetType = .colorchecker,
    target_space: []const u8 = "sRGB",
    format: OutputFormat = .text,
    output_file: ?[]const u8 = null,
    list_spaces: bool = false,
    list_chip_sets: bool = false,
    help: bool = false,
};

fn parseArgs(allocator: Allocator) !Config {
    var config = Config{};
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var i: usize = 1;
    while (i < args.len) {
        const arg = args[i];

        if (std.mem.eql(u8, arg, "--chip-set") or std.mem.eql(u8, arg, "-s")) {
            if (i + 1 < args.len) {
                config.chip_set = ChipSetType.fromString(args[i + 1]) orelse {
                    print("Error: Unknown chip set '{s}'\n", .{args[i + 1]});
                    return error.InvalidArgument;
                };
                i += 1;
            }
        } else if (std.mem.eql(u8, arg, "--target-space") or std.mem.eql(u8, arg, "-t")) {
            if (i + 1 < args.len) {
                config.target_space = args[i + 1];
                i += 1;
            }
        } else if (std.mem.eql(u8, arg, "--format") or std.mem.eql(u8, arg, "-f")) {
            if (i + 1 < args.len) {
                config.format = OutputFormat.fromString(args[i + 1]) orelse {
                    print("Error: Unknown format '{s}'\n", .{args[i + 1]});
                    return error.InvalidArgument;
                };
                i += 1;
            }
        } else if (std.mem.eql(u8, arg, "--output") or std.mem.eql(u8, arg, "-o")) {
            if (i + 1 < args.len) {
                config.output_file = args[i + 1];
                i += 1;
            }
        } else if (std.mem.eql(u8, arg, "--list-spaces") or std.mem.eql(u8, arg, "-l")) {
            config.list_spaces = true;
        } else if (std.mem.eql(u8, arg, "--list-chip-sets")) {
            config.list_chip_sets = true;
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            config.help = true;
        }

        i += 1;
    }

    return config;
}

fn printUsage() void {
    print(
        \\Color Chip Generator for Nanocolor Zig
        \\
        \\Usage: zig run color_chips.zig [options]
        \\
        \\Options:
        \\  --chip-set, -s <name>     Chip set to generate (colorchecker, smpte_bars, grayscale, spectral, blackbody)
        \\  --target-space, -t <name> Target color space name (default: sRGB)
        \\  --format, -f <format>     Output format (text, csv, json) (default: text)
        \\  --output, -o <file>       Output filename (default: stdout)
        \\  --list-spaces, -l         List available color spaces
        \\  --list-chip-sets          List available chip sets
        \\  --help, -h                Show this help
        \\
        \\Examples:
        \\  zig run color_chips.zig -- --list-spaces
        \\  zig run color_chips.zig -- -s colorchecker -t sRGB
        \\  zig run color_chips.zig -- -s smpte_bars -t g22_rec709 -f csv -o smpte_rec709.csv
        \\  zig run color_chips.zig -- -s blackbody -t acescg -f json -o blackbody_acescg.json
        \\
    );
}

fn listColorSpaces(lib: *nanocolor.ColorSpaceLibrary, allocator: Allocator) !void {
    print("Available color spaces:\n");
    const names = try lib.registeredColorSpaceNames(allocator);
    defer allocator.free(names);

    // Sort the names
    std.sort.pdq([]const u8, names, {}, struct {
        fn lessThan(_: void, lhs: []const u8, rhs: []const u8) bool {
            return std.mem.lessThan(u8, lhs, rhs);
        }
    }.lessThan);

    for (names) |name| {
        print("  {s}\n", .{name});
    }
}

fn listChipSets() void {
    print("Available chip sets:\n");
    const chip_sets = getPredefinedChipSets();
    const names = [_][]const u8{ "colorchecker", "smpte_bars", "grayscale", "spectral" };

    for (names, 0..) |name, i| {
        print("  {s}: {s} ({d} chips)\n", .{ name, chip_sets[i].name, chip_sets[i].chips.len });
    }
    print("  blackbody: Blackbody Temperature Series (17 chips)\n");
}

fn generateChips(allocator: Allocator, config: Config) !void {
    // Initialize nanocolor
    var lib = nanocolor.ColorSpaceLibrary.init(allocator);
    defer lib.deinit();
    try lib.initColorSpaceLibrary();

    // Validate target color space
    if (lib.getNamedColorSpace(config.target_space) == null) {
        print("Error: Unknown color space '{s}'\n", .{config.target_space});
        print("Use --list-spaces to see available color spaces\n");
        return;
    }

    // Generate chip set
    const chip_set: ColorChipSet = switch (config.chip_set) {
        .blackbody => try generateBlackbodySeries(allocator, 2000.0, 10000.0, 17),
        else => blk: {
            const predefined = getPredefinedChipSets();
            const index = switch (config.chip_set) {
                .colorchecker => 0,
                .smpte_bars => 1,
                .grayscale => 2,
                .spectral => 3,
                .blackbody => unreachable,
            };
            break :blk predefined[index];
        },
    };

    // Transform to target space if needed
    const final_chip_set = if (std.mem.eql(u8, chip_set.color_space, config.target_space))
        chip_set
    else
        try chip_set.transformTo(allocator, config.target_space, &lib);

    // Generate output
    const output = switch (config.format) {
        .csv => try final_chip_set.toCSV(allocator),
        .json => try final_chip_set.toJSON(allocator),
        .text => try final_chip_set.toText(allocator),
    };
    defer allocator.free(output);

    // Write output
    if (config.output_file) |filename| {
        try std.fs.cwd().writeFile(filename, output);
        print("Exported {d} chips to {s}\n", .{ final_chip_set.chips.len, filename });
    } else {
        print("{s}\n", .{output});
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = parseArgs(allocator) catch |err| switch (err) {
        error.InvalidArgument => {
            printUsage();
            return;
        },
        else => return err,
    };

    if (config.help) {
        printUsage();
        return;
    }

    if (config.list_spaces) {
        var lib = nanocolor.ColorSpaceLibrary.init(allocator);
        defer lib.deinit();
        try lib.initColorSpaceLibrary();
        try listColorSpaces(&lib, allocator);
        return;
    }

    if (config.list_chip_sets) {
        listChipSets();
        return;
    }

    try generateChips(allocator, config);
}

// MARK: - Tests

test "color chip creation" {
    const chip = ColorChip.init("test", nanocolor.RGB.init(0.5, 0.5, 0.5), "Test chip");
    try std.testing.expect(std.mem.eql(u8, chip.name, "test"));
    try std.testing.expectEqual(@as(f32, 0.5), chip.rgb.r);
}

test "chip set transformation" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var lib = nanocolor.ColorSpaceLibrary.init(allocator);
    defer lib.deinit();
    try lib.initColorSpaceLibrary();

    const predefined = getPredefinedChipSets();
    const colorchecker = predefined[0];

    const transformed = try colorchecker.transformTo(allocator, "sRGB", &lib);
    defer allocator.free(transformed.chips);

    try std.testing.expectEqual(colorchecker.chips.len, transformed.chips.len);
    try std.testing.expect(std.mem.eql(u8, transformed.color_space, "sRGB"));
}

test "output formats" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const predefined = getPredefinedChipSets();
    const grayscale = predefined[2];

    const csv_output = try grayscale.toCSV(allocator);
    defer allocator.free(csv_output);
    try std.testing.expect(std.mem.indexOf(u8, csv_output, "Name,R,G,B,Description") != null);

    const json_output = try grayscale.toJSON(allocator);
    defer allocator.free(json_output);
    try std.testing.expect(std.mem.indexOf(u8, json_output, "\"chips\":") != null);

    const text_output = try grayscale.toText(allocator);
    defer allocator.free(text_output);
    try std.testing.expect(std.mem.indexOf(u8, text_output, "Total:") != null);
}