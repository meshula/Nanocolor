//
// Color Chip Generator for Nanocolor Swift
//
// Generates SMPTE 2065-1 / ACES color chips and reference patterns
// in any nanocolor color space.
//
// LICENSE: MIT License
// Copyright (c) 2025 Nick Porcino
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation

// MARK: - Color Chip Structures

struct ColorChip {
    let name: String
    let rgb: RGB
    let description: String
    
    init(name: String, rgb: RGB, description: String = "") {
        self.name = name
        self.rgb = rgb
        self.description = description
    }
}

extension ColorChip: CustomStringConvertible {
    var description: String {
        return "\(name): RGB(\(String(format: "%.6f", rgb.r)), \(String(format: "%.6f", rgb.g)), \(String(format: "%.6f", rgb.b)))"
    }
}

struct ColorChipSet {
    let name: String
    let colorSpace: String
    let chips: [ColorChip]
    
    init(name: String, colorSpace: String, chips: [ColorChip]) {
        self.name = name
        self.colorSpace = colorSpace
        self.chips = chips
    }
    
    func transformTo(targetSpace: String) throws -> ColorChipSet {
        guard let srcSpace = ColorSpaceLibrary.getNamedColorSpace(colorSpace),
              let dstSpace = ColorSpaceLibrary.getNamedColorSpace(targetSpace) else {
            throw ColorChipError.unknownColorSpace("Could not find color spaces: \(colorSpace) or \(targetSpace)")
        }
        
        let transformedChips = chips.map { chip in
            let transformedRGB = transformColor(dst: dstSpace, src: srcSpace, rgb: chip.rgb)
            return ColorChip(name: chip.name, rgb: transformedRGB, description: chip.description)
        }
        
        return ColorChipSet(name: name, colorSpace: targetSpace, chips: transformedChips)
    }
    
    func toCSV() -> String {
        var lines = ["# \(name) in \(colorSpace)", "Name,R,G,B,Description"]
        
        for chip in chips {
            lines.append("\(chip.name),\(chip.rgb.r),\(chip.rgb.g),\(chip.rgb.b),\(chip.description)")
        }
        
        return lines.joined(separator: "\n")
    }
    
    func toJSON() -> String {
        let chipData = chips.map { chip in
            return [
                "name": chip.name,
                "rgb": [chip.rgb.r, chip.rgb.g, chip.rgb.b],
                "description": chip.description
            ] as [String: Any]
        }
        
        let data: [String: Any] = [
            "name": name,
            "color_space": colorSpace,
            "chips": chipData
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: data, options: .prettyPrinted),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return "{\"error\": \"Failed to serialize JSON\"}"
        }
        
        return jsonString
    }
    
    func toText() -> String {
        var lines = [
            "# \(name) in \(colorSpace)",
            String(repeating: "=", count: 60)
        ]
        
        for chip in chips {
            lines.append(chip.description)
            if !chip.description.isEmpty {
                lines.append("    \(chip.description)")
            }
        }
        
        lines.append("")
        lines.append("Total: \(chips.count) color chips")
        
        return lines.joined(separator: "\n")
    }
}

// MARK: - Error Types

enum ColorChipError: Error {
    case unknownColorSpace(String)
    case unknownChipSet(String)
    case fileWriteError(String)
}

// MARK: - Predefined Color Chip Sets

