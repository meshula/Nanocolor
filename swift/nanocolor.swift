//
// Nanocolor - A very small color transform library (Swift implementation)
//
// Copyright 2024 Pixar
// Licensed under the Apache License, Version 2.0
//
// This is a Swift implementation of the nanocolor library for color space 
// transformations, based on SMPTE RP177-1993 equations.
//

import Foundation

// MARK: - Basic Types

/// A single coordinate in the CIE 1931 xy chromaticity diagram
public struct Chromaticity {
    public let x: Float
    public let y: Float
    
    public init(x: Float, y: Float) {
        self.x = x
        self.y = y
    }
}

/// A coordinate in the CIE 1931 2-degree XYZ color space
public struct XYZ {
    public let x: Float
    public let y: Float
    public let z: Float
    
    public init(x: Float, y: Float, z: Float) {
        self.x = x
        self.y = y
        self.z = z
    }
}

/// A chromaticity coordinate with luminance
public struct Yxy {
    public let Y: Float
    public let x: Float
    public let y: Float
    
    public init(Y: Float, x: Float, y: Float) {
        self.Y = Y
        self.x = x
        self.y = y
    }
}

/// An RGB coordinate with no intrinsic color space
public struct RGB {
    public let r: Float
    public let g: Float
    public let b: Float
    
    public init(r: Float, g: Float, b: Float) {
        self.r = r
        self.g = g
        self.b = b
    }
}

/// RGB color with alpha channel
public struct RGBA {
    public let r: Float
    public let g: Float
    public let b: Float
    public let a: Float
    
    public init(r: Float, g: Float, b: Float, a: Float) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }
    
    public var rgb: RGB {
        return RGB(r: r, g: g, b: b)
    }
}

// MARK: - Matrix Operations

/// A 3x3 matrix of floats used for color space conversions
/// Stored in row major order, such that post-multiplying an RGB
/// as a column vector by an M33f will yield another RGB column
/// transformed by that matrix
public struct M33f {
    public var m: [Float]
    
    public init() {
        self.m = Array(repeating: 0.0, count: 9)
    }
    
    public init(_ elements: [Float]) {
        guard elements.count == 9 else {
            fatalError("Matrix must have exactly 9 elements")
        }
        self.m = elements
    }
    
    public subscript(index: Int) -> Float {
        get { return m[index] }
        set { m[index] = newValue }
    }
    
    /// Multiply this matrix by another matrix
    public func multiply(_ other: M33f) -> M33f {
        var result = M33f()
        result.m[0] = m[0] * other.m[0] + m[1] * other.m[3] + m[2] * other.m[6]
        result.m[1] = m[0] * other.m[1] + m[1] * other.m[4] + m[2] * other.m[7]
        result.m[2] = m[0] * other.m[2] + m[1] * other.m[5] + m[2] * other.m[8]
        result.m[3] = m[3] * other.m[0] + m[4] * other.m[3] + m[5] * other.m[6]
        result.m[4] = m[3] * other.m[1] + m[4] * other.m[4] + m[5] * other.m[7]
        result.m[5] = m[3] * other.m[2] + m[4] * other.m[5] + m[5] * other.m[8]
        result.m[6] = m[6] * other.m[0] + m[7] * other.m[3] + m[8] * other.m[6]
        result.m[7] = m[6] * other.m[1] + m[7] * other.m[4] + m[8] * other.m[7]
        result.m[8] = m[6] * other.m[2] + m[7] * other.m[5] + m[8] * other.m[8]
        return result
    }
    
    /// Compute the inverse of this matrix
    public func invert() -> M33f {
        var inv = M33f()
        let M0 = 0, M1 = 3, M2 = 6
        let M3 = 1, M4 = 4, M5 = 7
        let M6 = 2, M7 = 5, M8 = 8
        
        let det = m[M0] * (m[M4] * m[M8] - m[M5] * m[M7]) -
                  m[M1] * (m[M3] * m[M8] - m[M5] * m[M6]) +
                  m[M2] * (m[M3] * m[M7] - m[M4] * m[M6])
        
        guard abs(det) > 1e-10 else {
            fatalError("Matrix is not invertible (determinant near zero)")
        }
        
        let invdet = 1.0 / det
        inv.m[M0] = (m[M4] * m[M8] - m[M5] * m[M7]) * invdet
        inv.m[M1] = (m[M2] * m[M7] - m[M1] * m[M8]) * invdet
        inv.m[M2] = (m[M1] * m[M5] - m[M2] * m[M4]) * invdet
        inv.m[M3] = (m[M5] * m[M6] - m[M3] * m[M8]) * invdet
        inv.m[M4] = (m[M0] * m[M8] - m[M2] * m[M6]) * invdet
        inv.m[M5] = (m[M2] * m[M3] - m[M0] * m[M5]) * invdet
        inv.m[M6] = (m[M3] * m[M7] - m[M4] * m[M6]) * invdet
        inv.m[M7] = (m[M1] * m[M6] - m[M0] * m[M7]) * invdet
        inv.m[M8] = (m[M0] * m[M4] - m[M1] * m[M3]) * invdet
        return inv
    }
    
