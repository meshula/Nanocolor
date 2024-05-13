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

#include "nanocolorUtils.h"
#include <math.h>

/*
    This is actually u'v', u'v' is uv scaled by 1.5 along the v axis
*/

typedef struct {
    float Y;
    float u;
    float v;
} NcYuvPrime;

NcYxy _NcYuv2Yxy(NcYuvPrime c) {
    float d = 6.f * c.u - 16.f * c.v + 12.f;
    return (NcYxy) {
        c.Y,
        9.f * c.u / d,
        4.f * c.v / d
    };
}

/* Equations from the paper "An Algorithm to Calculate Correlated Colour 
   Temperature" by M. Krystek in 1985, using a rational Chebyshev approximation 
   designed.
*/
NcYxy NcKelvinToYxy(float T, float luminance) {
    if (T < 1000 || T > 15000)
        return (NcYxy) { 0, 0, 0 };

    float u = (0.860117757 + 1.54118254e-4 * T + 1.2864121e-7 * T * T) /
              (1.0 + 8.42420235e-4 * T + 7.08145163e-7 * T * T);
    float v = (0.317398726 + 4.22806245e-5 * T + 4.20481691e-8 * T * T) /
              (1.0 - 2.89741816e-5 * T + 1.61456053e-7 * T * T);

    return _NcYuv2Yxy((NcYuvPrime) {luminance, u, 3.f * v / 2.f });
}

// ISO 17321-1:2012 Table D.1
// ap0 is the aces name for 2065-1
/*
 CIE 1931
 AP0: ACES 2065-1             White Point  AP1: cg, cc, cct, proxy
 red     green   blue                 red    green  blue
 x        0.7347  0.0000  0.0001    0.32168    0.713  0.165  0.128
 y        0.2653  1.0000 -0.0770    0.33767    0.293  0.830  0.044
 */

static NcRGB _ISO17321_ap0[24] = {
    { 0.11877f, 0.08709f, 0.05895f }, // patch 1
    { 0.40003f, 0.31916f, 0.23737f }, // patch 2
    { 0.18476f, 0.20398f, 0.31310f }, // patch 3
    { 0.10901f, 0.13511f, 0.06493f }, // patch 4
    { 0.26684f, 0.24604f, 0.40932f }, // patch 5
    { 0.32283f, 0.46208f, 0.40606f }, // patch 6
    { 0.38607f, 0.22744f, 0.05777f }, // patch 7
    { 0.13822f, 0.13037f, 0.33703f }, // patch 8
    { 0.30203f, 0.13752f, 0.12758f }, // patch 9
    { 0.09310f, 0.06347f, 0.13525f },
    { 0.34877f, 0.43655f, 0.10613f },
    { 0.48657f, 0.36686f, 0.08061f },
    { 0.08731f, 0.07443f, 0.27274f },
    { 0.15366f, 0.25692f, 0.09071f },
    { 0.21743f, 0.07070f, 0.05130f },
    { 0.58921f, 0.53944f, 0.09157f },
    { 0.30904f, 0.14818f, 0.27426f },
    { 0.14900f, 0.23377f, 0.35939f }, // out of gamut r709, R could be in error
    { 0.86653f, 0.86792f, 0.85818f },
    { 0.57356f, 0.57256f, 0.57169f },
    { 0.35346f, 0.35337f, 0.35391f },
    { 0.20253f, 0.20243f, 0.20287f },
    { 0.09467f, 0.09520f, 0.09637f },
    { 0.03745f, 0.03766f, 0.03895f }, // patch 24
};

// these measurements are under Illuminant C, which is not normative
// https://home.cis.rit.edu/~cnspci/references/mccamy1976.pdf

