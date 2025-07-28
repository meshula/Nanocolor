#!/usr/bin/env python3
"""
Nanocolor - A very small color transform library (Python implementation)

Copyright 2024 Pixar
Licensed under the Apache License, Version 2.0

This is a Python implementation of the nanocolor library for color space 
transformations, based on SMPTE RP177-1993 equations.
"""

import math
from typing import List, NamedTuple, Optional, Dict
from dataclasses import dataclass


class Chromaticity(NamedTuple):
    """A single coordinate in the CIE 1931 xy chromaticity diagram."""
    x: float
    y: float


class XYZ(NamedTuple):
    """A coordinate in the CIE 1931 2-degree XYZ color space."""
    x: float
    y: float
    z: float


class Yxy(NamedTuple):
    """A chromaticity coordinate with luminance."""
    Y: float
    x: float
    y: float


class RGB(NamedTuple):
    """An rgb coordinate with no intrinsic color space."""
    r: float
    g: float
    b: float


class RGBA(NamedTuple):
    """RGB color with alpha channel."""
    r: float
    g: float
    b: float
    a: float

    @property
    def rgb(self) -> RGB:
        return RGB(self.r, self.g, self.b)


class M33f:
    """A 3x3 matrix of floats used for color space conversions.
    
    Stored in row major order, such that post-multiplying an RGB
    as a column vector by an M33f will yield another RGB column
    transformed by that matrix.
    """
    
    def __init__(self, m: List[float] = None):
        if m is None:
            self.m = [0.0] * 9
        else:
            if len(m) != 9:
                raise ValueError("Matrix must have exactly 9 elements")
            self.m = list(m)
    
    def __getitem__(self, index: int) -> float:
        return self.m[index]
    
    def __setitem__(self, index: int, value: float):
        self.m[index] = value
    
    def multiply(self, other: 'M33f') -> 'M33f':
        """Multiply this matrix by another matrix."""
        result = M33f()
        result.m[0] = self.m[0] * other.m[0] + self.m[1] * other.m[3] + self.m[2] * other.m[6]
        result.m[1] = self.m[0] * other.m[1] + self.m[1] * other.m[4] + self.m[2] * other.m[7]
        result.m[2] = self.m[0] * other.m[2] + self.m[1] * other.m[5] + self.m[2] * other.m[8]
        result.m[3] = self.m[3] * other.m[0] + self.m[4] * other.m[3] + self.m[5] * other.m[6]
        result.m[4] = self.m[3] * other.m[1] + self.m[4] * other.m[4] + self.m[5] * other.m[7]
        result.m[5] = self.m[3] * other.m[2] + self.m[4] * other.m[5] + self.m[5] * other.m[8]
        result.m[6] = self.m[6] * other.m[0] + self.m[7] * other.m[3] + self.m[8] * other.m[6]
        result.m[7] = self.m[6] * other.m[1] + self.m[7] * other.m[4] + self.m[8] * other.m[7]
        result.m[8] = self.m[6] * other.m[2] + self.m[7] * other.m[5] + self.m[8] * other.m[8]
        return result
    
    def invert(self) -> 'M33f':
        """Compute the inverse of this matrix."""
        inv = M33f()
        M0, M1, M2 = 0, 3, 6
        M3, M4, M5 = 1, 4, 7
        M6, M7, M8 = 2, 5, 8
        
        det = (self.m[M0] * (self.m[M4] * self.m[M8] - self.m[M5] * self.m[M7]) -
               self.m[M1] * (self.m[M3] * self.m[M8] - self.m[M5] * self.m[M6]) +
               self.m[M2] * (self.m[M3] * self.m[M7] - self.m[M4] * self.m[M6]))
        
        if abs(det) < 1e-10:
            raise ValueError("Matrix is not invertible (determinant near zero)")
        
        invdet = 1.0 / det
        inv.m[M0] = (self.m[M4] * self.m[M8] - self.m[M5] * self.m[M7]) * invdet
        inv.m[M1] = (self.m[M2] * self.m[M7] - self.m[M1] * self.m[M8]) * invdet
        inv.m[M2] = (self.m[M1] * self.m[M5] - self.m[M2] * self.m[M4]) * invdet
        inv.m[M3] = (self.m[M5] * self.m[M6] - self.m[M3] * self.m[M8]) * invdet
        inv.m[M4] = (self.m[M0] * self.m[M8] - self.m[M2] * self.m[M6]) * invdet
        inv.m[M5] = (self.m[M2] * self.m[M3] - self.m[M0] * self.m[M5]) * invdet
        inv.m[M6] = (self.m[M3] * self.m[M7] - self.m[M4] * self.m[M6]) * invdet
        inv.m[M7] = (self.m[M1] * self.m[M6] - self.m[M0] * self.m[M7]) * invdet
        inv.m[M8] = (self.m[M0] * self.m[M4] - self.m[M1] * self.m[M3]) * invdet
        return inv
    
    def transform_rgb(self, rgb: RGB) -> RGB:
        """Transform an RGB color by this matrix."""
        r = self.m[0] * rgb.r + self.m[1] * rgb.g + self.m[2] * rgb.b
        g = self.m[3] * rgb.r + self.m[4] * rgb.g + self.m[5] * rgb.b
        b = self.m[6] * rgb.r + self.m[7] * rgb.g + self.m[8] * rgb.b
        return RGB(r, g, b)