    /// Transform an RGB color by this matrix
    public func transform(_ rgb: RGB) -> RGB {
        let r = m[0] * rgb.r + m[1] * rgb.g + m[2] * rgb.b
        let g = m[3] * rgb.r + m[4] * rgb.g + m[5] * rgb.b
        let b = m[6] * rgb.r + m[7] * rgb.g + m[8] * rgb.b
        return RGB(r: r, g: g, b: b)
    }
}

// MARK: - Color Space Descriptors

/// Describes a color space with primaries, white point, and transfer function
public struct ColorSpaceDescriptor {
    public let name: String
    public let redPrimary: Chromaticity
    public let greenPrimary: Chromaticity
    public let bluePrimary: Chromaticity
    public let whitePoint: Chromaticity
    public let gamma: Float
    public let linearBias: Float
    
    public init(name: String, redPrimary: Chromaticity, greenPrimary: Chromaticity,
                bluePrimary: Chromaticity, whitePoint: Chromaticity,
                gamma: Float, linearBias: Float) {
        self.name = name
        self.redPrimary = redPrimary
        self.greenPrimary = greenPrimary
        self.bluePrimary = bluePrimary
        self.whitePoint = whitePoint
        self.gamma = gamma
        self.linearBias = linearBias
    }
}

/// Describes a color space defined in terms of a 3x3 matrix
public struct ColorSpaceM33Descriptor {
    public let name: String
    public let rgbToXYZ: M33f
    public let gamma: Float
    public let linearBias: Float
    
    public init(name: String, rgbToXYZ: M33f, gamma: Float, linearBias: Float) {
        self.name = name
        self.rgbToXYZ = rgbToXYZ
        self.gamma = gamma
        self.linearBias = linearBias
    }
}

// MARK: - Color Space Implementation

/// A color space object with computed transformation matrices
public class ColorSpace {
    public let descriptor: ColorSpaceDescriptor
    public private(set) var k0: Float = 0.0
    public private(set) var phi: Float = 0.0
    public private(set) var rgbToXYZ: M33f = M33f()
    
    public init(descriptor: ColorSpaceDescriptor) {
        self.descriptor = descriptor
        initialize()
    }
    
    public static func fromMatrix(_ descriptor: ColorSpaceM33Descriptor) -> ColorSpace {
        // Create a dummy ColorSpaceDescriptor with zero white point to signal matrix init
        let dummyDesc = ColorSpaceDescriptor(
            name: descriptor.name,
            redPrimary: Chromaticity(x: 0.0, y: 0.0),
            greenPrimary: Chromaticity(x: 0.0, y: 0.0),
            bluePrimary: Chromaticity(x: 0.0, y: 0.0),
            whitePoint: Chromaticity(x: 0.0, y: 0.0),
            gamma: descriptor.gamma,
            linearBias: descriptor.linearBias
        )
        let cs = ColorSpace(descriptor: dummyDesc)
        cs.rgbToXYZ = descriptor.rgbToXYZ
        return cs
    }
    