class ColorChipSets {
    // ACEScg ColorChecker reference values
    static let acesgColorCheckerChips = [
        // Row 1 (top)
        ColorChip(name: "dark_skin", rgb: RGB(r: 0.4325, g: 0.3127, b: 0.2411), description: "ColorChecker patch 1"),
        ColorChip(name: "light_skin", rgb: RGB(r: 0.7787, g: 0.5925, b: 0.4733), description: "ColorChecker patch 2"),
        ColorChip(name: "blue_sky", rgb: RGB(r: 0.3570, g: 0.4035, b: 0.5733), description: "ColorChecker patch 3"),
        ColorChip(name: "foliage", rgb: RGB(r: 0.3369, g: 0.4219, b: 0.2797), description: "ColorChecker patch 4"),
        ColorChip(name: "blue_flower", rgb: RGB(r: 0.5479, g: 0.5434, b: 0.8156), description: "ColorChecker patch 5"),
        ColorChip(name: "bluish_green", rgb: RGB(r: 0.4708, g: 0.7749, b: 0.6411), description: "ColorChecker patch 6"),
        
        // Row 2
        ColorChip(name: "orange", rgb: RGB(r: 0.9309, g: 0.4471, b: 0.1330), description: "ColorChecker patch 7"),
        ColorChip(name: "purplish_blue", rgb: RGB(r: 0.2906, g: 0.3299, b: 0.6549), description: "ColorChecker patch 8"),
        ColorChip(name: "moderate_red", rgb: RGB(r: 0.7285, g: 0.3447, b: 0.4019), description: "ColorChecker patch 9"),
        ColorChip(name: "purple", rgb: RGB(r: 0.3174, g: 0.2210, b: 0.3394), description: "ColorChecker patch 10"),
        ColorChip(name: "yellow_green", rgb: RGB(r: 0.6157, g: 0.8067, b: 0.2482), description: "ColorChecker patch 11"),
        ColorChip(name: "orange_yellow", rgb: RGB(r: 0.9847, g: 0.7369, b: 0.1090), description: "ColorChecker patch 12"),
        
        // Row 3
        ColorChip(name: "blue", rgb: RGB(r: 0.2131, g: 0.2373, b: 0.6580), description: "ColorChecker patch 13"),
        ColorChip(name: "green", rgb: RGB(r: 0.2744, g: 0.5175, b: 0.2297), description: "ColorChecker patch 14"),
        ColorChip(name: "red", rgb: RGB(r: 0.6910, g: 0.1926, b: 0.1395), description: "ColorChecker patch 15"),
        ColorChip(name: "yellow", rgb: RGB(r: 0.9892, g: 0.9011, b: 0.1060), description: "ColorChecker patch 16"),
        ColorChip(name: "magenta", rgb: RGB(r: 0.7380, g: 0.3039, b: 0.6192), description: "ColorChecker patch 17"),
        ColorChip(name: "cyan", rgb: RGB(r: 0.1864, g: 0.6377, b: 0.7554), description: "ColorChecker patch 18"),
        
        // Row 4 (grayscale)
        ColorChip(name: "white", rgb: RGB(r: 0.9131, g: 0.9131, b: 0.9131), description: "ColorChecker patch 19 - White"),
        ColorChip(name: "neutral_8", rgb: RGB(r: 0.5894, g: 0.5894, b: 0.5894), description: "ColorChecker patch 20 - 80% gray"),
        ColorChip(name: "neutral_65", rgb: RGB(r: 0.3668, g: 0.3668, b: 0.3668), description: "ColorChecker patch 21 - 65% gray"),
        ColorChip(name: "neutral_5", rgb: RGB(r: 0.1903, g: 0.1903, b: 0.1903), description: "ColorChecker patch 22 - 50% gray (18%)"),
        ColorChip(name: "neutral_35", rgb: RGB(r: 0.0898, g: 0.0898, b: 0.0898), description: "ColorChecker patch 23 - 35% gray"),
        ColorChip(name: "black", rgb: RGB(r: 0.0313, g: 0.0313, b: 0.0313), description: "ColorChecker patch 24 - Black"),
    ]
    
    // SMPTE Color Bars
    static let smpteColorBars = [
        ColorChip(name: "white", rgb: RGB(r: 1.0, g: 1.0, b: 1.0), description: "100% white"),
        ColorChip(name: "yellow", rgb: RGB(r: 1.0, g: 1.0, b: 0.0), description: "100% yellow"),
        ColorChip(name: "cyan", rgb: RGB(r: 0.0, g: 1.0, b: 1.0), description: "100% cyan"),
        ColorChip(name: "green", rgb: RGB(r: 0.0, g: 1.0, b: 0.0), description: "100% green"),
        ColorChip(name: "magenta", rgb: RGB(r: 1.0, g: 0.0, b: 1.0), description: "100% magenta"),
        ColorChip(name: "red", rgb: RGB(r: 1.0, g: 0.0, b: 0.0), description: "100% red"),
        ColorChip(name: "blue", rgb: RGB(r: 0.0, g: 0.0, b: 1.0), description: "100% blue"),
        ColorChip(name: "black", rgb: RGB(r: 0.0, g: 0.0, b: 0.0), description: "0% black"),
    ]
    
