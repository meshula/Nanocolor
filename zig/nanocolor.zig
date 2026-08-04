//! Nanocolor - A very small color transform library (Zig implementation)
//! 
//! This is a Zig implementation of the nanocolor library for color space 
//! transformations, based on SMPTE RP177-1993 equations.
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
const math = std.math;
const testing = std.testing;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

// MARK: - Basic Types

/// A single coordinate in the CIE 1931 xy chromaticity diagram
pub const Chromaticity = struct {
    x: f32,
    y: f32,

    pub fn init(x: f32, y: f32) Chromaticity {
        return Chromaticity{ .x = x, .y = y };
    }

    pub fn eql(self: Chromaticity, other: Chromaticity, epsilon: f32) bool {
        return @abs(self.x - other.x) < epsilon and @abs(self.y - other.y) < epsilon;
    }
};

/// A coordinate in the CIE 1931 2-degree XYZ color space
pub const XYZ = struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn init(x: f32, y: f32, z: f32) XYZ {
        return XYZ{ .x = x, .y = y, .z = z };
    }
};

/// A chromaticity coordinate with luminance
pub const Yxy = struct {
    Y: f32,
    x: f32,
    y: f32,

    pub fn init(Y: f32, x: f32, y: f32) Yxy {
        return Yxy{ .Y = Y, .x = x, .y = y };
    }
};

/// An RGB coordinate with no intrinsic color space
pub const RGB = struct {
    r: f32,
    g: f32,
    b: f32,

    pub fn init(r: f32, g: f32, b: f32) RGB {
        return RGB{ .r = r, .g = g, .b = b };
    }
};

/// RGB color with alpha channel
pub const RGBA = struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32,

    pub fn init(r: f32, g: f32, b: f32, a: f32) RGBA {
        return RGBA{ .r = r, .g = g, .b = b, .a = a };
    }

    pub fn rgb(self: RGBA) RGB {
        return RGB.init(self.r, self.g, self.b);
    }
};

// MARK: - Matrix Operations

/// A 3x3 matrix of floats used for color space conversions
/// Stored in row major order, such that post-multiplying an RGB
/// as a column vector by an M33f will yield another RGB column
/// transformed by that matrix
pub const M33f = struct {
    m: [9]f32,

    pub fn init() M33f {
        return M33f{ .m = [_]f32{0.0} ** 9 };
    }

    pub fn initFromArray(elements: [9]f32) M33f {
        return M33f{ .m = elements };
    }

    pub fn initIdentity() M33f {
        return M33f{ .m = [_]f32{ 1, 0, 0, 0, 1, 0, 0, 0, 1 } };
    }

    /// Multiply this matrix by another matrix
    pub fn multiply(self: M33f, other: M33f) M33f {
        var result = M33f.init();
        result.m[0] = self.m[0] * other.m[0] + self.m[1] * other.m[3] + self.m[2] * other.m[6];
        result.m[1] = self.m[0] * other.m[1] + self.m[1] * other.m[4] + self.m[2] * other.m[7];
        result.m[2] = self.m[0] * other.m[2] + self.m[1] * other.m[5] + self.m[2] * other.m[8];
        result.m[3] = self.m[3] * other.m[0] + self.m[4] * other.m[3] + self.m[5] * other.m[6];
        result.m[4] = self.m[3] * other.m[1] + self.m[4] * other.m[4] + self.m[5] * other.m[7];
        result.m[5] = self.m[3] * other.m[2] + self.m[4] * other.m[5] + self.m[5] * other.m[8];
        result.m[6] = self.m[6] * other.m[0] + self.m[7] * other.m[3] + self.m[8] * other.m[6];
        result.m[7] = self.m[6] * other.m[1] + self.m[7] * other.m[4] + self.m[8] * other.m[7];
        result.m[8] = self.m[6] * other.m[2] + self.m[7] * other.m[5] + self.m[8] * other.m[8];
        return result;
    }

    /// Compute the inverse of this matrix
    pub fn invert(self: M33f) !M33f {
        var inv = M33f.init();
        const M0 = 0;
        const M1 = 3;
        const M2 = 6;
        const M3 = 1;
        const M4 = 4;
        const M5 = 7;
        const M6 = 2;
        const M7 = 5;
        const M8 = 8;

        const det = self.m[M0] * (self.m[M4] * self.m[M8] - self.m[M5] * self.m[M7]) -
            self.m[M1] * (self.m[M3] * self.m[M8] - self.m[M5] * self.m[M6]) +
            self.m[M2] * (self.m[M3] * self.m[M7] - self.m[M4] * self.m[M6]);

        if (@abs(det) < 1e-10) {
            return error.MatrixNotInvertible;
        }

        const invdet = 1.0 / det;
        inv.m[M0] = (self.m[M4] * self.m[M8] - self.m[M5] * self.m[M7]) * invdet;
        inv.m[M1] = (self.m[M2] * self.m[M7] - self.m[M1] * self.m[M8]) * invdet;
        inv.m[M2] = (self.m[M1] * self.m[M5] - self.m[M2] * self.m[M4]) * invdet;
        inv.m[M3] = (self.m[M5] * self.m[M6] - self.m[M3] * self.m[M8]) * invdet;
        inv.m[M4] = (self.m[M0] * self.m[M8] - self.m[M2] * self.m[M6]) * invdet;
        inv.m[M5] = (self.m[M2] * self.m[M3] - self.m[M0] * self.m[M5]) * invdet;
        inv.m[M6] = (self.m[M3] * self.m[M7] - self.m[M4] * self.m[M6]) * invdet;
        inv.m[M7] = (self.m[M1] * self.m[M6] - self.m[0] * self.m[M7]) * invdet;
        inv.m[M8] = (self.m[M0] * self.m[M4] - self.m[M1] * self.m[M3]) * invdet;
        return inv;
    }

    /// Transform an RGB color by this matrix
    pub fn transformRGB(self: M33f, rgb: RGB) RGB {
        const r = self.m[0] * rgb.r + self.m[1] * rgb.g + self.m[2] * rgb.b;
        const g = self.m[3] * rgb.r + self.m[4] * rgb.g + self.m[5] * rgb.b;
        const b = self.m[6] * rgb.r + self.m[7] * rgb.g + self.m[8] * rgb.b;
        return RGB.init(r, g, b);
    }
};