    private func initialize() {
        let a = descriptor.linearBias
        let gamma = descriptor.gamma
        
        if gamma == 1.0 {
            k0 = 1e9
            phi = 1.0
        } else {
            if a <= 0.0 {
                k0 = 0.0
                phi = 1.0
            } else {
                k0 = a / (gamma - 1.0)
                phi = (a / exp(log(gamma * a / (gamma + gamma * a - 1.0 - a)) * gamma)) / (gamma - 1.0)
            }
        }
        
        // If white point is zero, this was matrix-initialized, don't overwrite
        if descriptor.whitePoint.x == 0.0 {
            return
        }
        
        // Compute RGB to XYZ matrix using SMPTE RP 177-1993
        let red = [descriptor.redPrimary.x, 
                   descriptor.redPrimary.y, 
                   1.0 - descriptor.redPrimary.x - descriptor.redPrimary.y]
        
        let green = [descriptor.greenPrimary.x, 
                     descriptor.greenPrimary.y, 
                     1.0 - descriptor.greenPrimary.x - descriptor.greenPrimary.y]
        
        let blue = [descriptor.bluePrimary.x, 
                    descriptor.bluePrimary.y, 
                    1.0 - descriptor.bluePrimary.x - descriptor.bluePrimary.y]
        
        let white = [descriptor.whitePoint.x, 
                     descriptor.whitePoint.y, 
                     1.0 - descriptor.whitePoint.x - descriptor.whitePoint.y]
        
        // Build the P matrix by column binding red, green, and blue
        var p = M33f([red[0], green[0], blue[0],
                      red[1], green[1], blue[1],
                      red[2], green[2], blue[2]])
        
        // White has luminance factor of 1.0, i.e., Y = 1
        let W = [white[0] / white[1], white[1] / white[1], white[2] / white[1]]
        
        // Compute coefficients to scale primaries
        let pInv = p.invert()
        let C = [pInv.m[0] * W[0] + pInv.m[1] * W[1] + pInv.m[2] * W[2],
                 pInv.m[3] * W[0] + pInv.m[4] * W[1] + pInv.m[5] * W[2],
                 pInv.m[6] * W[0] + pInv.m[7] * W[1] + pInv.m[8] * W[2]]
        
        // Multiply P matrix by diagonal matrix of coefficients
        rgbToXYZ = M33f([p.m[0] * C[0], p.m[1] * C[1], p.m[2] * C[2],
                         p.m[3] * C[0], p.m[4] * C[1], p.m[5] * C[2],
                         p.m[6] * C[0], p.m[7] * C[1], p.m[8] * C[2]])
    }
    
    /// Apply transfer function to convert from linear value
    public func fromLinear(_ t: Float) -> Float {
        if t < k0 / phi {
            return t * phi
        }
        let a = descriptor.linearBias
        return (1.0 + a) * pow(t, 1.0 / descriptor.gamma) - a
    }
    
    /// Apply inverse transfer function to convert to linear value
    public func toLinear(_ t: Float) -> Float {
        if t < k0 {
            return t / phi
        }
        let a = descriptor.linearBias
        return pow((t + a) / (1.0 + a), descriptor.gamma)
    }
    
    /// Get the RGB to XYZ transformation matrix
    public func getRGBToXYZMatrix() -> M33f {
        return rgbToXYZ
    }
    
    /// Get the XYZ to RGB transformation matrix
    public func getXYZToRGBMatrix() -> M33f {
        return rgbToXYZ.invert()
    }
    
    /// Get the RGB to RGB transformation matrix to another color space
    public func getRGBToRGBMatrix(to dst: ColorSpace) -> M33f {
        return dst.getXYZToRGBMatrix().multiply(rgbToXYZ)
    }
}

extension ColorSpace: Equatable {
    public static func == (lhs: ColorSpace, rhs: ColorSpace) -> Bool {
        return lhs.descriptor.name == rhs.descriptor.name &&
               lhs.descriptor.gamma == rhs.descriptor.gamma &&
               lhs.descriptor.linearBias == rhs.descriptor.linearBias
    }
}

// MARK: - Predefined Color Spaces

/// White point chromaticities
public struct WhitePoints {
    public static let D65 = Chromaticity(x: 0.3127, y: 0.3290)
    public static let ACES = Chromaticity(x: 0.32168, y: 0.33767)
}

/// Predefined color space descriptors
public struct ColorSpaces {
    public static let acescg = ColorSpaceDescriptor(
        name: "acescg", 
        redPrimary: Chromaticity(x: 0.713, y: 0.293), 
        greenPrimary: Chromaticity(x: 0.165, y: 0.830), 
        bluePrimary: Chromaticity(x: 0.128, y: 0.044), 
        whitePoint: WhitePoints.ACES, 
        gamma: 1.0, linearBias: 0.0)
    
