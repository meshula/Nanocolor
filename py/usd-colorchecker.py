#!/usr/bin/env python3
"""
OpenUSD ColorChecker Generator

Generates ColorChecker Classic 24-patch reference charts as USD files
with accurate color space assignment and proper geometric layout.

Requires:
- OpenUSD Python bindings (pip install usd-core)
- nanocolor library

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
import argparse
from typing import List, Tuple, Optional
import math

# Add nanocolor to path
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'py'))
import nanocolor

try:
    from pxr import Usd, UsdGeom, UsdShade, Sdf, Gf, Vt
except ImportError:
    print("Error: OpenUSD Python bindings not found. Install with: pip install usd-core")
    sys.exit(1)


class USDColorChecker:
    """Generates ColorChecker layouts in USD format with proper color management."""
    
    # ColorChecker Classic 24-patch layout (4 rows × 6 columns)
    COLORCHECKER_LAYOUT = [
        # Row 1 (top) - Natural colors
        ["dark_skin", "light_skin", "blue_sky", "foliage", "blue_flower", "bluish_green"],
        # Row 2 - More natural colors  
        ["orange", "purplish_blue", "moderate_red", "purple", "yellow_green", "orange_yellow"],
        # Row 3 - Primary and secondary colors
        ["blue", "green", "red", "yellow", "magenta", "cyan"],
        # Row 4 (bottom) - Grayscale
        ["white", "neutral_8", "neutral_65", "neutral_5", "neutral_35", "black"]
    ]
    
    def __init__(self, color_space: str):
        """Initialize with target color space."""
        self.color_space = color_space
        self.chips = self._get_color_chips()
        
    def _get_color_chips(self) -> dict:
        """Get color chips transformed to target color space."""
        # Initialize nanocolor
        nanocolor.init_color_space_library()
        
        # Get ACEScg ColorChecker chips (our reference)
        acescg_chips = {
            # Row 1 (top)
            "dark_skin": nanocolor.RGB(0.4325, 0.3127, 0.2411),
            "light_skin": nanocolor.RGB(0.7787, 0.5925, 0.4733),
            "blue_sky": nanocolor.RGB(0.3570, 0.4035, 0.5733),
            "foliage": nanocolor.RGB(0.3369, 0.4219, 0.2797),
            "blue_flower": nanocolor.RGB(0.5479, 0.5434, 0.8156),
            "bluish_green": nanocolor.RGB(0.4708, 0.7749, 0.6411),
            
            # Row 2
            "orange": nanocolor.RGB(0.9309, 0.4471, 0.1330),
            "purplish_blue": nanocolor.RGB(0.2906, 0.3299, 0.6549),
            "moderate_red": nanocolor.RGB(0.7285, 0.3447, 0.4019),
            "purple": nanocolor.RGB(0.3174, 0.2210, 0.3394),
            "yellow_green": nanocolor.RGB(0.6157, 0.8067, 0.2482),
            "orange_yellow": nanocolor.RGB(0.9847, 0.7369, 0.1090),
            
            # Row 3
            "blue": nanocolor.RGB(0.2131, 0.2373, 0.6580),
            "green": nanocolor.RGB(0.2744, 0.5175, 0.2297),
            "red": nanocolor.RGB(0.6910, 0.1926, 0.1395),
            "yellow": nanocolor.RGB(0.9892, 0.9011, 0.1060),
            "magenta": nanocolor.RGB(0.7380, 0.3039, 0.6192),
            "cyan": nanocolor.RGB(0.1864, 0.6377, 0.7554),
            
            # Row 4 (grayscale)
            "white": nanocolor.RGB(0.9131, 0.9131, 0.9131),
            "neutral_8": nanocolor.RGB(0.5894, 0.5894, 0.5894),
            "neutral_65": nanocolor.RGB(0.3668, 0.3668, 0.3668),
            "neutral_5": nanocolor.RGB(0.1903, 0.1903, 0.1903),
            "neutral_35": nanocolor.RGB(0.0898, 0.0898, 0.0898),
            "black": nanocolor.RGB(0.0313, 0.0313, 0.0313),
        }
        
        # Transform to target color space if needed
        if self.color_space == "acescg":
            return acescg_chips
        
        acescg_space = nanocolor.get_named_color_space("acescg")
        target_space = nanocolor.get_named_color_space(self.color_space)
        
        if not acescg_space or not target_space:
            raise ValueError(f"Could not find color space: {self.color_space}")
        
        transformed_chips = {}
        for name, rgb in acescg_chips.items():
            transformed_rgb = nanocolor.transform_color(target_space, acescg_space, rgb)
            transformed_chips[name] = transformed_rgb
            
        return transformed_chips
    
    def generate_usd(self, output_path: str, physical_scale: float = 1.0) -> None:
        """Generate USD file with ColorChecker layout.
        
        Args:
            output_path: Path to output USD file
            physical_scale: Scale factor (1.0 = 1 unit per chip, useful for real-world scale)
        """
        # Create USD stage
        stage = Usd.Stage.CreateNew(output_path)
        
        # Set up stage metadata
        stage.SetMetadata("comment", f"ColorChecker Classic 24-patch chart in {self.color_space} color space")
        stage.SetMetadata("customLayerData", {
            "colorSpace": self.color_space,
            "generator": "nanocolor USD ColorChecker Generator",
            "chipCount": 24,
            "layout": "4x6 Classic"
        })
        
        # Define the default prim as a group
        default_prim = UsdGeom.Xform.Define(stage, "/ColorChecker")
        stage.SetDefaultPrim(default_prim.GetPrim())
        
        # Add color space metadata to the group
        default_prim.GetPrim().SetMetadata("customData", {
            "colorSpace": self.color_space,
            "description": f"ColorChecker Classic in {self.color_space}",
        })
        
        # Create material scope
        material_scope = UsdShade.MaterialBindingAPI.CreateMaterialScope(stage, "/ColorChecker/Materials")
        
        # Find white chip position to use as origin reference
        white_row, white_col = self._find_chip_position("white")
        white_x = white_col * physical_scale
        white_y = (3 - white_row) * physical_scale  # Flip Y so row 0 is at top
        
        # Offset to put white chip at origin, then shift everything to positive octant
        origin_offset_x = -white_x + 3.0 * physical_scale  # Shift 3 units into positive
        origin_offset_y = -white_y + 2.0 * physical_scale  # Shift 2 units into positive
        
        # Generate chips
        for row_idx, row in enumerate(self.COLORCHECKER_LAYOUT):
            for col_idx, chip_name in enumerate(row):
                self._create_chip(
                    stage, chip_name, row_idx, col_idx, 
                    physical_scale, origin_offset_x, origin_offset_y
                )
        
        # Create a light for viewing
        self._create_lighting(stage, physical_scale)
        
        # Create camera for viewing
        self._create_camera(stage, physical_scale)
        
        # Save the stage
        stage.GetRootLayer().Save()
        print(f"Generated USD ColorChecker: {output_path}")
        print(f"Color space: {self.color_space}")
        print(f"Layout: 4×6 Classic (24 patches)")
        print(f"Physical scale: {physical_scale}")
    
    def _find_chip_position(self, chip_name: str) -> Tuple[int, int]:
        """Find the row, column position of a chip."""
        for row_idx, row in enumerate(self.COLORCHECKER_LAYOUT):
            for col_idx, name in enumerate(row):
                if name == chip_name:
                    return row_idx, col_idx
        return 0, 0
    
    def _create_chip(self, stage: Usd.Stage, chip_name: str, row: int, col: int, 
                    scale: float, offset_x: float, offset_y: float) -> None:
        """Create a single color chip as a cube primitive."""
        
        # Calculate position (white chip at origin after offset)
        x = col * scale + offset_x
        y = (3 - row) * scale + offset_y  # Flip Y so row 0 is at top
        z = 0.0  # All chips in XY plane
        
        # Create cube primitive
        cube_path = f"/ColorChecker/Chips/chip_{row}_{col}_{chip_name}"
        cube_prim = UsdGeom.Cube.Define(stage, cube_path)
        
        # Set cube properties
        cube_prim.CreateSizeAttr().Set(scale * 0.95)  # Slightly smaller than unit for gaps
        cube_prim.CreateExtentAttr().Set([(-scale*0.475, -scale*0.475, -scale*0.475), 
                                         (scale*0.475, scale*0.475, scale*0.475)])
        
        # Position the cube
        cube_prim.AddTranslateOp().Set(Gf.Vec3d(x, y, z))
        
        # Add metadata
        cube_prim.GetPrim().SetMetadata("customData", {
            "chipName": chip_name,
            "row": row,
            "column": col,
            "colorSpace": self.color_space,
        })
        
        # Create and assign material
        self._create_and_assign_material(stage, cube_prim, chip_name)
    
    def _create_and_assign_material(self, stage: Usd.Stage, cube_prim: UsdGeom.Cube, chip_name: str) -> None:
        """Create a material with the chip's color and assign it."""
        
        # Get chip color
        chip_rgb = self.chips[chip_name]
        
        # Create material
        material_path = f"/ColorChecker/Materials/mat_{chip_name}"
        material = UsdShade.Material.Define(stage, material_path)
        
        # Create surface shader
        shader = UsdShade.Shader.Define(stage, f"{material_path}/surface")
        shader.CreateIdAttr("UsdPreviewSurface")
        
        # Set diffuse color
        shader.CreateInput("diffuseColor", Sdf.ValueTypeNames.Color3f).Set(
            Gf.Vec3f(chip_rgb.r, chip_rgb.g, chip_rgb.b)
        )
        
        # Set other material properties for a matte appearance
        shader.CreateInput("roughness", Sdf.ValueTypeNames.Float).Set(0.9)
        shader.CreateInput("metallic", Sdf.ValueTypeNames.Float).Set(0.0)
        shader.CreateInput("specularColor", Sdf.ValueTypeNames.Color3f).Set(Gf.Vec3f(0.04, 0.04, 0.04))
        
        # Connect shader to material
        material.CreateSurfaceOutput().ConnectToSource(shader.ConnectableAPI(), "surface")
        
        # Add color space metadata to material
        material.GetPrim().SetMetadata("customData", {
            "colorSpace": self.color_space,
            "chipName": chip_name,
            "originalRGB": [chip_rgb.r, chip_rgb.g, chip_rgb.b],
        })
        
        # Bind material to cube
        UsdShade.MaterialBindingAPI(cube_prim).Bind(material)
    
    def _create_lighting(self, stage: Usd.Stage, scale: float) -> None:
        """Create even lighting for viewing the chart."""
        
        # Create a dome light for even illumination
        dome_light = UsdLux.DomeLight.Define(stage, "/ColorChecker/Lighting/dome_light")
        dome_light.CreateIntensityAttr().Set(1.0)
        dome_light.CreateColorAttr().Set(Gf.Vec3f(1.0, 1.0, 1.0))
        
        # Add some directional fill light
        dir_light = UsdLux.DistantLight.Define(stage, "/ColorChecker/Lighting/key_light")
        dir_light.CreateIntensityAttr().Set(0.5)
        dir_light.CreateAngleAttr().Set(5.0)  # Soft light
        
        # Position and orient the directional light
        dir_light.AddRotateXOp().Set(45.0)  # 45 degrees down
        dir_light.AddRotateYOp().Set(45.0)  # 45 degrees around Y
    
    def _create_camera(self, stage: Usd.Stage, scale: float) -> None:
        """Create a camera positioned to view the entire chart."""
        
        # Calculate chart bounds
        chart_width = 6 * scale
        chart_height = 4 * scale
        chart_center_x = 2.5 * scale
        chart_center_y = 1.5 * scale
        
        # Position camera to see entire chart
        camera_distance = max(chart_width, chart_height) * 1.5
        camera_height = chart_center_y + camera_distance * 0.3
        
        camera = UsdGeom.Camera.Define(stage, "/ColorChecker/Camera/main_camera")
        
        # Set camera position (looking down at chart)
        camera.AddTranslateOp().Set(Gf.Vec3d(chart_center_x, camera_height, camera_distance))
        
        # Point camera at chart center
        camera.AddRotateXOp().Set(-15.0)  # Look down slightly
        
        # Set camera parameters
        camera.CreateFocalLengthAttr().Set(50.0)  # Standard lens
        camera.CreateClippingRangeAttr().Set(Gf.Vec2f(0.1, 1000.0))