// MARK: - Color Space Descriptors

/// Describes a color space with primaries, white point, and transfer function
pub const ColorSpaceDescriptor = struct {
    name: []const u8,
    red_primary: Chromaticity,
    green_primary: Chromaticity,
    blue_primary: Chromaticity,
    white_point: Chromaticity,
    gamma: f32,
    linear_bias: f32,

    pub fn init(
        name: []const u8,
        red_primary: Chromaticity,
        green_primary: Chromaticity,
        blue_primary: Chromaticity,
        white_point: Chromaticity,
        gamma: f32,
        linear_bias: f32,
    ) ColorSpaceDescriptor {
        return ColorSpaceDescriptor{
            .name = name,
            .red_primary = red_primary,
            .green_primary = green_primary,
            .blue_primary = blue_primary,
            .white_point = white_point,
            .gamma = gamma,
            .linear_bias = linear_bias,
        };
    }
};

/// Describes a color space defined in terms of a 3x3 matrix
pub const ColorSpaceM33Descriptor = struct {
    name: []const u8,
    rgb_to_xyz: M33f,
    gamma: f32,
    linear_bias: f32,

    pub fn init(name: []const u8, rgb_to_xyz: M33f, gamma: f32, linear_bias: f32) ColorSpaceM33Descriptor {
        return ColorSpaceM33Descriptor{
            .name = name,
            .rgb_to_xyz = rgb_to_xyz,
            .gamma = gamma,
            .linear_bias = linear_bias,
        };
    }
};

// MARK: - Color Space Implementation

/// Opaque color space object
pub const ColorSpace = opaque {};