    public static let adobergb = ColorSpaceDescriptor(
        name: "adobergb", 
        redPrimary: Chromaticity(x: 0.64, y: 0.33), 
        greenPrimary: Chromaticity(x: 0.21, y: 0.71), 
        bluePrimary: Chromaticity(x: 0.15, y: 0.06), 
        whitePoint: WhitePoints.D65, 
        gamma: 2.2, linearBias: 0.0)
    
    public static let g18_ap1 = ColorSpaceDescriptor(
        name: "g18_ap1", 
        redPrimary: Chromaticity(x: 0.713, y: 0.293), 
        greenPrimary: Chromaticity(x: 0.165, y: 0.830), 
        bluePrimary: Chromaticity(x: 0.128, y: 0.044), 
        whitePoint: WhitePoints.ACES, 
        gamma: 1.8, linearBias: 0.0)
    
    public static let g18_rec709 = ColorSpaceDescriptor(
        name: "g18_rec709", 
        redPrimary: Chromaticity(x: 0.640, y: 0.330), 
        greenPrimary: Chromaticity(x: 0.300, y: 0.600), 
        bluePrimary: Chromaticity(x: 0.150, y: 0.060), 
        whitePoint: WhitePoints.D65, 
        gamma: 1.8, linearBias: 0.0)
    
    public static let g22_ap1 = ColorSpaceDescriptor(
        name: "g22_ap1", 
        redPrimary: Chromaticity(x: 0.713, y: 0.293), 
        greenPrimary: Chromaticity(x: 0.165, y: 0.830), 
        bluePrimary: Chromaticity(x: 0.128, y: 0.044), 
        whitePoint: WhitePoints.ACES, 
        gamma: 2.2, linearBias: 0.0)
    
    public static let g22_rec709 = ColorSpaceDescriptor(
        name: "g22_rec709", 
        redPrimary: Chromaticity(x: 0.640, y: 0.330), 
        greenPrimary: Chromaticity(x: 0.300, y: 0.600), 
        bluePrimary: Chromaticity(x: 0.150, y: 0.060), 
        whitePoint: WhitePoints.D65, 
        gamma: 2.2, linearBias: 0.0)
    
    public static let lin_adobergb = ColorSpaceDescriptor(
        name: "lin_adobergb", 
        redPrimary: Chromaticity(x: 0.64, y: 0.33), 
        greenPrimary: Chromaticity(x: 0.21, y: 0.71), 
        bluePrimary: Chromaticity(x: 0.15, y: 0.06), 
        whitePoint: WhitePoints.D65, 
        gamma: 1.0, linearBias: 0.0)
    
    public static let lin_ap0 = ColorSpaceDescriptor(
        name: "lin_ap0", 
        redPrimary: Chromaticity(x: 0.7347, y: 0.2653), 
        greenPrimary: Chromaticity(x: 0.0000, y: 1.0000), 
        bluePrimary: Chromaticity(x: 0.0001, y: -0.0770), 
        whitePoint: WhitePoints.ACES, 
        gamma: 1.0, linearBias: 0.0)
    
    public static let lin_ap1 = ColorSpaceDescriptor(
        name: "lin_ap1", 
        redPrimary: Chromaticity(x: 0.713, y: 0.293), 
        greenPrimary: Chromaticity(x: 0.165, y: 0.830), 
        bluePrimary: Chromaticity(x: 0.128, y: 0.044), 
        whitePoint: WhitePoints.ACES, 
        gamma: 1.0, linearBias: 0.0)
    
    public static let lin_displayp3 = ColorSpaceDescriptor(
        name: "lin_displayp3", 
        redPrimary: Chromaticity(x: 0.6800, y: 0.3200), 
        greenPrimary: Chromaticity(x: 0.2650, y: 0.6900), 
        bluePrimary: Chromaticity(x: 0.1500, y: 0.0600), 
        whitePoint: WhitePoints.D65, 
        gamma: 1.0, linearBias: 0.0)
    
    public static let lin_rec709 = ColorSpaceDescriptor(
        name: "lin_rec709", 
        redPrimary: Chromaticity(x: 0.640, y: 0.330), 
        greenPrimary: Chromaticity(x: 0.300, y: 0.600), 
        bluePrimary: Chromaticity(x: 0.150, y: 0.060), 
        whitePoint: WhitePoints.D65, 
        gamma: 1.0, linearBias: 0.0)
    