def clean_color_space_name(color_space: str) -> str:
    """Clean color space name for use in filename."""
    # Replace common characters that might cause issues
    return color_space.replace("_", "").replace("-", "").replace(".", "").lower()


def main():
    """Main CLI interface."""
    parser = argparse.ArgumentParser(
        description="Generate ColorChecker Classic as USD file with accurate color management"
    )
    parser.add_argument(
        "--color-space", "-c", 
        default="sRGB",
        help="Target color space name (default: sRGB)"
    )
    parser.add_argument(
        "--output", "-o",
        help="Output filename (default: colorchecker-{colorspace}.usda)"
    )
    parser.add_argument(
        "--scale", "-s",
        type=float,
        default=1.0,
        help="Physical scale factor (default: 1.0 unit per chip)"
    )
    parser.add_argument(
        "--list-spaces", "-l",
        action="store_true",
        help="List available color spaces"
    )
    parser.add_argument(
        "--ascii", "-a",
        action="store_true",
        help="Output ASCII USD format (.usda) instead of binary (.usd)"
    )
    
    args = parser.parse_args()
    
    # Initialize nanocolor
    nanocolor.init_color_space_library()
    
    if args.list_spaces:
        print("Available color spaces:")
        for name in sorted(nanocolor.registered_color_space_names()):
            print(f"  {name}")
        return 0
    
    # Validate color space
    if not nanocolor.get_named_color_space(args.color_space):
        print(f"Error: Unknown color space '{args.color_space}'")
        print("Use --list-spaces to see available color spaces")
        return 1
    
    # Generate output filename
    if args.output:
        output_path = args.output
    else:
        clean_name = clean_color_space_name(args.color_space)
        extension = ".usda" if args.ascii else ".usd"
        output_path = f"colorchecker-{clean_name}{extension}"
    
    # Create USD ColorChecker
    try:
        checker = USDColorChecker(args.color_space)
        checker.generate_usd(output_path, args.scale)
        
        print(f"\nTo view the result:")
        print(f"  usdview {output_path}")
        print(f"\nChart layout:")
        print("  4 rows × 6 columns (ColorChecker Classic)")
        print("  White chip positioned at origin (before positive octant shift)")
        print("  All chips in XY plane (Z=0)")
        print(f"  Physical scale: {args.scale} units per chip")
        
        return 0
        
    except Exception as e:
        print(f"Error generating USD file: {e}")
        return 1


if __name__ == "__main__":
    sys.exit(main())