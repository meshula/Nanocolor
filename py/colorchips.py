#!/usr/bin/env python3
"""
ACES Color Chip Generator

Generates SMPTE 2065-1 / ACES color chips and reference patterns
in any nanocolor color space. Based on standard test patterns and
ColorChecker reference values.

License: MIT License
Copyright (c) 2025 Nick Porcino

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
"""

import sys
import os
sys.path.append(os.path.join(os.path.dirname(__file__), 'py'))

import nanocolor
import math
from typing import List, Tuple, Dict, Optional

class ColorChip:
    """Represents a single color chip with name and RGB values."""
    def __init__(self, name: str, rgb: nanocolor.RGB, description: str = ""):
        self.name = name
        self.rgb = rgb
        self.description = description
    
    def __str__(self):
        return f"{self.name}: RGB({self.rgb.r:.6f}, {self.rgb.g:.6f}, {self.rgb.b:.6f})"

class ColorChipSet:
    """A collection of color chips representing a standard test pattern."""
    def __init__(self, name: str, color_space: str, chips: List[ColorChip]):
        self.name = name
        self.color_space = color_space
        self.chips = chips
    
    def transform_to(self, target_space_name: str) -> 'ColorChipSet':
        """Transform all chips to a different color space."""
        src_space = nanocolor.get_named_color_space(self.color_space)
        dst_space = nanocolor.get_named_color_space(target_space_name)
        
        if not src_space or not dst_space:
            raise ValueError(f"Could not find color spaces: {self.color_space} or {target_space_name}")
        
        transformed_chips = []
        for chip in self.chips:
            transformed_rgb = nanocolor.transform_color(dst_space, src_space, chip.rgb)
            transformed_chips.append(ColorChip(chip.name, transformed_rgb, chip.description))
        
        return ColorChipSet(self.name, target_space_name, transformed_chips)
    
    def to_csv(self, filename: str):
        """Export chips to CSV format."""
        with open(filename, 'w') as f:
            f.write(f"# {self.name} in {self.color_space}\n")
            f.write("Name,R,G,B,Description\n")
            for chip in self.chips:
                f.write(f"{chip.name},{chip.rgb.r:.6f},{chip.rgb.g:.6f},{chip.rgb.b:.6f},{chip.description}\n")
    
    def to_json(self, filename: str):
        """Export chips to JSON format."""
        import json
        data = {
            "name": self.name,
            "color_space": self.color_space,
            "chips": [
                {
                    "name": chip.name,
                    "rgb": [chip.rgb.r, chip.rgb.g, chip.rgb.b],
                    "description": chip.description
                }
                for chip in self.chips
            ]
        }
        with open(filename, 'w') as f:
            json.dump(data, f, indent=2)

# ACES/ACEScg ColorChecker reference values
# Based on the ACESCentral community data and standard ColorChecker specifications
ACESCG_COLORCHECKER_CHIPS = [
    # Row 1 (top)
    ColorChip("dark_skin", nanocolor.RGB(0.4325, 0.3127, 0.2411), "ColorChecker patch 1"),
    ColorChip("light_skin", nanocolor.RGB(0.7787, 0.5925, 0.4733), "ColorChecker patch 2"),
    ColorChip("blue_sky", nanocolor.RGB(0.3570, 0.4035, 0.5733), "ColorChecker patch 3"),
    ColorChip("foliage", nanocolor.RGB(0.3369, 0.4219, 0.2797), "ColorChecker patch 4"),
    ColorChip("blue_flower", nanocolor.RGB(0.5479, 0.5434, 0.8156), "ColorChecker patch 5"),
    ColorChip("bluish_green", nanocolor.RGB(0.4708, 0.7749, 0.6411), "ColorChecker patch 6"),
    
    # Row 2
    ColorChip("orange", nanocolor.RGB(0.9309, 0.4471, 0.1330), "ColorChecker patch 7"),
    ColorChip("purplish_blue", nanocolor.RGB(0.2906, 0.3299, 0.6549), "ColorChecker patch 8"),
    ColorChip("moderate_red", nanocolor.RGB(0.7285, 0.3447, 0.4019), "ColorChecker patch 9"),
    ColorChip("purple", nanocolor.RGB(0.3174, 0.2210, 0.3394), "ColorChecker patch 10"),
    ColorChip("yellow_green", nanocolor.RGB(0.6157, 0.8067, 0.2482), "ColorChecker patch 11"),
    ColorChip("orange_yellow", nanocolor.RGB(0.9847, 0.7369, 0.1090), "ColorChecker patch 12"),
    
    # Row 3
    ColorChip("blue", nanocolor.RGB(0.2131, 0.2373, 0.6580), "ColorChecker patch 13"),
    ColorChip("green", nanocolor.RGB(0.2744, 0.5175, 0.2297), "ColorChecker patch 14"),
    ColorChip("red", nanocolor.RGB(0.6910, 0.1926, 0.1395), "ColorChecker patch 15"),
    ColorChip("yellow", nanocolor.RGB(0.9892, 0.9011, 0.1060), "ColorChecker patch 16"),
    ColorChip("magenta", nanocolor.RGB(0.7380, 0.3039, 0.6192), "ColorChecker patch 17"),
    ColorChip("cyan", nanocolor.RGB(0.1864, 0.6377, 0.7554), "ColorChecker patch 18"),
    
    # Row 4 (grayscale)
    ColorChip("white", nanocolor.RGB(0.9131, 0.9131, 0.9131), "ColorChecker patch 19 - White"),
    ColorChip("neutral_8", nanocolor.RGB(0.5894, 0.5894, 0.5894), "ColorChecker patch 20 - 80% gray"),
    ColorChip("neutral_65", nanocolor.RGB(0.3668, 0.3668, 0.3668), "ColorChecker patch 21 - 65% gray"),
    ColorChip("neutral_5", nanocolor.RGB(0.1903, 0.1903, 0.1903), "ColorChecker patch 22 - 50% gray (18%)"),
    ColorChip("neutral_35", nanocolor.RGB(0.0898, 0.0898, 0.0898), "ColorChecker patch 23 - 35% gray"),
    ColorChip("black", nanocolor.RGB(0.0313, 0.0313, 0.0313), "ColorChecker patch 24 - Black"),
]