    // Grayscale patches
    static let grayscalePatches = [
        ColorChip(name: "white_100", rgb: RGB(r: 1.0, g: 1.0, b: 1.0), description: "100% white"),
        ColorChip(name: "gray_90", rgb: RGB(r: 0.9, g: 0.9, b: 0.9), description: "90% gray"),
        ColorChip(name: "gray_80", rgb: RGB(r: 0.8, g: 0.8, b: 0.8), description: "80% gray"),
        ColorChip(name: "gray_70", rgb: RGB(r: 0.7, g: 0.7, b: 0.7), description: "70% gray"),
        ColorChip(name: "gray_60", rgb: RGB(r: 0.6, g: 0.6, b: 0.6), description: "60% gray"),
        ColorChip(name: "gray_50", rgb: RGB(r: 0.5, g: 0.5, b: 0.5), description: "50% gray"),
        ColorChip(name: "gray_40", rgb: RGB(r: 0.4, g: 0.4, b: 0.4), description: "40% gray"),
        ColorChip(name: "gray_30", rgb: RGB(r: 0.3, g: 0.3, b: 0.3), description: "30% gray"),
        ColorChip(name: "gray_20", rgb: RGB(r: 0.2, g: 0.2, b: 0.2), description: "20% gray"),
        ColorChip(name: "gray_18", rgb: RGB(r: 0.18, g: 0.18, b: 0.18), description: "18% gray (photographic mid-gray)"),
        ColorChip(name: "gray_10", rgb: RGB(r: 0.1, g: 0.1, b: 0.1), description: "10% gray"),
        ColorChip(name: "black_0", rgb: RGB(r: 0.0, g: 0.0, b: 0.0), description: "0% black"),
    ]
    
    // Spectral primaries
    static let spectralPrimaries = [
        ColorChip(name: "red_700nm", rgb: RGB(r: 1.0, g: 0.0, b: 0.0), description: "Approximate 700nm red"),
        ColorChip(name: "orange_600nm", rgb: RGB(r: 1.0, g: 0.5, b: 0.0), description: "Approximate 600nm orange"),
        ColorChip(name: "yellow_580nm", rgb: RGB(r: 1.0, g: 1.0, b: 0.0), description: "Approximate 580nm yellow"),
        ColorChip(name: "green_530nm", rgb: RGB(r: 0.0, g: 1.0, b: 0.0), description: "Approximate 530nm green"),
        ColorChip(name: "cyan_485nm", rgb: RGB(r: 0.0, g: 1.0, b: 1.0), description: "Approximate 485nm cyan"),
        ColorChip(name: "blue_450nm", rgb: RGB(r: 0.0, g: 0.0, b: 1.0), description: "Approximate 450nm blue"),
        ColorChip(name: "violet_400nm", rgb: RGB(r: 0.5, g: 0.0, b: 1.0), description: "Approximate 400nm violet"),
    ]
    
    static func getPredefinedChipSets() -> [String: ColorChipSet] {
        return [
            "colorchecker": ColorChipSet(name: "ColorChecker Classic", colorSpace: "acescg", chips: acesgColorCheckerChips),
            "smpte_bars": ColorChipSet(name: "SMPTE Color Bars", colorSpace: "lin_srgb", chips: smpteColorBars),
            "grayscale": ColorChipSet(name: "Grayscale Patches", colorSpace: "lin_srgb", chips: grayscalePatches),
            "spectral": ColorChipSet(name: "Spectral Primaries", colorSpace: "lin_srgb", chips: spectralPrimaries),
        ]
    }
    
    static func generateBlackbodySeries(startTemp: Float = 2000.0, endTemp: Float = 10000.0, steps: Int = 17) -> ColorChipSet {
        var chips: [ColorChip] = []
        
        for i in 0..<steps {
            let temp = startTemp + (endTemp - startTemp) * Float(i) / Float(steps - 1)
            let yxy = kelvinToYxy(temperature: temp, luminosity: 1.0)
            let xyz = yxyToXYZ(yxy)
            
            // Convert to linear sRGB as reference
            if let linSrgb = ColorSpaceLibrary.getNamedColorSpace("lin_srgb") {
                let rgb = xyzToRGB(cs: linSrgb, xyz: xyz)
                chips.append(ColorChip(name: "blackbody_\(Int(temp))K", rgb: rgb, description: "Blackbody at \(Int(temp))K"))
            }
        }
        
        return ColorChipSet(name: "Blackbody Temperature Series", colorSpace: "lin_srgb", chips: chips)
    }
}