@dataclass
class ColorSpaceDescriptor:
    """Describes a color space with primaries, white point, and transfer function."""
    name: str
    red_primary: Chromaticity
    green_primary: Chromaticity
    blue_primary: Chromaticity
    white_point: Chromaticity
    gamma: float
    linear_bias: float


@dataclass
class ColorSpaceM33Descriptor:
    """Describes a color space defined in terms of a 3x3 matrix."""
    name: str
    rgb_to_xyz: M33f
    gamma: float
    linear_bias: float


class ColorSpace:
    """A color space object with computed transformation matrices."""
    
    def __init__(self, descriptor: ColorSpaceDescriptor):
        self.descriptor = descriptor
        self.k0 = 0.0
        self.phi = 0.0
        self.rgb_to_xyz = M33f()
        self._initialize()
    
    @classmethod
    def from_matrix(cls, descriptor: ColorSpaceM33Descriptor) -> 'ColorSpace':
        """Create a color space from a matrix descriptor."""
        # Create a dummy ColorSpaceDescriptor with zero white point to signal matrix init
        dummy_desc = ColorSpaceDescriptor(
            name=descriptor.name,
            red_primary=Chromaticity(0.0, 0.0),
            green_primary=Chromaticity(0.0, 0.0),
            blue_primary=Chromaticity(0.0, 0.0),
            white_point=Chromaticity(0.0, 0.0),
            gamma=descriptor.gamma,
            linear_bias=descriptor.linear_bias
        )
        cs = cls(dummy_desc)
        cs.rgb_to_xyz = descriptor.rgb_to_xyz
        return cs
    
    def _initialize(self):
        """Initialize the color space parameters."""
        a = self.descriptor.linear_bias
        gamma = self.descriptor.gamma
        
        if gamma == 1.0:
            self.k0 = 1e9
            self.phi = 1.0
        else:
            if a <= 0.0:
                self.k0 = 0.0
                self.phi = 1.0
            else:
                self.k0 = a / (gamma - 1.0)
                self.phi = (a / math.exp(math.log(gamma * a / (gamma + gamma * a - 1.0 - a)) * gamma)) / (gamma - 1.0)
        
        # If white point is zero, this was matrix-initialized, don't overwrite
        if self.descriptor.white_point.x == 0.0:
            return
        
        # Compute RGB to XYZ matrix using SMPTE RP 177-1993
        red = [self.descriptor.red_primary.x, 
               self.descriptor.red_primary.y, 
               1.0 - self.descriptor.red_primary.x - self.descriptor.red_primary.y]
        
        green = [self.descriptor.green_primary.x, 
                 self.descriptor.green_primary.y, 
                 1.0 - self.descriptor.green_primary.x - self.descriptor.green_primary.y]
        
        blue = [self.descriptor.blue_primary.x, 
                self.descriptor.blue_primary.y, 
                1.0 - self.descriptor.blue_primary.x - self.descriptor.blue_primary.y]
        
        white = [self.descriptor.white_point.x, 
                 self.descriptor.white_point.y, 
                 1.0 - self.descriptor.white_point.x - self.descriptor.white_point.y]
        
        # Build the P matrix by column binding red, green, and blue
        p = M33f([red[0], green[0], blue[0],
                  red[1], green[1], blue[1],
                  red[2], green[2], blue[2]])
        
        # White has luminance factor of 1.0, i.e., Y = 1
        W = [white[0] / white[1], white[1] / white[1], white[2] / white[1]]
        
        # Compute coefficients to scale primaries
        p_inv = p.invert()
        C = [p_inv.m[0] * W[0] + p_inv.m[1] * W[1] + p_inv.m[2] * W[2],
             p_inv.m[3] * W[0] + p_inv.m[4] * W[1] + p_inv.m[5] * W[2],
             p_inv.m[6] * W[0] + p_inv.m[7] * W[1] + p_inv.m[8] * W[2]]
        
        # Multiply P matrix by diagonal matrix of coefficients
        self.rgb_to_xyz = M33f([p.m[0] * C[0], p.m[1] * C[1], p.m[2] * C[2],
                                p.m[3] * C[0], p.m[4] * C[1], p.m[5] * C[2],
                                p.m[6] * C[0], p.m[7] * C[1], p.m[8] * C[2]])
    
    def from_linear(self, t: float) -> float:
        """Apply transfer function to convert from linear value."""
        if t < self.k0 / self.phi:
            return t * self.phi
        a = self.descriptor.linear_bias
        return (1.0 + a) * math.pow(t, 1.0 / self.descriptor.gamma) - a
    
    def to_linear(self, t: float) -> float:
        """Apply inverse transfer function to convert to linear value."""
        if t < self.k0:
            return t / self.phi
        a = self.descriptor.linear_bias
        return math.pow((t + a) / (1.0 + a), self.descriptor.gamma)
    
    def get_rgb_to_xyz_matrix(self) -> M33f:
        """Get the RGB to XYZ transformation matrix."""
        return self.rgb_to_xyz
    
    def get_xyz_to_rgb_matrix(self) -> M33f:
        """Get the XYZ to RGB transformation matrix."""
        return self.rgb_to_xyz.invert()
    
    def get_rgb_to_rgb_matrix(self, dst: 'ColorSpace') -> M33f:
        """Get the RGB to RGB transformation matrix to another color space."""
        return dst.get_xyz_to_rgb_matrix().multiply(self.rgb_to_xyz)
    
    def __eq__(self, other: 'ColorSpace') -> bool:
        """Check if two color spaces are equal."""
        if not isinstance(other, ColorSpace):
            return False
        return (self.descriptor.name == other.descriptor.name and
                self.descriptor.gamma == other.descriptor.gamma and
                self.descriptor.linear_bias == other.descriptor.linear_bias)


