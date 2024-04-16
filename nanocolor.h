//
// Copyright 2024 Pixar
//
// Licensed under the Apache License, Version 2.0 (the "Apache License")
// with the following modification; you may not use this file except in
// compliance with the Apache License and the following modification to it:
// Section 6. Trademarks. is deleted and replaced with:
//
// 6. Trademarks. This License does not grant permission to use the trade
//    names, trademarks, service marks, or product names of the Licensor
//    and its affiliates, except as required to comply with Section 4(c) of
//    the License and to reproduce the content of the NOTICE file.
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

#ifndef PXR_BASE_GF_NC_NANOCOLOR_H
#define PXR_BASE_GF_NC_NANOCOLOR_H

// NCNAMESPACE is provided to introduce a namespace to the symbols
// so that multiple libraries can include the nanocolor library
// without symbol conflicts. The default is nc_1_0_ to indicate the
// 1.0 version of Nanocolor.

// pxr: note that the PXR namespace macros are in pxr/pxr.h which
// is a C++ only header; so the generated namespace prefixes can't be
// used here.
#ifndef NCNAMESPACE
#define NCNAMESPACE pxr_nc_1_0_
#endif

// NCCONCAT is the means by which the namespace is applied to the symbols
// in the public interface.
#define NCCONCAT1(a, b) a ## b
#define NCCONCAT(a, b) NCCONCAT1(a, b)

// NCAPI may be overridden externally to control symbol visibility.
#ifndef NCAPI
#define NCAPI
#endif


// The base structs for nanocolor are not namespaced as they are meant
// to be compatible across libraries, including multiple namespaced
// versions of nanocolor. If the structs need to be modified in the future,
// they should be left in place, and new versions introduced with new names.
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

// NcRGB is an rgb coordinate with no intrinsic color space; it's merely
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
    const char*       name;
    NcCIEXYZ          redPrimary, greenPrimary, bluePrimary;
    NcXYChromaticity  whitePoint;
    float             gamma;      // gamma of log section
    float             linearBias; // where the linear section ends
} NcColorSpaceDescriptor;

typedef struct {
    const char*       name;
    NcM33f            rgbToXYZ;
    float             gamma;      // gamma of log section
    float             linearBias; // where the linear section ends
} NcColorSpaceM33Descriptor;

// Opaque struct for the public interface
typedef struct NcColorSpace NcColorSpace;