// MARK: - Command Line Interface

class ColorChipGenerator {
    
    static func listColorSpaces() {
        print("Available color spaces:")
        for name in ColorSpaceLibrary.registeredColorSpaceNames().sorted() {
            print("  \(name)")
        }
    }
    
    static func listChipSets() {
        let chipSets = ColorChipSets.getPredefinedChipSets()
        print("Available chip sets:")
        for (key, chipSet) in chipSets.sorted(by: { $0.key < $1.key }) {
            print("  \(key): \(chipSet.name) (\(chipSet.chips.count) chips)")
        }
    }
    
    static func generateChips(chipSetName: String, targetSpace: String, format: String, outputFile: String?) throws {
        // Initialize nanocolor
        ColorSpaceLibrary.initColorSpaceLibrary()
        
        // Validate target color space
        guard ColorSpaceLibrary.getNamedColorSpace(targetSpace) != nil else {
            throw ColorChipError.unknownColorSpace("Unknown color space '\(targetSpace)'")
        }
        
        // Generate chip set
        let chipSet: ColorChipSet
        if chipSetName == "blackbody" {
            chipSet = ColorChipSets.generateBlackbodySeries()
        } else {
            let chipSets = ColorChipSets.getPredefinedChipSets()
            guard let baseChipSet = chipSets[chipSetName] else {
                throw ColorChipError.unknownChipSet("Unknown chip set '\(chipSetName)'")
            }
            chipSet = baseChipSet
        }
        
        // Transform to target space if needed
        let finalChipSet = chipSet.colorSpace != targetSpace ? try chipSet.transformTo(targetSpace: targetSpace) : chipSet
        
        // Generate output
        let output: String
        switch format {
        case "csv":
            output = finalChipSet.toCSV()
        case "json":
            output = finalChipSet.toJSON()
        default:
            output = finalChipSet.toText()
        }
        
        // Write output
        if let outputFile = outputFile {
            try output.write(toFile: outputFile, atomically: true, encoding: .utf8)
            print("Exported \(finalChipSet.chips.count) chips to \(outputFile)")
        } else {
            print(output)
        }
    }
    
    static func main() {
        let args = CommandLine.arguments
        
        guard args.count > 1 else {
            printUsage()
            return
        }
        
        var chipSet = "colorchecker"
        var targetSpace = "sRGB"
        var format = "text"
        var outputFile: String?
        
        var i = 1
        while i < args.count {
            switch args[i] {
            case "--chip-set", "-s":
                if i + 1 < args.count {
                    chipSet = args[i + 1]
                    i += 1
                }
            case "--target-space", "-t":
                if i + 1 < args.count {
                    targetSpace = args[i + 1]
                    i += 1
                }
            case "--format", "-f":
                if i + 1 < args.count {
                    format = args[i + 1]
                    i += 1
                }
            case "--output", "-o":
                if i + 1 < args.count {
                    outputFile = args[i + 1]
                    i += 1
                }
            case "--list-spaces", "-l":
                listColorSpaces()
                return
            case "--list-chip-sets":
                listChipSets()
                return
            case "--help", "-h":
                printUsage()
                return
            default:
                break
            }
            i += 1
        }
        
        do {
            try generateChips(chipSetName: chipSet, targetSpace: targetSpace, format: format, outputFile: outputFile)
        } catch {
            print("Error: \(error)")
        }
    }
    
    static func printUsage() {
        print("""
        Color Chip Generator for Nanocolor Swift
        
        Usage: swift run ColorChipGenerator [options]
        
        Options:
          --chip-set, -s <name>     Chip set to generate (colorchecker, smpte_bars, grayscale, spectral, blackbody)
          --target-space, -t <name> Target color space name (default: sRGB)
          --format, -f <format>     Output format (text, csv, json) (default: text)
          --output, -o <file>       Output filename (default: stdout)
          --list-spaces, -l         List available color spaces
          --list-chip-sets          List available chip sets
          --help, -h                Show this help
        
        Examples:
          swift run ColorChipGenerator --list-spaces
          swift run ColorChipGenerator -s colorchecker -t sRGB
          swift run ColorChipGenerator -s smpte_bars -t g22_rec709 -f csv -o smpte_rec709.csv
          swift run ColorChipGenerator -s blackbody -t acescg -f json -o blackbody_acescg.json
        """)
    }
}

// Entry point
ColorChipGenerator.main()