# White point chromaticities
WP_D65 = Chromaticity(0.3127, 0.3290)
WP_ACES = Chromaticity(0.32168, 0.33767)

# Predefined color spaces
COLOR_SPACES: Dict[str, ColorSpaceDescriptor] = {
    "acescg": ColorSpaceDescriptor(
        "acescg", Chromaticity(0.713, 0.293), Chromaticity(0.165, 0.830), 
        Chromaticity(0.128, 0.044), WP_ACES, 1.0, 0.0),
    
    "adobergb": ColorSpaceDescriptor(
        "adobergb", Chromaticity(0.64, 0.33), Chromaticity(0.21, 0.71), 
        Chromaticity(0.15, 0.06), WP_D65, 2.2, 0.0),
    
    "g18_ap1": ColorSpaceDescriptor(
        "g18_ap1", Chromaticity(0.713, 0.293), Chromaticity(0.165, 0.830), 
        Chromaticity(0.128, 0.044), WP_ACES, 1.8, 0.0),
    
    "g18_rec709": ColorSpaceDescriptor(
        "g18_rec709", Chromaticity(0.640, 0.330), Chromaticity(0.300, 0.600), 
        Chromaticity(0.150, 0.060), WP_D65, 1.8, 0.0),
    
    "g22_ap1": ColorSpaceDescriptor(
        "g22_ap1", Chromaticity(0.713, 0.293), Chromaticity(0.165, 0.830), 
        Chromaticity(0.128, 0.044), WP_ACES, 2.2, 0.0),
    
    "g22_rec709": ColorSpaceDescriptor(
        "g22_rec709", Chromaticity(0.640, 0.330), Chromaticity(0.300, 0.600), 
        Chromaticity(0.150, 0.060), WP_D65, 2.2, 0.0),
    
    "lin_adobergb": ColorSpaceDescriptor(
        "lin_adobergb", Chromaticity(0.64, 0.33), Chromaticity(0.21, 0.71), 
        Chromaticity(0.15, 0.06), WP_D65, 1.0, 0.0),
    
    "lin_ap0": ColorSpaceDescriptor(
        "lin_ap0", Chromaticity(0.7347, 0.2653), Chromaticity(0.0000, 1.0000), 
        Chromaticity(0.0001, -0.0770), WP_ACES, 1.0, 0.0),
    
    "lin_ap1": ColorSpaceDescriptor(
        "lin_ap1", Chromaticity(0.713, 0.293), Chromaticity(0.165, 0.830), 
        Chromaticity(0.128, 0.044), WP_ACES, 1.0, 0.0),
    
    "lin_displayp3": ColorSpaceDescriptor(
        "lin_displayp3", Chromaticity(0.6800, 0.3200), Chromaticity(0.2650, 0.6900), 
        Chromaticity(0.1500, 0.0600), WP_D65, 1.0, 0.0),
    
    "lin_rec709": ColorSpaceDescriptor(
        "lin_rec709", Chromaticity(0.640, 0.330), Chromaticity(0.300, 0.600), 
        Chromaticity(0.150, 0.060), WP_D65, 1.0, 0.0),
    
    "lin_rec2020": ColorSpaceDescriptor(
        "lin_rec2020", Chromaticity(0.708, 0.292), Chromaticity(0.170, 0.797), 
        Chromaticity(0.131, 0.046), WP_D65, 1.0, 0.0),
    
    "lin_srgb": ColorSpaceDescriptor(
        "lin_srgb", Chromaticity(0.640, 0.330), Chromaticity(0.300, 0.600), 
        Chromaticity(0.150, 0.060), WP_D65, 1.0, 0.0),
    
    "srgb_displayp3": ColorSpaceDescriptor(
        "srgb_displayp3", Chromaticity(0.6800, 0.3200), Chromaticity(0.2650, 0.6900), 
        Chromaticity(0.1500, 0.0600), WP_D65, 2.4, 0.055),
    
    "sRGB": ColorSpaceDescriptor(
        "sRGB", Chromaticity(0.640, 0.330), Chromaticity(0.300, 0.600), 
        Chromaticity(0.150, 0.060), WP_D65, 2.4, 0.055),
    
    "srgb_texture": ColorSpaceDescriptor(
        "srgb_texture", Chromaticity(0.640, 0.330), Chromaticity(0.300, 0.600), 
        Chromaticity(0.150, 0.060), WP_D65, 2.4, 0.055),
    
    "identity": ColorSpaceDescriptor(
        "identity", Chromaticity(1.0, 0.0), Chromaticity(0.0, 1.0), 
        Chromaticity(0.0, 0.0), Chromaticity(1.0/3.0, 1.0/3.0), 1.0, 0.0),
    
    "raw": ColorSpaceDescriptor(
        "raw", Chromaticity(1.0, 0.0), Chromaticity(0.0, 1.0), 
        Chromaticity(0.0, 0.0), Chromaticity(1.0/3.0, 1.0/3.0), 1.0, 0.0),
}

