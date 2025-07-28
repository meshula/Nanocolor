//
// Nanocolor to Core Graphics Bridge
//
// Provides seamless integration between nanocolor color management
// and Apple's Core Graphics framework.
//

import Foundation
import CoreGraphics

// MARK: - Core Graphics Integration

extension ColorSpace {
    
    /// Create a CGColorSpace from a nanocolor ColorSpace
    /// This maps nanocolor color spaces to their Core Graphics equivalents
    func toCGColorSpace() -> CGColorSpace? {
        // Get the RGB to XYZ matrix for this color space
        let rgbToXYZ = self.getRGBToXYZMatrix()
        
        // Map common nanocolor spaces to CG equivalents
        switch self.descriptor.name {
        case "sRGB", "srgb_texture":
            return CGColorSpace(name: CGColorSpace.sRGB)
            
        case "lin_srgb":
            return CGColorSpace(name: CGColorSpace.linearSRGB)
            
        case "lin_displayp3":
            return CGColorSpace(name: CGColorSpace.linearDisplayP3)
            
        case "srgb_displayp3":
            return CGColorSpace(name: CGColorSpace.displayP3)
            
        case "lin_rec2020":
            return CGColorSpace(name: CGColorSpace.linearITUR_2020)
            
        case "acescg", "lin_ap1":
            // ACES AP1 primaries - create custom color space
            return createCustomCGColorSpace(
                name: "ACEScg",
                redPrimary: Chromaticity(x: 0.713, y: 0.293),
                greenPrimary: Chromaticity(x: 0.165, y: 0.830),
                bluePrimary: Chromaticity(x: 0.128, y: 0.044),
                whitePoint: WhitePoints.ACES,
                gamma: 1.0
            )
            
        case "lin_ap0":
            // ACES AP0 primaries - create custom color space
            return createCustomCGColorSpace(
                name: "ACES2065-1",
                redPrimary: Chromaticity(x: 0.7347, y: 0.2653),
                greenPrimary: Chromaticity(x: 0.0000, y: 1.0000),
                bluePrimary: Chromaticity(x: 0.0001, y: -0.0770),
                whitePoint: WhitePoints.ACES,
                gamma: 1.0
            )
            
        case "adobergb":
            return createCustomCGColorSpace(
                name: "Adobe RGB",
                redPrimary: Chromaticity(x: 0.64, y: 0.33),
                greenPrimary: Chromaticity(x: 0.21, y: 0.71),
                bluePrimary: Chromaticity(x: 0.15, y: 0.06),
                whitePoint: WhitePoints.D65,
                gamma: 2.2
            )
            
        case "lin_adobergb":
            return createCustomCGColorSpace(
                name: "Linear Adobe RGB",
                redPrimary: Chromaticity(x: 0.64, y: 0.33),
                greenPrimary: Chromaticity(x: 0.21, y: 0.71),
                bluePrimary: Chromaticity(x: 0.15, y: 0.06),
                whitePoint: WhitePoints.D65,
                gamma: 1.0
            )
            
        case "g22_rec709":
            return CGColorSpace(name: CGColorSpace.itur_709)
            
        case "lin_rec709":
            return createCustomCGColorSpace(
                name: "Linear Rec.709",
                redPrimary: Chromaticity(x: 0.640, y: 0.330),
                greenPrimary: Chromaticity(x: 0.300, y: 0.600),
                bluePrimary: Chromaticity(x: 0.150, y: 0.060),
                whitePoint: WhitePoints.D65,
                gamma: 1.0
            )
            
        case "identity", "raw":
            // Generic RGB for identity transforms
            return CGColorSpace(name: CGColorSpace.genericRGB)
            
        default:
            // For custom color spaces, create from primaries
            return createCustomCGColorSpace(
                name: self.descriptor.name,
                redPrimary: self.descriptor.redPrimary,
                greenPrimary: self.descriptor.greenPrimary,
                bluePrimary: self.descriptor.bluePrimary,
                whitePoint: self.descriptor.whitePoint,
                gamma: self.descriptor.gamma
            )
        }
    }
    