    public static let lin_rec2020 = ColorSpaceDescriptor(
        name: "lin_rec2020", 
        redPrimary: Chromaticity(x: 0.708, y: 0.292), 
        greenPrimary: Chromaticity(x: 0.170, y: 0.797), 
        bluePrimary: Chromaticity(x: 0.131, y: 0.046), 
        whitePoint: WhitePoints.D65, 
        gamma: 1.0, linearBias: 0.0)
    
    public static let lin_srgb = ColorSpaceDescriptor(
        name: "lin_srgb", 
        redPrimary: Chromaticity(x: 0.640, y: 0.330), 
        greenPrimary: Chromaticity(x: 0.300, y: 0.600), 
        bluePrimary: Chromaticity(x: 0.150, y: 0.060), 
        whitePoint: WhitePoints.D65, 
        gamma: 1.0, linearBias: 0.0)
    
    public static let srgb_displayp3 = ColorSpaceDescriptor(
        name: "srgb_displayp3", 
        redPrimary: Chromaticity(x: 0.6800, y: 0.3200), 
        greenPrimary: Chromaticity(x: 0.2650, y: 0.6900), 
        bluePrimary: Chromaticity(x: 0.1500, y: 0.0600), 
        whitePoint: WhitePoints.D65, 
        gamma: 2.4, linearBias: 0.055)
    
    public static let sRGB = ColorSpaceDescriptor(
        name: "sRGB", 
        redPrimary: Chromaticity(x: 0.640, y: 0.330), 
        greenPrimary: Chromaticity(x: 0.300, y: 0.600), 
        bluePrimary: Chromaticity(x: 0.150, y: 0.060), 
        whitePoint: WhitePoints.D65, 
        gamma: 2.4, linearBias: 0.055)
    
    public static let srgb_texture = ColorSpaceDescriptor(
        name: "srgb_texture", 
        redPrimary: Chromaticity(x: 0.640, y: 0.330), 
        greenPrimary: Chromaticity(x: 0.300, y: 0.600), 
        bluePrimary: Chromaticity(x: 0.150, y: 0.060), 
        whitePoint: WhitePoints.D65, 
        gamma: 2.4, linearBias: 0.055)
    
    public static let identity = ColorSpaceDescriptor(
        name: "identity", 
        redPrimary: Chromaticity(x: 1.0, y: 0.0), 
        greenPrimary: Chromaticity(x: 0.0, y: 1.0), 
        bluePrimary: Chromaticity(x: 0.0, y: 0.0), 
        whitePoint: Chromaticity(x: 1.0/3.0, y: 1.0/3.0), 
        gamma: 1.0, linearBias: 0.0)
    
    public static let raw = ColorSpaceDescriptor(
        name: "raw", 
        redPrimary: Chromaticity(x: 1.0, y: 0.0), 
        greenPrimary: Chromaticity(x: 0.0, y: 1.0), 
        bluePrimary: Chromaticity(x: 0.0, y: 0.0), 
        whitePoint: Chromaticity(x: 1.0/3.0, y: 1.0/3.0), 
        gamma: 1.0, linearBias: 0.0)
}

// MARK: - Color Space Library

/// Global color space library
public class ColorSpaceLibrary {
    private static var colorSpaces: [String: ColorSpace] = [:]
    
    /// Initialize the color space library with predefined color spaces
    public static func initColorSpaceLibrary() {
        colorSpaces.removeAll()
        
        let predefinedSpaces: [ColorSpaceDescriptor] = [
            ColorSpaces.acescg, ColorSpaces.adobergb, ColorSpaces.g18_ap1, ColorSpaces.g18_rec709,
            ColorSpaces.g22_ap1, ColorSpaces.g22_rec709, ColorSpaces.lin_adobergb, ColorSpaces.lin_ap0,
            ColorSpaces.lin_ap1, ColorSpaces.lin_displayp3, ColorSpaces.lin_rec709, ColorSpaces.lin_rec2020,
            ColorSpaces.lin_srgb, ColorSpaces.srgb_displayp3, ColorSpaces.sRGB, ColorSpaces.srgb_texture,
            ColorSpaces.identity, ColorSpaces.raw
        ]
        
        for descriptor in predefinedSpaces {
            colorSpaces[descriptor.name] = ColorSpace(descriptor: descriptor)
        }
    }
    