#ifdef __cplusplus
extern "C" {
#endif

/*
 The named color spaces provided by Nanocolor are as follows.
 Note that the names are shared with libraries such as MaterialX.

 - acescg:           The Academy Color Encoding System, a color space designed
                     for cinematic content creation and exchange, using AP1 primaries
 - adobergb:         A color space developed by Adobe Systems. It has a wider gamut
                     than sRGB and is suitable for photography and printing
 - g18_ap1:          A color space with a 1.8 gamma and an AP1 primaries color gamut
 - g18_rec709:       A color space with a 1.8 gamma, and primaries per the Rec. 709
                     standard, commonly used in HDTV
 - g22_ap1:          A color space with a 2.2 gamma and an AP1 primaries color gamut
 - g22_rec709:       A color space with a 2.2 gamma, and primaries per the Rec. 709
                     standard, commonly used in HDTV
 - identity:         Indicates that no transform is applied.
 - lin_adobergb:     The AdobeRGB gamut, and linear gamma
 - lin_ap0:          AP0 primaries, and linear gamma
 - lin_ap1:          AP1 primaries, and linear gamma; these are the ACESCg primaries
 - lin_displayp3:    DisplayP3 gamut, and linear gamma
 - lin_rec709:       A linearized version of the Rec. 709 color space.
 - lin_rec2020:      Rec2020 gamut, and linear gamma
 - lin_srgb:         sRGB gamut, linear gamma
 - raw:              Indicates that no transform is applied.
 - srgb_displayp3:   sRGB color space adapted to the Display P3 primaries
 - sRGB:             The sRGB color space.
 - srgb_texture:     The sRGB color space.
*/

#ifdef __cplusplus
#define NCEXTERNC extern "C" NCAPI
#else
#define NCEXTERNC extern NCAPI
#endif

NCEXTERNC const char* Nc_acescg;
NCEXTERNC const char* Nc_adobergb;
NCEXTERNC const char* Nc_g18_ap1;
NCEXTERNC const char* Nc_g18_rec709;
NCEXTERNC const char* Nc_g22_ap1;
NCEXTERNC const char* Nc_g22_rec709;
NCEXTERNC const char* Nc_identity;
NCEXTERNC const char* Nc_lin_adobergb;
NCEXTERNC const char* Nc_lin_ap0;
NCEXTERNC const char* Nc_lin_ap1;
NCEXTERNC const char* Nc_lin_displayp3;
NCEXTERNC const char* Nc_lin_rec709;
NCEXTERNC const char* Nc_lin_rec2020;
NCEXTERNC const char* Nc_lin_srgb;
NCEXTERNC const char* Nc_raw;
NCEXTERNC const char* Nc_srgb_displayp3;
NCEXTERNC const char* Nc_sRGB;
NCEXTERNC const char* Nc_srgb_texture;

// declare the public interface using a C style namespace macro
// this will allow several libraries to incorporate the nanocolor library
// directly as source without running into symbol or API conflicts.
// Change the namespace here to make the symbols unique.
// Recommended: Foo_nc_ to embed nanocolor in library Foo.
#define NcCreateColorSpace           NCCONCAT(NCNAMESPACE, InitColorSpace)
#define NcCreateColorSpaceM33        NCCONCAT(NCNAMESPACE, InitColorSpaceM33)
#define NcColorSpaceEqual            NCCONCAT(NCNAMESPACE, ColorSpaceEqual)
#define NcRegisteredColorSpaceNames  NCCONCAT(NCNAMESPACE, RegisteredColorSpaceNames)
#define NcGetNamedColorSpace   NCCONCAT(NCNAMESPACE, GetNamedColorSpace)
#define NcGetRGBToCIEXYZMatrix NCCONCAT(NCNAMESPACE, GetRGBtoCIEXYZMatrix)
#define NcGetCIEXYZToRGBMatrix NCCONCAT(NCNAMESPACE, etCIEXYZtoRGBMatrix)
#define NcGetRGBToRGBMatrix          NCCONCAT(NCNAMESPACE, GetRGBToRGBMatrix)
#define NcTransformColor       NCCONCAT(NCNAMESPACE, TransformColor)
#define NcTransformColorsWithAlpha   NCCONCAT(NCNAMESPACE, TransformColorsWithAlpha)
#define NcTransformColors            NCCONCAT(NCNAMESPACE, TransformColors)
#define NcRGBToXYZ             NCCONCAT(NCNAMESPACE, RGBToXYZ)
#define NcXYZToRGB             NCCONCAT(NCNAMESPACE, XYZToRGB)
#define NcGetColorSpaceDescriptor    NCCONCAT(NCNAMESPACE, GetColorSpaceDescriptor)
#define NcGetColorSpaceM33Descriptor NCCONCAT(NCNAMESPACE, GetColorSpaceM33Descriptor)
#define NcGetK0Phi                   NCCONCAT(NCNAMESPACE, GetK0Phi)
#define NcGetDescription             NCCONCAT(NCNAMESPACE, GetDescription)

NCAPI const NcColorSpace* NcCreateColorSpace(const NcColorSpaceDescriptor* cs);
NCAPI const NcColorSpace* NcCreateColorSpaceM33(const NcColorSpaceM33Descriptor* cs);
NCAPI const char**  NcRegisteredColorSpaceNames(void);
NCAPI const NcColorSpace* NcGetNamedColorSpace(const char* name);
NCAPI NcM33f        NcGetRGBToCIEXYZMatrix(const NcColorSpace* cs);
NCAPI NcM33f        NcGetCIEXYZToRGBMatrix(const NcColorSpace* cs);
NCAPI NcM33f        NcGetRGBToRGBMatrix(const NcColorSpace* src, const NcColorSpace* dst);
NCAPI NcRGB         NcTransformColor(const NcColorSpace* dst, const NcColorSpace* src, NcRGB rgb);
NCAPI void          NcTransformColors(const NcColorSpace* dst, const NcColorSpace* src, NcRGB* rgb, int count);
NCAPI void          NcTransformColorsWithAlpha(const NcColorSpace* dst, const NcColorSpace* src,
                                               float* rgba, int count);
NCAPI NcCIEXYZ      NcRGBToXYZ(const NcColorSpace* cs, NcRGB rgb);
NCAPI NcRGB         NcXYZToRGB(const NcColorSpace* cs, NcCIEXYZ xyz);
NCAPI bool          NcColorSpaceEqual(const NcColorSpace* cs1, const NcColorSpace* cs2);

// returns true if the colorspace descriptor was filled in
// Note that colorspaces initialized using a 3x3 matrix will not fill in the values.
NCAPI bool          NcGetColorSpaceDescriptor(const NcColorSpace* cs, NcColorSpaceDescriptor*);

// returns true if the colorspace descriptor was filled in
// All properly initialized colorspaces will be able to fill in the values.
NCAPI bool          NcGetColorSpaceM33Descriptor(const NcColorSpace* cs, NcColorSpaceM33Descriptor*);

// returns a string describing the color space.
NCAPI const char*  NcGetDescription(const NcColorSpace* cs);

NCAPI void          NcGetK0Phi(const NcColorSpace* cs, float* K0, float* phi);

#ifdef __cplusplus
}
#endif
#endif /* PXR_BASE_GF_NC_NANOCOLOR_H */