# SMPTE Color Bars (traditional test pattern)
SMPTE_COLOR_BARS = [
    ColorChip("white", nanocolor.RGB(1.0, 1.0, 1.0), "100% white"),
    ColorChip("yellow", nanocolor.RGB(1.0, 1.0, 0.0), "100% yellow"),
    ColorChip("cyan", nanocolor.RGB(0.0, 1.0, 1.0), "100% cyan"),
    ColorChip("green", nanocolor.RGB(0.0, 1.0, 0.0), "100% green"),
    ColorChip("magenta", nanocolor.RGB(1.0, 0.0, 1.0), "100% magenta"),
    ColorChip("red", nanocolor.RGB(1.0, 0.0, 0.0), "100% red"),
    ColorChip("blue", nanocolor.RGB(0.0, 0.0, 1.0), "100% blue"),
    ColorChip("black", nanocolor.RGB(0.0, 0.0, 0.0), "0% black"),
]

# Basic grayscale test patches
GRAYSCALE_PATCHES = [
    ColorChip("white_100", nanocolor.RGB(1.0, 1.0, 1.0), "100% white"),
    ColorChip("gray_90", nanocolor.RGB(0.9, 0.9, 0.9), "90% gray"),
    ColorChip("gray_80", nanocolor.RGB(0.8, 0.8, 0.8), "80% gray"),
    ColorChip("gray_70", nanocolor.RGB(0.7, 0.7, 0.7), "70% gray"),
    ColorChip("gray_60", nanocolor.RGB(0.6, 0.6, 0.6), "60% gray"),
    ColorChip("gray_50", nanocolor.RGB(0.5, 0.5, 0.5), "50% gray"),
    ColorChip("gray_40", nanocolor.RGB(0.4, 0.4, 0.4), "40% gray"),
    ColorChip("gray_30", nanocolor.RGB(0.3, 0.3, 0.3), "30% gray"),
    ColorChip("gray_20", nanocolor.RGB(0.2, 0.2, 0.2), "20% gray"),
    ColorChip("gray_18", nanocolor.RGB(0.18, 0.18, 0.18), "18% gray (photographic mid-gray)"),
    ColorChip("gray_10", nanocolor.RGB(0.1, 0.1, 0.1), "10% gray"),
    ColorChip("black_0", nanocolor.RGB(0.0, 0.0, 0.0), "0% black"),
]

# Spectral primaries and secondaries
SPECTRAL_PRIMARIES = [
    ColorChip("red_700nm", nanocolor.RGB(1.0, 0.0, 0.0), "Approximate 700nm red"),
    ColorChip("orange_600nm", nanocolor.RGB(1.0, 0.5, 0.0), "Approximate 600nm orange"),
    ColorChip("yellow_580nm", nanocolor.RGB(1.0, 1.0, 0.0), "Approximate 580nm yellow"),
    ColorChip("green_530nm", nanocolor.RGB(0.0, 1.0, 0.0), "Approximate 530nm green"),
    ColorChip("cyan_485nm", nanocolor.RGB(0.0, 1.0, 1.0), "Approximate 485nm cyan"),
    ColorChip("blue_450nm", nanocolor.RGB(0.0, 0.0, 1.0), "Approximate 450nm blue"),
    ColorChip("violet_400nm", nanocolor.RGB(0.5, 0.0, 1.0), "Approximate 400nm violet"),
]