const ColorSpaceImpl = struct {
    descriptor: ColorSpaceDescriptor,
    k0: f32,
    phi: f32,
    rgb_to_xyz: M33f,
    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator, descriptor: ColorSpaceDescriptor) !*ColorSpaceImpl {
        var cs = try allocator.create(ColorSpaceImpl);
        cs.* = .{ 
            .descriptor = descriptor,
            .k0 = 0.0,
            .phi = 0.0,
            .rgb_to_xyz = M33f.init(),
            .allocator = allocator,
        };
        try cs.initialize();
        return cs;
    }

    pub fn initFromMatrix(allocator: Allocator, descriptor: ColorSpaceM33Descriptor) !*ColorSpaceImpl {
        // Create a dummy ColorSpaceDescriptor with zero white point to signal matrix init
        const dummy_desc = ColorSpaceDescriptor.init(
            descriptor.name,
            Chromaticity.init(0.0, 0.0),
            Chromaticity.init(0.0, 0.0),
            Chromaticity.init(0.0, 0.0),
            Chromaticity.init(0.0, 0.0),
            descriptor.gamma,
            descriptor.linear_bias,
        );
        var cs = try allocator.create(ColorSpaceImpl);
        cs.* = .{ 
            .descriptor = dummy_desc,
            .k0 = 0.0,
            .phi = 0.0,
            .rgb_to_xyz = descriptor.rgb_to_xyz,
            .allocator = allocator,
        };
        cs.initializeTransferFunction();
        return cs;
    }
    
    pub fn deinit(self: *ColorSpaceImpl) void {
        self.allocator.destroy(self);
    }

    fn initialize(self: *Self) !void {
        self.initializeTransferFunction();

        // If white point is zero, this was matrix-initialized, don't overwrite
        if (self.descriptor.white_point.x == 0.0) {
            return;
        }

        // Compute RGB to XYZ matrix using SMPTE RP 177-1993
        const red = [3]f32{ 
            self.descriptor.red_primary.x,
            self.descriptor.red_primary.y,
            1.0 - self.descriptor.red_primary.x - self.descriptor.red_primary.y 
        };

        const green = [3]f32{ 
            self.descriptor.green_primary.x,
            self.descriptor.green_primary.y,
            1.0 - self.descriptor.green_primary.x - self.descriptor.green_primary.y 
        };

        const blue = [3]f32{ 
            self.descriptor.blue_primary.x,
            self.descriptor.blue_primary.y,
            1.0 - self.descriptor.blue_primary.x - self.descriptor.blue_primary.y 
        };

        const white = [3]f32{ 
            self.descriptor.white_point.x,
            self.descriptor.white_point.y,
            1.0 - self.descriptor.white_point.x - self.descriptor.white_point.y 
        };

        // Build the P matrix by column binding red, green, and blue
        const p = M33f.initFromArray([9]f32{ 
            red[0],   green[0], blue[0],
            red[1],   green[1], blue[1],
            red[2],   green[2], blue[2],
        });

        // White has luminance factor of 1.0, i.e., Y = 1
        const W = [3]f32{ white[0] / white[1], white[1] / white[1], white[2] / white[1] };

        // Compute coefficients to scale primaries
        const p_inv = try p.invert();
        const C = [3]f32{ 
            p_inv.m[0] * W[0] + p_inv.m[1] * W[1] + p_inv.m[2] * W[2],
            p_inv.m[3] * W[0] + p_inv.m[4] * W[1] + p_inv.m[5] * W[2],
            p_inv.m[6] * W[0] + p_inv.m[7] * W[1] + p_inv.m[8] * W[2],
        };

        // Multiply P matrix by diagonal matrix of coefficients
        self.rgb_to_xyz = M33f.initFromArray([9]f32{ 
            p.m[0] * C[0], p.m[1] * C[1], p.m[2] * C[2],
            p.m[3] * C[0], p.m[4] * C[1], p.m[5] * C[2],
            p.m[6] * C[0], p.m[7] * C[1], p.m[8] * C[2],
        });
    }

    fn initializeTransferFunction(self: *Self) void {
        const a = self.descriptor.linear_bias;
        const gamma = self.descriptor.gamma;

        if (gamma == 1.0) {
            self.k0 = 1e9;
            self.phi = 1.0;
        } else {
            if (a <= 0.0) {
                self.k0 = 0.0;
                self.phi = 1.0;
            } else {
                self.k0 = a / (gamma - 1.0);
                self.phi = (a / math.exp(@log(gamma * a / (gamma + gamma * a - 1.0 - a)) * gamma)) / (gamma - 1.0);
            }
        }
    }

    /// Apply transfer function to convert from linear value
    pub fn fromLinear(self: *const Self, t: f32) f32 {
        if (t < self.k0 / self.phi) {
            return t * self.phi;
        }
        const a = self.descriptor.linear_bias;
        return (1.0 + a) * math.pow(f32, t, 1.0 / self.descriptor.gamma) - a;
    }

    /// Apply inverse transfer function to convert to linear value
    pub fn toLinear(self: *const Self, t: f32) f32 {
        if (t < self.k0) {
            return t / self.phi;
        }
        const a = self.descriptor.linear_bias;
        return math.pow(f32, (t + a) / (1.0 + a), self.descriptor.gamma);
    }

    /// Get the RGB to XYZ transformation matrix
    pub fn getRGBToXYZMatrix(self: *const Self) M33f {
        return self.rgb_to_xyz;
    }

    /// Get the XYZ to RGB transformation matrix
    pub fn getXYZToRGBMatrix(self: *const Self) !M33f {
        return self.rgb_to_xyz.invert();
    }

    /// Get the RGB to RGB transformation matrix to another color space
    pub fn getRGBToRGBMatrix(self: *const Self, dst: *const Self) !M33f {
        const dst_xyz_to_rgb = try dst.getXYZToRGBMatrix();
        return dst_xyz_to_rgb.multiply(self.rgb_to_xyz);
    }

    /// Get K0 and phi values for the color space
    pub fn getK0Phi(self: *const Self) struct { k0: f32, phi: f32 } {
        return .{ .k0 = self.k0, .phi = self.phi };
    }

    pub fn eql(self: *const Self, other: *const Self) bool {
        return std.mem.eql(u8, self.descriptor.name, other.descriptor.name) and 
            self.descriptor.gamma == other.descriptor.gamma and 
            self.descriptor.linear_bias == other.descriptor.linear_bias;
    }
};

// MARK: - Predefined Color Spaces

/// White point chromaticities
pub const WhitePoints = struct {
    pub const D65 = Chromaticity.init(0.3127, 0.3290);
    pub const ACES = Chromaticity.init(0.32168, 0.33767);
};