    /// Create a custom CGColorSpace from chromaticity coordinates
    private func createCustomCGColorSpace(
        name: String,
        redPrimary: Chromaticity,
        greenPrimary: Chromaticity,
        bluePrimary: Chromaticity,
        whitePoint: Chromaticity,
        gamma: Float
    ) -> CGColorSpace? {
        
        // Convert chromaticity coordinates to CIE XYZ
        let redXYZ = chromaticityToXYZ(redPrimary)
        let greenXYZ = chromaticityToXYZ(greenPrimary)
        let blueXYZ = chromaticityToXYZ(bluePrimary)
        let whiteXYZ = chromaticityToXYZ(whitePoint, Y: 1.0)
        
        // Create matrix from primaries (column-major for Core Graphics)
        let matrix: [CGFloat] = [
            CGFloat(redXYZ.x), CGFloat(greenXYZ.x), CGFloat(blueXYZ.x),
            CGFloat(redXYZ.y), CGFloat(greenXYZ.y), CGFloat(blueXYZ.y),
            CGFloat(redXYZ.z), CGFloat(greenXYZ.z), CGFloat(blueXYZ.z)
        ]
        
        // Create white point array
        let whitePointArray: [CGFloat] = [CGFloat(whiteXYZ.x), CGFloat(whiteXYZ.y), CGFloat(whiteXYZ.z)]
        
        // Create gamma array (same for all channels for simplicity)
        let gammaArray: [CGFloat] = [CGFloat(gamma), CGFloat(gamma), CGFloat(gamma)]
        
        // Create the color space
        return CGColorSpace(
            calibratedRGBWhitePoint: whitePointArray,
            blackPoint: [0.0, 0.0, 0.0],
            gamma: gammaArray,
            matrix: matrix
        )
    }
    
    /// Helper to convert chromaticity to XYZ (assumes Y=1 unless specified)
    private func chromaticityToXYZ(_ chromaticity: Chromaticity, Y: Float = 1.0) -> (x: Float, y: Float, z: Float) {
        let x = Y * chromaticity.x / chromaticity.y
        let z = Y * (1.0 - chromaticity.x - chromaticity.y) / chromaticity.y
        return (x: x, y: Y, z: z)
    }
}

extension RGB {
    
    /// Create a CGColor from an RGB value using the specified color space
    /// - Parameters:
    ///   - colorSpace: The nanocolor ColorSpace to use
    ///   - alpha: Alpha component (default: 1.0)
    /// - Returns: A CGColor object, or nil if conversion fails
    func toCGColor(in colorSpace: ColorSpace, alpha: Float = 1.0) -> CGColor? {
        guard let cgColorSpace = colorSpace.toCGColorSpace() else {
            return nil
        }
        
        let components: [CGFloat] = [
            CGFloat(self.r),
            CGFloat(self.g),
            CGFloat(self.b),
            CGFloat(alpha)
        ]
        
        return CGColor(colorSpace: cgColorSpace, components: components)
    }
    
    /// Create a CGColor by transforming this RGB from one color space to another
    /// - Parameters:
    ///   - sourceSpace: Source nanocolor ColorSpace
    ///   - targetSpace: Target nanocolor ColorSpace  
    ///   - alpha: Alpha component (default: 1.0)
    /// - Returns: A CGColor in the target color space, or nil if conversion fails
    func toCGColor(from sourceSpace: ColorSpace, to targetSpace: ColorSpace, alpha: Float = 1.0) -> CGColor? {
        // Transform the color to target space
        let transformedRGB = transformColor(dst: targetSpace, src: sourceSpace, rgb: self)
        
        // Create CGColor in target space
        return transformedRGB.toCGColor(in: targetSpace, alpha: alpha)
    }
}