# Global color space library
_color_space_library: Dict[str, ColorSpace] = {}


def init_color_space_library():
    """Initialize the color space library with predefined color spaces."""
    global _color_space_library
    _color_space_library.clear()
    
    for name, descriptor in COLOR_SPACES.items():
        _color_space_library[name] = ColorSpace(descriptor)


def registered_color_space_names() -> List[str]:
    """Get the names of registered color spaces."""
    return list(_color_space_library.keys())


def get_named_color_space(name: str) -> Optional[ColorSpace]:
    """Get a color space by name."""
    return _color_space_library.get(name)


def create_color_space(descriptor: ColorSpaceDescriptor) -> ColorSpace:
    """Create a custom color space from a descriptor."""
    return ColorSpace(descriptor)


def create_color_space_m33(descriptor: ColorSpaceM33Descriptor) -> ColorSpace:
    """Create a custom color space from a matrix descriptor."""
    return ColorSpace.from_matrix(descriptor)


# Color transformation functions
def transform_color(dst: ColorSpace, src: ColorSpace, rgb: RGB) -> RGB:
    """Transform a color from one color space to another."""
    # Convert to linear in source space
    linear_rgb = RGB(src.to_linear(rgb.r), src.to_linear(rgb.g), src.to_linear(rgb.b))
    
    # Transform to destination color space via XYZ
    transformation_matrix = dst.get_xyz_to_rgb_matrix().multiply(src.get_rgb_to_xyz_matrix())
    transformed_linear = transformation_matrix.transform_rgb(linear_rgb)
    
    # Apply destination transfer function
    return RGB(dst.from_linear(transformed_linear.r), 
               dst.from_linear(transformed_linear.g), 
               dst.from_linear(transformed_linear.b))