/// Predefined color space descriptors
pub const ColorSpaces = struct {
    pub const acescg = ColorSpaceDescriptor.init(
        "acescg",
        Chromaticity.init(0.713, 0.293),
        Chromaticity.init(0.165, 0.830),
        Chromaticity.init(0.128, 0.044),
        WhitePoints.ACES,
        1.0,
        0.0,
    );

    pub const adobergb = ColorSpaceDescriptor.init(
        "adobergb",
        Chromaticity.init(0.64, 0.33),
        Chromaticity.init(0.21, 0.71),
        Chromaticity.init(0.15, 0.06),
        WhitePoints.D65,
        2.2,
        0.0,
    );

    pub const g18_ap1 = ColorSpaceDescriptor.init(
        "g18_ap1",
        Chromaticity.init(0.713, 0.293),
        Chromaticity.init(0.165, 0.830),
        Chromaticity.init(0.128, 0.044),
        WhitePoints.ACES,
        1.8,
        0.0,
    );

    pub const g18_rec709 = ColorSpaceDescriptor.init(
        "g18_rec709",
        Chromaticity.init(0.640, 0.330),
        Chromaticity.init(0.300, 0.600),
        Chromaticity.init(0.150, 0.060),
        WhitePoints.D65,
        1.8,
        0.0,
    );

    pub const g22_ap1 = ColorSpaceDescriptor.init(
        "g22_ap1",
        Chromaticity.init(0.713, 0.293),
        Chromaticity.init(0.165, 0.830),
        Chromaticity.init(0.128, 0.044),
        WhitePoints.ACES,
        2.2,
        0.0,
    );

    pub const g22_rec709 = ColorSpaceDescriptor.init(
        "g22_rec709",
        Chromaticity.init(0.640, 0.330),
        Chromaticity.init(0.300, 0.600),
        Chromaticity.init(0.150, 0.060),
        WhitePoints.D65,
        2.2,
        0.0,
    );

    pub const lin_adobergb = ColorSpaceDescriptor.init(
        "lin_adobergb",
        Chromaticity.init(0.64, 0.33),
        Chromaticity.init(0.21, 0.71),
        Chromaticity.init(0.15, 0.06),
        WhitePoints.D65,
        1.0,
        0.0,
    );

    pub const lin_ap0 = ColorSpaceDescriptor.init(
        "lin_ap0",
        Chromaticity.init(0.7347, 0.2653),
        Chromaticity.init(0.0000, 1.0000),
        Chromaticity.init(0.0001, -0.0770),
        WhitePoints.ACES,
        1.0,
        0.0,
    );

    pub const lin_ap1 = ColorSpaceDescriptor.init(
        "lin_ap1",
        Chromaticity.init(0.713, 0.293),
        Chromaticity.init(0.165, 0.830),
        Chromaticity.init(0.128, 0.044),
        WhitePoints.ACES,
        1.0,
        0.0,
    );

    pub const lin_displayp3 = ColorSpaceDescriptor.init(
        "lin_displayp3",
        Chromaticity.init(0.6800, 0.3200),
        Chromaticity.init(0.2650, 0.6900),
        Chromaticity.init(0.1500, 0.0600),
        WhitePoints.D65,
        1.0,
        0.0,
    );

    pub const lin_rec709 = ColorSpaceDescriptor.init(
        "lin_rec709",
        Chromaticity.init(0.640, 0.330),
        Chromaticity.init(0.300, 0.600),
        Chromaticity.init(0.150, 0.060),
        WhitePoints.D65,
        1.0,
        0.0,
    );

    pub const lin_rec2020 = ColorSpaceDescriptor.init(
        "lin_rec2020",
        Chromaticity.init(0.708, 0.292),
        Chromaticity.init(0.170, 0.797),
        Chromaticity.init(0.131, 0.046),
        WhitePoints.D65,
        1.0,
        0.0,
    );

    pub const lin_srgb = ColorSpaceDescriptor.init(
        "lin_srgb",
        Chromaticity.init(0.640, 0.330),
        Chromaticity.init(0.300, 0.600),
        Chromaticity.init(0.150, 0.060),
        WhitePoints.D65,
        1.0,
        0.0,
    );

    pub const srgb_displayp3 = ColorSpaceDescriptor.init(
        "srgb_displayp3",
        Chromaticity.init(0.6800, 0.3200),
        Chromaticity.init(0.2650, 0.6900),
        Chromaticity.init(0.1500, 0.0600),
        WhitePoints.D65,
        2.4,
        0.055,
    );

    pub const sRGB = ColorSpaceDescriptor.init(
        "sRGB",
        Chromaticity.init(0.640, 0.330),
        Chromaticity.init(0.300, 0.600),
        Chromaticity.init(0.150, 0.060),
        WhitePoints.D65,
        2.4,
        0.055,
    );

    pub const srgb_texture = ColorSpaceDescriptor.init(
        "srgb_texture",
        Chromaticity.init(0.640, 0.330),
        Chromaticity.init(0.300, 0.600),
        Chromaticity.init(0.150, 0.060),
        WhitePoints.D65,
        2.4,
        0.055,
    );

    pub const identity = ColorSpaceDescriptor.init(
        "identity",
        Chromaticity.init(1.0, 0.0),
        Chromaticity.init(0.0, 1.0),
        Chromaticity.init(0.0, 0.0),
        Chromaticity.init(1.0 / 3.0, 1.0 / 3.0),
        1.0,
        0.0,
    );

    pub const raw = ColorSpaceDescriptor.init(
        "raw",
        Chromaticity.init(1.0, 0.0),
        Chromaticity.init(0.0, 1.0),
        Chromaticity.init(0.0, 0.0),
        Chromaticity.init(1.0 / 3.0, 1.0 / 3.0),
        1.0,
        0.0,
    );
};

// MARK: - Color Space Library