    /// Get the names of registered color spaces
    public static func registeredColorSpaceNames() -> [String] {
        return Array(colorSpaces.keys).sorted()
    }
    
    /// Get a color space by name
    public static func getNamedColorSpace(_ name: String) -> ColorSpace? {
        return colorSpaces[name]
    }
    
    /// Create a custom color space from a descriptor
    public static func createColorSpace(descriptor: ColorSpaceDescriptor) -> ColorSpace {
        return ColorSpace(descriptor: descriptor)
    }
    
    /// Create a custom color space from a matrix descriptor
    public static func createColorSpaceM33(descriptor: ColorSpaceM33Descriptor) -> ColorSpace {
        return ColorSpace.fromMatrix(descriptor)
    }
}

// MARK: - Color Transformation Functions

/// Transform a color from one color space to another
public func transformColor(dst: ColorSpace, src: ColorSpace, rgb: RGB) -> RGB {
    // Convert to linear in source space
    let linearRGB = RGB(r: src.toLinear(rgb.r), g: src.toLinear(rgb.g), b: src.toLinear(rgb.b))
    
    // Transform to destination color space via XYZ
    let transformationMatrix = dst.getXYZToRGBMatrix().multiply(src.getRGBToXYZMatrix())
    let transformedLinear = transformationMatrix.transform(linearRGB)
    
    // Apply destination transfer function
    return RGB(r: dst.fromLinear(transformedLinear.r), 
               g: dst.fromLinear(transformedLinear.g), 
               b: dst.fromLinear(transformedLinear.b))
}

/// Transform an array of colors from one color space to another
public func transformColors(dst: ColorSpace, src: ColorSpace, rgbList: [RGB]) -> [RGB] {
    return rgbList.map { transformColor(dst: dst, src: src, rgb: $0) }
}

/// Convert RGB to XYZ using the given color space
public func rgbToXYZ(cs: ColorSpace, rgb: RGB) -> XYZ {
    let linearRGB = RGB(r: cs.toLinear(rgb.r), g: cs.toLinear(rgb.g), b: cs.toLinear(rgb.b))
    let matrix = cs.getRGBToXYZMatrix()
    let x = matrix.m[0] * linearRGB.r + matrix.m[1] * linearRGB.g + matrix.m[2] * linearRGB.b
    let y = matrix.m[3] * linearRGB.r + matrix.m[4] * linearRGB.g + matrix.m[5] * linearRGB.b
    let z = matrix.m[6] * linearRGB.r + matrix.m[7] * linearRGB.g + matrix.m[8] * linearRGB.b
    return XYZ(x: x, y: y, z: z)
}

/// Convert XYZ to RGB using the given color space
public func xyzToRGB(cs: ColorSpace, xyz: XYZ) -> RGB {
    let matrix = cs.getXYZToRGBMatrix()
    let linearR = matrix.m[0] * xyz.x + matrix.m[1] * xyz.y + matrix.m[2] * xyz.z
    let linearG = matrix.m[3] * xyz.x + matrix.m[4] * xyz.y + matrix.m[5] * xyz.z
    let linearB = matrix.m[6] * xyz.x + matrix.m[7] * xyz.y + matrix.m[8] * xyz.z
    return RGB(r: cs.fromLinear(linearR), g: cs.fromLinear(linearG), b: cs.fromLinear(linearB))
}