def transform_colors(dst: ColorSpace, src: ColorSpace, rgb_list: List[RGB]) -> List[RGB]:
    """Transform a list of colors from one color space to another."""
    return [transform_color(dst, src, rgb) for rgb in rgb_list]


def rgb_to_xyz(cs: ColorSpace, rgb: RGB) -> XYZ:
    """Convert RGB to XYZ using the given color space."""
    linear_rgb = RGB(cs.to_linear(rgb.r), cs.to_linear(rgb.g), cs.to_linear(rgb.b))
    matrix = cs.get_rgb_to_xyz_matrix()
    x = matrix.m[0] * linear_rgb.r + matrix.m[1] * linear_rgb.g + matrix.m[2] * linear_rgb.b
    y = matrix.m[3] * linear_rgb.r + matrix.m[4] * linear_rgb.g + matrix.m[5] * linear_rgb.b
    z = matrix.m[6] * linear_rgb.r + matrix.m[7] * linear_rgb.g + matrix.m[8] * linear_rgb.b
    return XYZ(x, y, z)


def xyz_to_rgb(cs: ColorSpace, xyz: XYZ) -> RGB:
    """Convert XYZ to RGB using the given color space."""
    matrix = cs.get_xyz_to_rgb_matrix()
    linear_r = matrix.m[0] * xyz.x + matrix.m[1] * xyz.y + matrix.m[2] * xyz.z
    linear_g = matrix.m[3] * xyz.x + matrix.m[4] * xyz.y + matrix.m[5] * xyz.z
    linear_b = matrix.m[6] * xyz.x + matrix.m[7] * xyz.y + matrix.m[8] * xyz.z
    return RGB(cs.from_linear(linear_r), cs.from_linear(linear_g), cs.from_linear(linear_b))


def xyz_to_yxy(xyz: XYZ) -> Yxy:
    """Convert XYZ to Yxy."""
    sum_xyz = xyz.x + xyz.y + xyz.z
    if sum_xyz == 0.0:
        return Yxy(xyz.y, 0.0, 0.0)
    return Yxy(xyz.y, xyz.x / sum_xyz, xyz.y / sum_xyz)


def yxy_to_xyz(yxy: Yxy) -> XYZ:
    """Convert Yxy to XYZ."""
    if yxy.y == 0.0:
        return XYZ(0.0, 0.0, 0.0)
    x = yxy.Y * yxy.x / yxy.y
    z = yxy.Y * (1.0 - yxy.x - yxy.y) / yxy.y
    return XYZ(x, yxy.Y, z)


def yxy_to_rgb(cs: ColorSpace, yxy: Yxy) -> RGB:
    """Convert Yxy to RGB using the given color space."""
    xyz = yxy_to_xyz(yxy)
    return xyz_to_rgb(cs, xyz)