/// Global color space library
pub const ColorSpaceLibrary = struct {
    const ColorSpaceMap = std.HashMap([]const u8, *ColorSpaceImpl, std.hash_map.StringContext, std.hash_map.default_max_load_percentage);

    color_spaces: ColorSpaceMap,
    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{ 
            .color_spaces = ColorSpaceMap.init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        var iterator = self.color_spaces.valueIterator();
        while (iterator.next()) |cs| {
            cs.*.deinit();
        }
        self.color_spaces.deinit();
    }

    /// Initialize the color space library with predefined color spaces
    pub fn initColorSpaceLibrary(self: *Self) !void {
        self.color_spaces.clearRetainingCapacity();

        const predefined_spaces = [_]ColorSpaceDescriptor{
            ColorSpaces.acescg,       ColorSpaces.adobergb,     ColorSpaces.g18_ap1,      ColorSpaces.g18_rec709,
            ColorSpaces.g22_ap1,      ColorSpaces.g22_rec709,   ColorSpaces.lin_adobergb, ColorSpaces.lin_ap0,
            ColorSpaces.lin_ap1,      ColorSpaces.lin_displayp3, ColorSpaces.lin_rec709,  ColorSpaces.lin_rec2020,
            ColorSpaces.lin_srgb,     ColorSpaces.srgb_displayp3, ColorSpaces.sRGB,       ColorSpaces.srgb_texture,
            ColorSpaces.identity,     ColorSpaces.raw,
        };

        for (predefined_spaces) |descriptor| {
            const cs = try ColorSpaceImpl.init(self.allocator, descriptor);
            try self.color_spaces.put(descriptor.name, cs);
        }
    }

    /// Get the names of registered color spaces
    pub fn registeredColorSpaceNames(self: Self, allocator: Allocator) ![][]const u8 {
        var names = ArrayList([]const u8).init(allocator);
        defer names.deinit();

        var iterator = self.color_spaces.keyIterator();
        while (iterator.next()) |key| {
            try names.append(key.*);
        }

        return names.toOwnedSlice();
    }

    /// Get a color space by name
    pub fn getNamedColorSpace(self: Self, name: []const u8) ?*ColorSpace {
        const cs = self.color_spaces.get(name);
        if (cs) |c| {
            return @ptrCast(c);
        }
        return null;
    }
};

/// Create a custom color space from a descriptor
pub fn createColorSpace(allocator: Allocator, descriptor: ColorSpaceDescriptor) !*ColorSpace {
    const cs = try ColorSpaceImpl.init(allocator, descriptor);
    return @ptrCast(cs);
}

/// Create a custom color space from a matrix descriptor
pub fn createColorSpaceM33(allocator: Allocator, descriptor: ColorSpaceM33Descriptor) !*ColorSpace {
    const cs = try ColorSpaceImpl.initFromMatrix(allocator, descriptor);
    return @ptrCast(cs);
}

/// Destroy a custom color space
pub fn destroyColorSpace(cs: *ColorSpace) void {
    const impl = @as(*ColorSpaceImpl, @ptrCast(cs));
    impl.deinit();
}

// MARK: - Color Transformation Functions

/// Transform a color from one color space to another
pub fn transformColor(dst: *const ColorSpace, src: *const ColorSpace, rgb: RGB) !RGB {
    const src_impl = @as(*ColorSpaceImpl, @alignCast(@constCast(@ptrCast(src))));
    const dst_impl = @as(*ColorSpaceImpl, @alignCast(@constCast(@ptrCast(dst))));

    // Convert to linear in source space
    const linear_rgb = RGB.init(src_impl.toLinear(rgb.r), src_impl.toLinear(rgb.g), src_impl.toLinear(rgb.b));

    // Transform to destination color space via XYZ
    const dst_xyz_to_rgb = try dst_impl.getXYZToRGBMatrix();
    const transformation_matrix = dst_xyz_to_rgb.multiply(src_impl.getRGBToXYZMatrix());
    const transformed_linear = transformation_matrix.transformRGB(linear_rgb);

    // Apply destination transfer function
    return RGB.init(
        dst_impl.fromLinear(transformed_linear.r),
        dst_impl.fromLinear(transformed_linear.g),
        dst_impl.fromLinear(transformed_linear.b),
    );
}

/// Transform an array of colors from one color space to another
pub fn transformColors(allocator: Allocator, dst: *const ColorSpace, src: *const ColorSpace, rgb_list: []const RGB) ![]RGB {
    var result = try std.ArrayList(RGB).initCapacity(allocator, rgb_list.len);
    defer result.deinit();

    for (rgb_list) |rgb| {
        const transformed = try transformColor(dst, src, rgb);
        try result.append(transformed);
    }

    return result.toOwnedSlice();
}

/// Convert RGB to XYZ using the given color space
pub fn rgbToXYZ(cs: *const ColorSpace, rgb: RGB) XYZ {
    const impl = @as(*ColorSpaceImpl, @alignCast(@constCast(@ptrCast(cs))));
    const linear_rgb = RGB.init(impl.toLinear(rgb.r), impl.toLinear(rgb.g), impl.toLinear(rgb.b));
    const matrix = impl.getRGBToXYZMatrix();
    const x = matrix.m[0] * linear_rgb.r + matrix.m[1] * linear_rgb.g + matrix.m[2] * linear_rgb.b;
    const y = matrix.m[3] * linear_rgb.r + matrix.m[4] * linear_rgb.g + matrix.m[5] * linear_rgb.b;
    const z = matrix.m[6] * linear_rgb.r + matrix.m[7] * linear_rgb.g + matrix.m[8] * linear_rgb.b;
    return XYZ.init(x, y, z);
}

/// Convert XYZ to RGB using the given color space
pub fn xyzToRGB(cs: *const ColorSpace, xyz: XYZ) !RGB {
    const impl = @as(*ColorSpaceImpl, @alignCast(@constCast(@ptrCast(cs))));
    const matrix = try impl.getXYZToRGBMatrix();
    const linear_r = matrix.m[0] * xyz.x + matrix.m[1] * xyz.y + matrix.m[2] * xyz.z;
    const linear_g = matrix.m[3] * xyz.x + matrix.m[4] * xyz.y + matrix.m[5] * xyz.z;
    const linear_b = matrix.m[6] * xyz.x + matrix.m[7] * xyz.y + matrix.m[8] * xyz.z;
    return RGB.init(impl.fromLinear(linear_r), impl.fromLinear(linear_g), impl.fromLinear(linear_b));
}