/// Convert XYZ to Yxy
public func xyzToYxy(_ xyz: XYZ) -> Yxy {
    let sum = xyz.x + xyz.y + xyz.z
    if sum == 0.0 {
        return Yxy(Y: xyz.y,return Yxy(Y: xyz.y, x: 0.0, y: 0.0)
    }
    return Yxy(Y: xyz.y, x: xyz.x / sum, y: xyz.y / sum)
}

/// Convert Yxy to XYZ
public func yxyToXYZ(_ yxy: Yxy) -> XYZ {
    if yxy.y == 0.0 {
        return XYZ(x: 0.0, y: 0.0, z: 0.0)
    }
    let x = yxy.Y * yxy.x / yxy.y
    let z = yxy.Y * (1.0 - yxy.x - yxy.y) / yxy.y
    return XYZ(x: x, y: yxy.Y, z: z)
}

/// Convert Yxy to RGB using the given color space
public func yxyToRGB(cs: ColorSpace, yxy: Yxy) -> RGB {
    let xyz = yxyToXYZ(yxy)
    return xyzToRGB(cs: cs, xyz: xyz)
}

/// Convert blackbody temperature to Yxy chromaticity
/// - Parameters:
///   - temperature: Temperature in Kelvin (1000-15000K)
///   - luminosity: Luminosity value (default 1.0)
/// - Returns: Yxy coordinate on the blackbody emission spectrum
public func kelvinToYxy(temperature: Float, luminosity: Float = 1.0) -> Yxy {
    // Clamp temperature to valid range
    let temp = max(1000.0, min(15000.0, temperature))
    
    // Use McCamy's approximation for CCT to xy conversion
    // This is a simplified implementation - the C version likely uses more precise equations
    let x: Float
    if temp < 4000 {
        x = -0.2661239 * (1e9 / (temp * temp * temp)) - 0.2343589 * (1e6 / (temp * temp)) + 0.8776956 * (1e3 / temp) + 0.179910
    } else {
        x = -3.0258469 * (1e9 / (temp * temp * temp)) + 2.1070379 * (1e6 / (temp * temp)) + 0.2226347 * (1e3 / temp) + 0.240390
    }
    
    // Calculate y from x using Planckian locus approximation
    let y: Float
    if temp < 2222 {
        y = -1.1063814 * (x * x * x) - 1.34811020 * (x * x) + 2.18555832 * x - 0.20219683
    } else if temp < 4000 {
        y = -0.9549476 * (x * x * x) - 1.37418593 * (x * x) + 2.09137015 * x - 0.16748867
    } else {
        y = 3.0817580 * (x * x * x) - 5.87338670 * (x * x) + 3.75112997 * x - 0.37001483
    }
    
    return Yxy(Y: luminosity, x: x, y: y)
}

/// Match a linear color space based on primaries and white point
/// - Parameters:
///   - redPrimary: Red primary chromaticity
///   - greenPrimary: Green primary chromaticity
///   - bluePrimary: Blue primary chromaticity
///   - whitePoint: White point chromaticity
///   - epsilon: Tolerance for comparison (default 1e-4)
/// - Returns: Name of matching color space or nil if no match found
public func matchLinearColorSpace(redPrimary: Chromaticity, 
                                 greenPrimary: Chromaticity,
                                 bluePrimary: Chromaticity, 
                                 whitePoint: Chromaticity,
                                 epsilon: Float = 1e-4) -> String? {
    
    func chromaticityClose(_ c1: Chromaticity, _ c2: Chromaticity, _ eps: Float) -> Bool {
        return abs(c1.x - c2.x) < eps && abs(c1.y - c2.y) < eps
    }
    
    let predefinedSpaces: [ColorSpaceDescriptor] = [
        ColorSpaces.acescg, ColorSpaces.adobergb, ColorSpaces.g18_ap1, ColorSpaces.g18_rec709,
        ColorSpaces.g22_ap1, ColorSpaces.g22_rec709, ColorSpaces.lin_adobergb, ColorSpaces.lin_ap0,
        ColorSpaces.lin_ap1, ColorSpaces.lin_displayp3, ColorSpaces.lin_rec709, ColorSpaces.lin_rec2020,
        ColorSpaces.lin_srgb, ColorSpaces.srgb_displayp3, ColorSpaces.sRGB, ColorSpaces.srgb_texture,
        ColorSpaces.identity, ColorSpaces.raw
    ]
    
    for descriptor in predefinedSpaces {
        // Only check linear color spaces (gamma = 1.0)
        if descriptor.gamma != 1.0 {
            continue
        }
        
        if chromaticityClose(descriptor.redPrimary, redPrimary, epsilon) &&
           chromaticityClose(descriptor.greenPrimary, greenPrimary, epsilon) &&
           chromaticityClose(descriptor.bluePrimary, bluePrimary, epsilon) &&
           chromaticityClose(descriptor.whitePoint, whitePoint, epsilon) {
            return descriptor.name
        }
    }
    
    return nil
}

// MARK: - Convenience Extensions

extension ColorSpace {
    /// Get K0 and phi values for the color space
    public func getK0Phi() -> (k0: Float, phi: Float) {
        return (k0: k0, phi: phi)
    }
    
    /// Get a description of the color space
    public func getDescription() -> String {
        return "ColorSpace '\(descriptor.name)' - Gamma: \(descriptor.gamma), LinearBias: \(descriptor.linearBias)"
    }
}

extension M33f: CustomStringConvertible {
    public var description: String {
        return """
        M33f:
        [\(m[0]), \(m[1]), \(m[2])]
        [\(m[3]), \(m[4]), \(m[5])]
        [\(m[6]), \(m[7]), \(m[8])]
        """
    }
}

extension RGB: CustomStringConvertible {
    public var description: String {
        return "RGB(r: \(r), g: \(g), b: \(b))"
    }
}

extension XYZ: CustomStringConvertible {
    public var description: String {
        return "XYZ(x: \(x), y: \(y), z: \(z))"
    }
}

extension Yxy: CustomStringConvertible {
    public var description: String {
        return "Yxy(Y: \(Y), x: \(x), y: \(y))"
    }
}

// MARK: - Example Usage and Testing

#if DEBUG
/// Example usage and testing functions
public class NanocolorTests {
    
    public static func runBasicTests() {
        print("Nanocolor Swift Implementation")
        
        // Initialize the library
        ColorSpaceLibrary.initColorSpaceLibrary()
        print("Available color spaces: \(ColorSpaceLibrary.registeredColorSpaceNames())")
        
        // Test color transformation
        guard let srgb = ColorSpaceLibrary.getNamedColorSpace("sRGB"),
              let linSrgb = ColorSpaceLibrary.getNamedColorSpace("lin_srgb") else {
            print("Error: Could not load sRGB color spaces")
            return
        }
        
        // Test sRGB to linear sRGB transformation
        let testColor = RGB(r: 0.5, g: 0.5, b: 0.5)  // Mid-gray in sRGB
        let linearColor = transformColor(dst: linSrgb, src: srgb, rgb: testColor)
        print("sRGB \(testColor) -> Linear sRGB \(linearColor)")
        
        // Convert back
        let backToSrgb = transformColor(dst: srgb, src: linSrgb, rgb: linearColor)
        print("Linear sRGB \(linearColor) -> sRGB \(backToSrgb)")
        
        // Test XYZ conversion
        let xyz = rgbToXYZ(cs: srgb, rgb: testColor)
        print("sRGB \(testColor) -> XYZ \(xyz)")
        
        // Test Yxy conversion
        let yxy = xyzToYxy(xyz)
        print("XYZ \(xyz) -> Yxy \(yxy)")
        
        // Test blackbody conversion
        let kelvinYxy = kelvinToYxy(temperature: 6500.0)  // D65 white point approx
        print("6500K blackbody -> Yxy \(kelvinYxy)")
        
        // Test matrix operations
        let identity = M33f([1, 0, 0, 0, 1, 0, 0, 0, 1])
        let testRgb = RGB(r: 1.0, g: 0.5, b: 0.0)
        let transformed = identity.transform(testRgb)
        print("Identity transform \(testRgb) -> \(transformed)")
        
        // Test matrix inversion
        let testMatrix = M33f([2, 0, 0, 0, 2, 0, 0, 0, 2])  // 2x scale matrix
        let inverted = testMatrix.invert()
        let shouldBeIdentity = testMatrix.multiply(inverted)
        print("Matrix inversion test - should be close to identity:")
        print(shouldBeIdentity)
        
        print("Basic tests completed.")
    }
    
    public static func performanceTest() {
        ColorSpaceLibrary.initColorSpaceLibrary()
        
        guard let srgb = ColorSpaceLibrary.getNamedColorSpace("sRGB"),
              let acescg = ColorSpaceLibrary.getNamedColorSpace("acescg") else {
            print("Error: Could not load color spaces for performance test")
            return
        }
        
        // Generate test colors
        var testColors: [RGB] = []
        for i in 0..<10000 {
            let f = Float(i) / 10000.0
            testColors.append(RGB(r: f, g: f * 0.5, b: f * 0.8))
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let _ = transformColors(dst: acescg, src: srgb, rgbList: testColors)
        let endTime = CFAbsoluteTimeGetCurrent()
        
        let duration = endTime - startTime
        let colorsPerSecond = Double(testColors.count) / duration
        
        print("Performance test: Transformed \(testColors.count) colors in \(duration) seconds")
        print("Rate: \(Int(colorsPerSecond)) colors/second")
    }
}
#endif