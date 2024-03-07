//
// Copyright 2024 Pixar
//
// Licensed under the Apache License, Version 2.0 (the "Apache License")
//
// You may obtain a copy of the Apache License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the Apache License with the above modification is
// distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied. See the Apache License for the specific
// language governing permissions and limitations under the Apache License.
//

// NCAPI may be overridden externally to control symbol visibility.
#ifndef NCNAMESPACE
#define NCNAMESPACE pxr_nc_1_0_
#endif
#define NCCONCAT(a, b) a ## b
#ifndef NCAPI
#define NCAPI
#endif

#ifndef included_nanocolor_h
#define included_nanocolor_h

// The base structs for nanocolor are not namespaced, because
// they are designed to never need to be changed.
//
// The structs are prefixed with Nc for "nanocolor".

// NcXYChromaticity is a coordinate in the two dimensional chromaticity
// system used by the CIE 1931 XYZ color space.
typedef struct {
    float x, y;
} NcXYChromaticity;

// NcCIEXYZ is a coordinate in the perceptually uniform CIE 1931 XYZ
// color space.
typedef struct {
    float x, y, z;
} NcCIEXYZ;

// NcRGB is an rgb coordinate with no intrisic color space; it's merely
// a convenient way to store three named floats.
typedef struct {
    float r, g, b;
} NcRGB;

// NcM33f is a 3x3 matrix of floats used for color space conversions.
// It's stored in column major order, such that multiplying an NcRGB
// by an NcM33f will yield another NcRGB transformed by that matrix.
typedef struct {
    float m[9];
} NcM33f;

// If the transfer op is changed in the future, a new struct should be
// created and the old one should be left in place for backwards compatibility.

// Only gamma and a are free parameters
// gamma = 2.4 and a = .055 for sRGB
// K0 = a/(gamma-1.0)
// phi =  a / exp(ln(gamma * a / (gamma + gamma * a - 1.0 - a)) *  gamma) /  (gamma - 1.0)
// Solving yields K0 = .03928... and phi = 12.9232... 
//
// in use (where "^" is exponentiation):
// toLinear:   ifelse(t<K0, t/phi, ((t+a)/(1.0+a))^gamma)
// fromLinear: ifelse(t<K0/phi, phi*t, (1.0+a)*t^(1.0/gamma) - a)
//
// leaving gamma and a here - it's one way to go
// note we definitely want K0 here, as setting it to zero after construction allows non-lifted
// slope-limited gamma functions

typedef struct {
    float gamma;      // gamma of log section
    float linearBias; // linear bias of log section
    float K0;         // to linear break point; K0/phi for from linear
    float phi;        // slope of from linear section, use 1/phi if to linear
} NcTransferOp;

// If the color transform struct is changed in the future, a new struct should be
// created and the old one should be left in place for backwards compatibility.
//
// a given color space must be invertible;
// chaining a different transform on input/output is done by chaining colorpaces
typedef struct {
    NcTransferOp transfer;
    NcM33f       transform;
} NcColorTransform;

// If the color space struct is changed in the future, a new struct should be
// created and the old one should be left in place for backwards compatibility.
//
// The color space struct contains all the information needed to convert
// between the named color space and the CIE 1931 XYZ color space.
typedef struct {
    const char*       name;
    NcCIEXYZ          redPrimary, greenPrimary, bluePrimary;
    NcXYChromaticity  whitePoint;
    float             gamma;
    float             linearBias;
    NcColorTransform  colorTransform;
} NcColorSpace;

#ifdef __cplusplus
extern "C" {
#endif

/*
 The named color spaces provided by Nanocolor are as follows.
 Note that the names are shared with libraries such as MaterialX.

 - ACEScg:           The Academy Color Encoding System, a color space designed
                     for cinematic content creation and exchange, using AP1 primaries
 - Linear_AP1:       Alias for ACEScg. A linearized version of the ACEScg color space
 - G18_AP1:          A color space with a 1.8 gamma and an AP1 primaries color gamut
 - G22_AP1:          A color space with a 2.2 gamma and an AP1 primaries color gamut
 - G18_Rec709:       A color space with a 1.8 gamma, and primaries per the Rec. 709
                     standard, commonly used in HDTV
 - G22_Rec709:       A color space with a 2.2 gamma, and primaries per the Rec. 709
                     standard, commonly used in HDTV
 - Linear_Rec709:    A linearized version of the Rec. 709 color space.
 - AdobeRGB:         A color space developed by Adobe Systems. It has a wider gamut
                     than sRGB and is suitable for photography and printing
 - Linear_AdobeRGB:  The AdobeRGB gamut, and linear gamma
 - Linear_DisplayP3: DisplayP3 gamut, and linear gamma
 - Linear_sRGB:      sRGB gamut, linear gamma
 - sRGB_Texture:     An sRGB color space optimized for texture mapping.
 - sRGB_DisplayP3:   sRGB color space adapted to the Display P3 primaries
 - Linear_Rec2020:   Rec2020 gamut, and linear gamma
*/


// declare the public interface using a C style namespace macro
// this will allow several libraries to incorporate the nanocolor library
// directly as source without running into symbol or API conflicts.
// Change the namespace here to make the symbols unique.
// Recommended: Foo_nc_ to embed nanocolor in library Foo.
#define NcGetNamedColorSpace   NCCONCAT(NCNAMESPACE, GetNamedColorSpace)
#define NcGetRGBToCIEXYZMatrix NCCONCAT(NCNAMESPACE, GetRGBtoCIEXYZMatrix)
#define NcGetCIEXYZToRGBMatrix NCCONCAT(NCNAMESPACE, etCIEXYZtoRGBMatrix)
#define NcGetRGBToRGBTransform NCCONCAT(NCNAMESPACE, GetRGBToRGBTransform)
#define NcTransformColor       NCCONCAT(NCNAMESPACE, TransformColor)
#define NcRGBToXYZ             NCCONCAT(NCNAMESPACE, RGBToXYZ)
#define NcXYZToRGB             NCCONCAT(NCNAMESPACE, XYZToRGB)
#define NcInitColorSpace       NCCONCAT(NCNAMESPACE, InitColorSpace)
#define NcRegisteredColorSpaceNames NCCONCAT(NCNAMESPACE, RegisteredColorSpaceNames)

NCAPI NcColorSpace NcGetNamedColorSpace(const char* name);
NCAPI NcM33f       NcGetRGBToCIEXYZMatrix(NcColorSpace* cs);
NCAPI NcM33f       NcGetCIEXYZToRGBMatrix(NcColorSpace* cs);
NCAPI NcM33f       NcGetRGBToRGBTransform(NcColorSpace* src, NcColorSpace* dst);
NCAPI NcRGB        NcTransformColor(NcColorSpace* dst, NcColorSpace* src, NcRGB rgb);
NCAPI NcCIEXYZ     NcRGBToXYZ(NcColorSpace* cs, NcRGB rgb);
NCAPI NcRGB        NcXYZToRGB(NcColorSpace* cs, NcCIEXYZ xyz);
NCAPI void         NcInitColorSpace(NcColorSpace* cs);
NCAPI const char** NcRegisteredColorSpaceNames();

#ifdef __cplusplus
}
#endif
#endif /* included_nanocolor_h */