/// Convert XYZ to Yxy
pub fn xyzToYxy(xyz: XYZ) Yxy {
    const sum = xyz.x + xyz.y + xyz.z;
    if (sum == 0.0) {
        return Yxy.init(xyz.y, 0.0, 0.0);
    }
    return Yxy.init(xyz.y, xyz.x / sum, xyz.y / sum);
}

/// Convert Yxy to XYZ
pub fn yxyToXYZ(yxy: Yxy) XYZ {
    if (yxy.y == 0.0) {
        return XYZ.init(0.0, 0.0, 0.0);
    }
    const x = yxy.Y * yxy.x / yxy.y;
    const z = yxy.Y * (1.0 - yxy.x - yxy.y) / yxy.y;
    return XYZ.init(x, yxy.Y, z);
}

/// Convert Yxy to RGB using the given color space
pub fn yxyToRGB(cs: *const ColorSpace, yxy: Yxy) !RGB {
    const xyz = yxyToXYZ(yxy);
    return xyzToRGB(cs, xyz);
}

/// Convert blackbody temperature to Yxy chromaticity
/// temperature: Temperature in Kelvin (1000-15000K)
/// luminosity: Luminosity value (default 1.0)
/// Returns: Yxy coordinate on the blackbody emission spectrum
pub fn kelvinToYxy(temperature: f32, luminosity: f32) Yxy {
    // Clamp temperature to valid range
    const temp = math.clamp(temperature, 1000.0, 15000.0);

    // Use McCamy's approximation for CCT to xy conversion
    // This is a simplified implementation - the C version likely uses more precise equations
    const x: f32 = if (temp < 4000) blk: {
        break :blk -0.2661239 * (1e9 / (temp * temp * temp)) - 0.2343589 * (1e6 / (temp * temp)) + 0.8776956 * (1e3 / temp) + 0.179910;
    } else blk: {
        break :blk -3.0258469 * (1e9 / (temp * temp * temp)) + 2.1070379 * (1e6 / (temp * temp)) + 0.2226347 * (1e3 / temp) + 0.240390;
    };

    // Calculate y from x using Planckian locus approximation
    const y: f32 = if (temp < 2222) blk: {
        break :blk -1.1063814 * (x * x * x) - 1.34811020 * (x * x) + 2.18555832 * x - 0.20219683;
    } else if (temp < 4000) blk: {
        break :blk -0.9549476 * (x * x * x) - 1.37418593 * (x * x) + 2.09137015 * x - 0.16748867;
    } else blk: {
        break :blk 3.0817580 * (x * x * x) - 5.87338670 * (x * x) + 3.75112997 * x - 0.37001483;
    };

    return Yxy.init(luminosity, x, y);
}

/// Match a linear color space based on primaries and white point
/// red_primary: Red primary chromaticity
/// green_primary: Green primary chromaticity
/// blue_primary: Blue primary chromaticity
/// white_point: White point chromaticity
/// epsilon: Tolerance for comparison (default 1e-4)
/// Returns: Name of matching color space or null if no match found
pub fn matchLinearColorSpace(
    red_primary: Chromaticity,
    green_primary: Chromaticity,
    blue_primary: Chromaticity,
    white_point: Chromaticity,
    epsilon: f32,
) ?[]const u8 {
    const predefined_spaces = [_]ColorSpaceDescriptor{
        ColorSpaces.acescg,       ColorSpaces.adobergb,     ColorSpaces.g18_ap1,      ColorSpaces.g18_rec709,
        ColorSpaces.g22_ap1,      ColorSpaces.g22_rec709,   ColorSpaces.lin_adobergb, ColorSpaces.lin_ap0,
        ColorSpaces.lin_ap1,      ColorSpaces.lin_displayp3, ColorSpaces.lin_rec709,  ColorSpaces.lin_rec2020,
        ColorSpaces.lin_srgb,     ColorSpaces.srgb_displayp3, ColorSpaces.sRGB,       ColorSpaces.srgb_texture,
        ColorSpaces.identity,     ColorSpaces.raw,
    };

    for (predefined_spaces) |descriptor| {
        // Only check linear color spaces (gamma = 1.0)
        if (descriptor.gamma != 1.0) {
            continue;
        }

        if (descriptor.red_primary.eql(red_primary, epsilon) and
            descriptor.green_primary.eql(green_primary, epsilon) and
            descriptor.blue_primary.eql(blue_primary, epsilon) and
            descriptor.white_point.eql(white_point, epsilon))
        {
            return descriptor.name;
        }
    }

    return null;
}

// MARK: - Testing and Examples

test "basic matrix operations" {
    const identity = M33f.initIdentity();
    const test_rgb = RGB.init(1.0, 0.5, 0.0);
    const transformed = identity.transformRGB(test_rgb);

    try testing.expectEqual(test_rgb.r, transformed.r);
    try testing.expectEqual(test_rgb.g, transformed.g);
    try testing.expectEqual(test_rgb.b, transformed.b);
}

