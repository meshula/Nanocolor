
example CoreGraphics bridge

```swift
// Initialize nanocolor
ColorSpaceLibrary.initColorSpaceLibrary()

// Get color spaces
guard let srgb = ColorSpaceLibrary.getNamedColorSpace("sRGB"),
      let acescg = ColorSpaceLibrary.getNamedColorSpace("acescg") else {
    fatalError("Could not load color spaces")
}

// Create a color in ACEScg
let acesgColor = RGB(r: 0.5, g: 0.3, b: 0.8)

// Convert to CGColor in ACEScg space
let cgColorACES = acesgColor.toCGColor(in: acescg)

// Transform to sRGB and create CGColor
let cgColorSRGB = acesgColor.toCGColor(from: acescg, to: srgb)

// Create CGColorSpace objects
let cgSRGB = srgb.toCGColorSpace()
let cgACEScg = acescg.toCGColorSpace()

// Use with color chips
let colorChecker = ColorChipSets.acesgColorCheckerChips[0] // dark_skin
let chipCGColor = CGColor.fromColorChip(colorChecker, colorSpace: acescg)

// Platform-specific usage
#if canImport(UIKit)
let uiColor = UIColor.fromNanocolor(acesgColor, colorSpace: srgb)
#endif

#if canImport(AppKit)
let nsColor = NSColor.fromNanocolor(acesgColor, colorSpace: srgb)
#endif

// Create cached CGColorSpaces for performance
let cgColorSpaceCache = ColorSpaceLibrary.createCGColorSpaceCache()
if let cachedSRGB = cgColorSpaceCache["sRGB"] {
    // Use cached color space for better performance
}
```