def get_predefined_chip_sets() -> Dict[str, ColorChipSet]:
    """Return all predefined color chip sets."""
    return {
        "colorchecker": ColorChipSet("ColorChecker Classic", "acescg", ACESCG_COLORCHECKER_CHIPS),
        "smpte_bars": ColorChipSet("SMPTE Color Bars", "lin_srgb", SMPTE_COLOR_BARS),
        "grayscale": ColorChipSet("Grayscale Patches", "lin_srgb", GRAYSCALE_PATCHES),
        "spectral": ColorChipSet("Spectral Primaries", "lin_srgb", SPECTRAL_PRIMARIES),
    }

def generate_blackbody_series(start_temp: float = 2000.0, end_temp: float = 10000.0, 
                            steps: int = 17) -> ColorChipSet:
    """Generate a series of blackbody radiator colors."""
    chips = []
    
    for i in range(steps):
        temp = start_temp + (end_temp - start_temp) * i / (steps - 1)
        yxy = nanocolor.kelvin_to_yxy(temp, 1.0)
        xyz = nanocolor.yxy_to_xyz(yxy)
        
        # Convert to linear sRGB as reference
        lin_srgb = nanocolor.get_named_color_space("lin_srgb")
        if lin_srgb:
            rgb = nanocolor.xyz_to_rgb(lin_srgb, xyz)
            chips.append(ColorChip(f"blackbody_{int(temp)}K", rgb, f"Blackbody at {int(temp)}K"))
    
    return ColorChipSet("Blackbody Temperature Series", "lin_srgb", chips)

def main():
    """Main CLI interface for color chip generation."""
    import argparse
    
    parser = argparse.ArgumentParser(description="Generate ACES/SMPTE color chips in any nanocolor color space")
    parser.add_argument("--chip-set", "-s", choices=["colorchecker", "smpte_bars", "grayscale", "spectral", "blackbody"], 
                       default="colorchecker", help="Which chip set to generate")
    parser.add_argument("--target-space", "-t", default="sRGB", help="Target color space name")
    parser.add_argument("--format", "-f", choices=["csv", "json", "text"], default="text", help="Output format")
    parser.add_argument("--output", "-o", help="Output filename (default: stdout)")
    parser.add_argument("--list-spaces", "-l", action="store_true", help="List available color spaces")
    parser.add_argument("--list-chip-sets", action="store_true", help="List available chip sets")
    
    args = parser.parse_args()
    
    # Initialize nanocolor
    nanocolor.init_color_space_library()
    
    if args.list_spaces:
        print("Available color spaces:")
        for name in sorted(nanocolor.registered_color_space_names()):
            print(f"  {name}")
        return
    
    if args.list_chip_sets:
        chip_sets = get_predefined_chip_sets()
        print("Available chip sets:")
        for name, chip_set in chip_sets.items():
            print(f"  {name}: {chip_set.name} ({len(chip_set.chips)} chips)")
        return
    
    # Validate target color space
    target_space = nanocolor.get_named_color_space(args.target_space)
    if not target_space:
        print(f"Error: Unknown color space '{args.target_space}'")
        print("Use --list-spaces to see available color spaces")
        return 1
    
    # Generate chip set
    if args.chip_set == "blackbody":
        chip_set = generate_blackbody_series()
    else:
        chip_sets = get_predefined_chip_sets()
        if args.chip_set not in chip_sets:
            print(f"Error: Unknown chip set '{args.chip_set}'")
            print("Use --list-chip-sets to see available chip sets")
            return 1
        chip_set = chip_sets[args.chip_set]
    
    # Transform to target space
    if chip_set.color_space != args.target_space:
        chip_set = chip_set.transform_to(args.target_space)
    
    # Output results
    if args.format == "csv" and args.output:
        chip_set.to_csv(args.output)
        print(f"Exported {len(chip_set.chips)} chips to {args.output}")
    elif args.format == "json" and args.output:
        chip_set.to_json(args.output)
        print(f"Exported {len(chip_set.chips)} chips to {args.output}")
    else:
        # Text output
        output_lines = []
        output_lines.append(f"# {chip_set.name} in {chip_set.color_space}")
        output_lines.append("=" * 60)
        
        for chip in chip_set.chips:
            output_lines.append(str(chip))
            if chip.description:
                output_lines.append(f"    {chip.description}")
        
        output_lines.append("")
        output_lines.append(f"Total: {len(chip_set.chips)} color chips")
        
        output_text = "\n".join(output_lines)
        
        if args.output:
            with open(args.output, 'w') as f:
                f.write(output_text)
            print(f"Exported {len(chip_set.chips)} chips to {args.output}")
        else:
            print(output_text)
    
    return 0

if __name__ == "__main__":
    exit(main())