test "matrix inversion" {
    const scale_matrix = M33f.initFromArray([9]f32{ 2, 0, 0, 0, 2, 0, 0, 0, 2 });
    const inverted = try scale_matrix.invert();
    const should_be_identity = scale_matrix.multiply(inverted);

    const epsilon = 1e-6;
    try testing.expectApproxEqAbs(@as(f32, 1.0), should_be_identity.m[0], epsilon);
    try testing.expectApproxEqAbs(@as(f32, 0.0), should_be_identity.m[1], epsilon);
    try testing.expectApproxEqAbs(@as(f32, 0.0), should_be_identity.m[2], epsilon);
    try testing.expectApproxEqAbs(@as(f32, 0.0), should_be_identity.m[3], epsilon);
    try testing.expectApproxEqAbs(@as(f32, 1.0), should_be_identity.m[4], epsilon);
    try testing.expectApproxEqAbs(@as(f32, 0.0), should_be_identity.m[5], epsilon);
    try testing.expectApproxEqAbs(@as(f32, 0.0), should_be_identity.m[6], epsilon);
    try testing.expectApproxEqAbs(@as(f32, 0.0), should_be_identity.m[7], epsilon);
    try testing.expectApproxEqAbs(@as(f32, 1.0), should_be_identity.m[8], epsilon);
}

test "color space creation" {
    const srgb_cs = try ColorSpaceImpl.init(testing.allocator, ColorSpaces.sRGB);
    defer srgb_cs.deinit();
    
    const srgb = @as(*ColorSpace, @alignCast(@constCast(@ptrCast(srgb_cs))));
    const srgb_impl = @as(*const ColorSpaceImpl, @alignCast(@constCast(@ptrCast(srgb))));

    try testing.expect(std.mem.eql(u8, srgb_impl.descriptor.name, "sRGB"));
    try testing.expectEqual(@as(f32, 2.4), srgb_impl.descriptor.gamma);
    try testing.expectEqual(@as(f32, 0.055), srgb_impl.descriptor.linear_bias);
}

test "color transformation" {
    const srgb_cs = try ColorSpaceImpl.init(testing.allocator, ColorSpaces.sRGB);
    defer srgb_cs.deinit();
    const srgb = @as(*ColorSpace, @ptrCast(srgb_cs)); 

    const lin_srgb_cs = try ColorSpaceImpl.init(testing.allocator, ColorSpaces.lin_srgb);
    defer lin_srgb_cs.deinit();
    const lin_srgb = @as(*ColorSpace, @ptrCast(lin_srgb_cs));

    const test_color = RGB.init(0.5, 0.5, 0.5); // Mid-gray in sRGB
    const linear_color = try transformColor(lin_srgb, srgb, test_color);

    // Linear values should be smaller than sRGB encoded values for mid-range
    try testing.expect(linear_color.r < test_color.r);
    try testing.expect(linear_color.g < test_color.g);
    try testing.expect(linear_color.b < test_color.b);

    // Transform back
    const back_to_srgb = try transformColor(srgb, lin_srgb, linear_color);
    const epsilon = 1e-5;
    try testing.expectApproxEqAbs(test_color.r, back_to_srgb.r, epsilon);
    try testing.expectApproxEqAbs(test_color.g, back_to_srgb.g, epsilon);
    try testing.expectApproxEqAbs(test_color.b, back_to_srgb.b, epsilon);
}

test "xyz conversion" {
    const srgb_cs = try ColorSpaceImpl.init(testing.allocator, ColorSpaces.sRGB);
    defer srgb_cs.deinit();
    const srgb = @as(*ColorSpace, @ptrCast(srgb_cs)); 

    const test_color = RGB.init(1.0, 0.0, 0.0); // Pure red
    const xyz = rgbToXYZ(srgb, test_color);

    // Red should have more X than Y or Z
    try testing.expect(xyz.x > xyz.y);
    try testing.expect(xyz.x > xyz.z);

    // Convert back
    const back_to_rgb = try xyzToRGB(srgb, xyz);
    const epsilon = 1e-4;
    try testing.expectApproxEqAbs(test_color.r, back_to_rgb.r, epsilon);
    try testing.expectApproxEqAbs(test_color.g, back_to_rgb.g, epsilon);
    try testing.expectApproxEqAbs(test_color.b, back_to_rgb.b, epsilon);
}

test "yxy conversion" {
    const xyz = XYZ.init(0.3, 0.6, 0.1);
    const yxy = xyzToYxy(xyz);
    const back_to_xyz = yxyToXYZ(yxy);

    const epsilon = 1e-6;
    try testing.expectApproxEqAbs(xyz.x, back_to_xyz.x, epsilon);
    try testing.expectApproxEqAbs(xyz.y, back_to_xyz.y, epsilon);
    try testing.expectApproxEqAbs(xyz.z, back_to_xyz.z, epsilon);
}

test "kelvin conversion" {
    const kelvin_yxy = kelvinToYxy(6500.0, 1.0); // D65 white point approx
    
    // Should be close to D65 white point
    const d65 = WhitePoints.D65;
    const epsilon = 0.01; // Relaxed epsilon due to approximation
    try testing.expectApproxEqAbs(d65.x, kelvin_yxy.x, epsilon);
    try testing.expectApproxEqAbs(d65.y, kelvin_yxy.y, epsilon);
}

test "color space library" {
    var lib = ColorSpaceLibrary.init(testing.allocator);
    defer lib.deinit();

    try lib.initColorSpaceLibrary();

    const srgb_opt = lib.getNamedColorSpace("sRGB");
    try testing.expect(srgb_opt != null);

    const srgb = srgb_opt.?;
    const srgb_impl = @as(*const ColorSpaceImpl, @alignCast(@constCast(@ptrCast(srgb))));
    try testing.expect(std.mem.eql(u8, srgb_impl.descriptor.name, "sRGB"));
}