// MARK: - Convenience Extensions

extension CGColor {
    
    /// Create a CGColor from nanocolor RGB values
    /// - Parameters:
    ///   - r: Red component (0.0-1.0)
    ///   - g: Green component (0.0-1.0) 
    ///   - b: Blue component (0.0-1.0)
    ///   - colorSpace: Nanocolor ColorSpace
    ///   - alpha: Alpha component (0.0-1.0, default: 1.0)
    /// - Returns: CGColor instance or nil if creation fails
    static func fromNanocolor(
        r: Float, g: Float, b: Float,
        colorSpace: ColorSpace,
        alpha: Float = 1.0
    ) -> CGColor? {
        let rgb = RGB(r: r, g: g, b: b)
        return rgb.toCGColor(in: colorSpace, alpha: alpha)
    }
    
    /// Create a CGColor from a nanocolor color chip
    /// - Parameters:
    ///   - chip: ColorChip containing RGB values and metadata
    ///   - colorSpace: Nanocolor ColorSpace
    ///   - alpha: Alpha component (0.0-1.0, default: 1.0)
    /// - Returns: CGColor instance or nil if creation fails
    static func fromColorChip(
        _ chip: ColorChip,
        colorSpace: ColorSpace,
        alpha: Float = 1.0
    ) -> CGColor? {
        return chip.rgb.toCGColor(in: colorSpace, alpha: alpha)
    }
}

// MARK: - Usage Examples and Utilities

extension ColorSpaceLibrary {
    
    /// Create a dictionary of common CGColorSpaces mapped from nanocolor
    /// Useful for caching and lookup operations
    static func createCGColorSpaceCache() -> [String: CGColorSpace] {
        initColorSpaceLibrary()
        
        var cache: [String: CGColorSpace] = [:]
        
        let commonSpaces = [
            "sRGB", "lin_srgb", "srgb_displayp3", "lin_displayp3",
            "acescg", "lin_ap1", "lin_ap0", "adobergb", "lin_adobergb",
            "g22_rec709", "lin_rec709", "lin_rec2020"
        ]
        
        for spaceName in commonSpaces {
            if let nanocolorSpace = getNamedColorSpace(spaceName),
               let cgColorSpace = nanocolorSpace.toCGColorSpace() {
                cache[spaceName] = cgColorSpace
            }
        }
        
        return cache
    }
}

// MARK: - Platform-Specific Helpers

#if canImport(AppKit)
import AppKit

extension NSColor {
    
    /// Create an NSColor from nanocolor RGB values
    /// - Parameters:
    ///   - rgb: Nanocolor RGB struct
    ///   - colorSpace: Nanocolor ColorSpace
    ///   - alpha: Alpha component (0.0-1.0, default: 1.0)
    /// - Returns: NSColor instance or nil if creation fails
    static func fromNanocolor(
        _ rgb: RGB,
        colorSpace: ColorSpace,
        alpha: Float = 1.0
    ) -> NSColor? {
        guard let cgColor = rgb.toCGColor(in: colorSpace, alpha: alpha) else {
            return nil
        }
        return NSColor(cgColor: cgColor)
    }
}

#endif

#if canImport(UIKit)
import UIKit

extension UIColor {
    
    /// Create a UIColor from nanocolor RGB values
    /// - Parameters:
    ///   - rgb: Nanocolor RGB struct
    ///   - colorSpace: Nanocolor ColorSpace
    ///   - alpha: Alpha component (0.0-1.0, default: 1.0)
    /// - Returns: UIColor instance or nil if creation fails
    static func fromNanocolor(
        _ rgb: RGB,
        colorSpace: ColorSpace,
        alpha: Float = 1.0
    ) -> UIColor? {
        guard let cgColor = rgb.toCGColor(in: colorSpace, alpha: alpha) else {
            return nil
        }
        return UIColor(cgColor: cgColor)
    }
}

#endif