static NcYxy _McCamy1976_Yxy[24] = {
    { 10.10, 0.400, 0.350 },
    { 35.80, 0.377, 0.345 },
    { 19.30, 0.247, 0.251 },
    { 13.30, 0.337, 0.422 },
    { 24.30, 0.265, 0.240 },
    { 43.10, 0.261, 0.343 },
    { 30.10, 0.506, 0.407 },
    { 12.00, 0.211, 0.175 },
    { 19.80, 0.453, 0.306 },
    {  6.60, 0.285, 0.202 },
    { 44.30, 0.380, 0.489 },
    { 43.10, 0.473, 0.438 },
    {  6.10, 0.187, 0.129 },
    { 23.40, 0.305, 0.478 },
    { 12.00, 0.539, 0.313 },
    { 59.10, 0.448, 0.470 },
    { 19.80, 0.364, 0.233 },
    { 19.80, 0.196, 0.252 },
    { 90.00, 0.310, 0.316 },
    { 59.10, 0.310, 0.316 },
    { 36.20, 0.310, 0.316 },
    { 19.80, 0.310, 0.316 },
    {  9.00, 0.310, 0.316 },
    {  3.10, 0.310, 0.316 },
};

// these measurements are under D65 illuminant, and may not match the ISO chart
// https://xritephoto.com/documents/literature/en/ColorData-1p_EN.pdf
#define RGB(r, g, b) {(float)(r)/255.f, (float)(g)/255.f, (float)(b)/255.f}
static NcRGB _Checker_SRGB[24] = {
    RGB(115, 82, 68),
    RGB(194, 150, 130),
    RGB(98, 122, 157),
    RGB(87, 108, 67),
    RGB(133, 128, 177),
    RGB(103, 189, 170),
    RGB(214, 126, 44),
    RGB(80, 91, 166),
    RGB(193, 90, 99),
    RGB(94, 60, 108),
    RGB(157, 188, 64),
    RGB(224, 163, 46),
    RGB(56, 61, 150),
    RGB(70, 148, 73),
    RGB(175, 54, 60),
    RGB(231, 199, 31),
    RGB(187, 86, 149),
    RGB(8, 133, 161),
    RGB(243, 243, 242),
    RGB(200, 200, 200),
    RGB(160, 160, 160),
    RGB(122, 122, 121),
    RGB(85, 85, 85),
    RGB(52, 52, 52)
};
#undef RGB

static const char* _ISO17321_names[24] = {
    "Dark skin",
    "Light skin",
    "Blue sky",
    "Foliage",
    "Blue flower",
    "Bluish green",
    "Orange",
    "Purplish blue",
    "Moderate red",
    "Purple",
    "Yellow green",
    "Orange yellow",
    "Blue",
    "Green",
    "Red",
    "Yellow",
    "Magenta",
    "Cyan",
    "White",
    "Neutral 8",
    "Neutral 6.5",
    "Neutral 5",
    "Neutral 3.5",
    "Black"
};

NcRGB* NcISO17321ColorChipsAP0() { return _ISO17321_ap0; }
const char** NcISO17321ColorChipsNames() { return _ISO17321_names; }
NcRGB* NcCheckerColorChipsSRGB() { return _Checker_SRGB; }
NcYxy* NcMcCamy1976ColorChipsYxy() { return _McCamy1976_Yxy; }

NcXYZ NcProjectToChromaticities(NcXYZ c) {
    float n  = c.x + c.y + c.z;
    return (NcXYZ) { c.x / n, c.y / n, c.z / n };
}

NcYxy NcNormalizeYxy(NcYxy c) {
    return (NcYxy) {
        c.Y,
        c.Y * c.x / c.y,
        c.Y * (1.f - c.x - c.y) / c.y
    };
}

static inline float sign_of(float x) {
    return x > 0 ? 1.f : (x < 0) ? -1.f : 0.f;
}

NcRGB NcRGBFromYxy(const NcColorSpace* cs, NcYxy c) {
    NcYxy cYxy = NcNormalizeYxy(c);
    NcRGB rgb = NcXYZToRGB(cs, (NcXYZ) { cYxy.x, cYxy.Y, cYxy.y });
    NcRGB magRgb = {
        fabsf(rgb.r),
        fabsf(rgb.g),
        fabsf(rgb.b) };

    float maxc = (magRgb.r > magRgb.g) ? magRgb.r : magRgb.g;
    maxc = maxc > magRgb.b ? maxc : magRgb.b;
    NcRGB ret = (NcRGB) {
        sign_of(rgb.r) * rgb.r / maxc,
        sign_of(rgb.g) * rgb.g / maxc,
        sign_of(rgb.b) * rgb.b / maxc };
    return ret;
}