test "linear color space matching" {
    const match = matchLinearColorSpace(
        ColorSpaces.lin_srgb.red_primary,
        ColorSpaces.lin_srgb.green_primary,
        ColorSpaces.lin_srgb.blue_primary,
        ColorSpaces.lin_srgb.white_point,
        1e-4,
    );

    try testing.expect(match != null);
    try testing.expect(std.mem.eql(u8, match.?, "lin_srgb"));
}

// MARK: - Performance Testing and Examples

pub fn performanceTest(allocator: Allocator) !void {
    var lib = ColorSpaceLibrary.init(allocator);
    defer lib.deinit();
    try lib.initColorSpaceLibrary();

    const srgb = lib.getNamedColorSpace("sRGB") orelse return error.ColorSpaceNotFound;
    const acescg = lib.getNamedColorSpace("acescg") orelse return error.ColorSpaceNotFound;

    // Generate test colors
    var test_colors = ArrayList(RGB).init(allocator);
    defer test_colors.deinit();

    var i: u32 = 0;
    while (i < 10000) : (i += 1) {
        const f = @as(f32, @floatFromInt(i)) / 10000.0;
        try test_colors.append(RGB.init(f, f * 0.5, f * 0.8));
    }

    const start_time = std.time.nanoTimestamp();
    const transformed = try transformColors(allocator, acescg, srgb, test_colors.items);
    defer allocator.free(transformed);
    const end_time = std.time.nanoTimestamp();

    const duration_ns = end_time - start_time;
    const duration_ms = @as(f64, @floatFromInt(duration_ns)) / 1_000_000.0;
    const colors_per_second = @as(f64, @floatFromInt(test_colors.items.len)) / (duration_ms / 1000.0);

    std.debug.print("Performance test: Transformed {} colors in {d:.2} ms\n", .{ test_colors.items.len, duration_ms });
    std.debug.print("Rate: {d:.0} colors/second\n", .{colors_per_second});
}

pub fn runExamples(allocator: Allocator) !void {
    std.debug.print("Nanocolor Zig Implementation\n");

    var lib = ColorSpaceLibrary.init(allocator);
    defer lib.deinit();
    try lib.initColorSpaceLibrary();

    const names = try lib.registeredColorSpaceNames(allocator);
    defer allocator.free(names);
    std.debug.print("Available color spaces: {any}\n", .{names});

    // Test color transformation
    const srgb = lib.getNamedColorSpace("sRGB") orelse return error.ColorSpaceNotFound;
    const lin_srgb = lib.getNamedColorSpace("lin_srgb") orelse return error.ColorSpaceNotFound;

    // Test sRGB to linear sRGB transformation
    const test_color = RGB.init(0.5, 0.5, 0.5); // Mid-gray in sRGB
    const linear_color = try transformColor(lin_srgb, srgb, test_color);
    std.debug.print("sRGB RGB({d:.3}, {d:.3}, {d:.3}) -> Linear sRGB RGB({d:.3}, {d:.3}, {d:.3})\n", .{ test_color.r, test_color.g, test_color.b, linear_color.r, linear_color.g, linear_color.b });

    // Convert back
    const back_to_srgb = try transformColor(srgb, lin_srgb, linear_color);
    std.debug.print("Linear sRGB RGB({d:.3}, {d:.3}, {d:.3}) -> sRGB RGB({d:.3}, {d:.3}, {d:.3})\n", .{ linear_color.r, linear_color.g, linear_color.b, back_to_srgb.r, back_to_srgb.g, back_to_srgb.b });

    // Test XYZ conversion
    const xyz = rgbToXYZ(srgb, test_color);
    std.debug.print("sRGB RGB({d:.3}, {d:.3}, {d:.3}) -> XYZ({d:.3}, {d:.3}, {d:.3})\n", .{ test_color.r, test_color.g, test_color.b, xyz.x, xyz.y, xyz.z });

    // Test Yxy conversion
    const yxy = xyzToYxy(xyz);
    std.debug.print("XYZ({d:.3}, {d:.3}, {d:.3}) -> Yxy({d:.3}, {d:.3}, {d:.3})\n", .{ xyz.x, xyz.y, xyz.z, yxy.Y, yxy.x, yxy.y });

    // Test blackbody conversion
    const kelvin_yxy = kelvinToYxy(6500.0, 1.0); // D65 white point approx
    std.debug.print("6500K blackbody -> Yxy({d:.3}, {d:.3}, {d:.3})\n", .{ kelvin_yxy.Y, kelvin_yxy.x, kelvin_yxy.y });

    std.debug.print("Basic examples completed.\n");
}

// Example main function
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try runExamples(allocator);
    try performanceTest(allocator);
}

// When this file is run as a test, the test functions will be executed
// zig test nanocolor.zig
//
// When this file is run as an executable, the main function will be executed
// zig run nanocolor.zig
//
// To use this as a library, import it into your own Zig project
// const nanocolor = @import("nanocolor.zig");
//
// Then you can use the types and functions like this:
// var lib = nanocolor.ColorSpaceLibrary.init(allocator);
// defer lib.deinit();
// try lib.initColorSpaceLibrary();
// const srgb = lib.getNamedColorSpace("sRGB") orelse return error.ColorSpaceNotFound;
// ...