def kelvin_to_yxy(temperature: float, luminosity: float = 1.0) -> Yxy:
    """Convert blackbody temperature to Yxy chromaticity.
    
    Args:
        temperature: Temperature in Kelvin (1000-15000K)
        luminosity: Luminosity value (default 1.0)
    
    Returns:
        Yxy coordinate on the blackbody emission spectrum
    """
    # Clamp temperature to valid range
    temp = max(1000.0, min(15000.0, temperature))
    
    # Use McCamy's approximation for CCT to xy conversion
    # This is a simplified implementation - the C version likely uses more precise equations
    if temp < 4000:
        x = -0.2661239 * (1e9 / (temp * temp * temp)) - 0.2343589 * (1e6 / (temp * temp)) + 0.8776956 * (1e3 / temp) + 0.179910
    else:
        x = -3.0258469 * (1e9 / (temp * temp * temp)) + 2.1070379 * (1e6 / (temp * temp)) + 0.2226347 * (1e3 / temp) + 0.240390
    
    # Calculate y from x using Planckian locus approximation
    if temp < 2222:
        y = -1.1063814 * (x * x * x) - 1.34811020 * (x * x) + 2.18555832 * x - 0.20219683
    elif temp < 4000:
        y = -0.9549476 * (x * x * x) - 1.37418593 * (x * x) + 2.09137015 * x - 0.16748867
    else:
        y = 3.0817580 * (x * x * x) - 5.87338670 * (x * x) + 3.75112997 * x - 0.37001483
    
    return Yxy(luminosity, x, y)


def match_linear_color_space(red_primary: Chromaticity, 
                           green_primary: Chromaticity,
                           blue_primary: Chromaticity, 
                           white_point: Chromaticity,
                           epsilon: float = 1e-4) -> Optional[str]:
    """Match a linear color space based on primaries and white point.
    
    Args:
        red_primary: Red primary chromaticity
        green_primary: Green primary chromaticity
        blue_primary: Blue primary chromaticity
        white_point: White point chromaticity
        epsilon: Tolerance for comparison
    
    Returns:
        Name of matching color space or None if no match found
    """
    def chromaticity_close(c1: Chromaticity, c2: Chromaticity, eps: float) -> bool:
        return abs(c1.x - c2.x) < eps and abs(c1.y - c2.y) < eps
    
    for name, descriptor in COLOR_SPACES.items():
        # Only check linear color spaces (gamma = 1.0)
        if descriptor.gamma != 1.0:
            continue
            
        if (chromaticity_close(descriptor.red_primary, red_primary, epsilon) and
            chromaticity_close(descriptor.green_primary, green_primary, epsilon) and
            chromaticity_close(descriptor.blue_primary, blue_primary, epsilon) and
            chromaticity_close(descriptor.white_point, white_point, epsilon)):
            return name
    
    return None


# Initialize the library when the module is imported
init_color_space_library()


# Example usage and testing
if __name__ == "__main__":
    # Test basic functionality
    print("Nanocolor Python Implementation")
    print("Available color spaces:", registered_color_space_names())
    
    # Test color transformation
    srgb = get_named_color_space("sRGB")
    lin_srgb = get_named_color_space("lin_srgb")
    
    if srgb and lin_srgb:
        # Test sRGB to linear sRGB transformation
        test_color = RGB(0.5, 0.5, 0.5)  # Mid-gray in sRGB
        linear_color = transform_color(lin_srgb, srgb, test_color)
        print(f"sRGB {test_color} -> Linear sRGB {linear_color}")
        
        # Convert back
        back_to_srgb = transform_color(srgb, lin_srgb, linear_color)
        print(f"Linear sRGB {linear_color} -> sRGB {back_to_srgb}")
        
        # Test XYZ conversion
        xyz = rgb_to_xyz(srgb, test_color)
        print(f"sRGB {test_color} -> XYZ {xyz}")
        
        # Test Yxy conversion
        yxy = xyz_to_yxy(xyz)
        print(f"XYZ {xyz} -> Yxy {yxy}")
        
        # Test blackbody conversion
        kelvin_yxy = kelvin_to_yxy(6500.0)  # D65 white point approx
        print(f"6500K blackbody -> Yxy {kelvin_yxy}")
    
    # Test matrix operations
    identity = M33f([1, 0, 0, 0, 1, 0, 0, 0, 1])
    test_rgb = RGB(1.0, 0.5, 0.0)
    transformed = identity.transform_rgb(test_rgb)
    print(f"Identity transform {test_rgb} -> {transformed}")
    
    print("Basic tests completed.")