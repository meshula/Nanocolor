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

#include "Nanocolor.h"
#include <stdbool.h>
#include <string.h>
#include <math.h>

#ifdef __SSE2__
#include <xmmintrin.h>
#include <smmintrin.h>
#endif

#ifdef __ARM_NEON
#include <arm_neon.h>
#endif

extern "C" {

// White point chromaticities.
static const NcXYChromaticity _WpD65 = { 0.3127, 0.3290 };
static const NcXYChromaticity _WpACES = { 0.32168, 0.33767 };

static const NcColorSpace _colorSpaces[] = {
    {
        "acescg",                       // same as lin_ap0
        { 0.713, 0.293 },
        { 0.165, 0.830 },
        { 0.128, 0.044 },
        _WpACES,
        1.0,
        0.0,
        {{ 0, 0, 0, 0 },                // transfer - zero must be computed
         { 0,0,0, 0,0,0, 0,0,0 }}       // transform - zero must be computed
    },
    {
        "adobergb",
        { 0.64, 0.33 },
        { 0.21, 0.71 },
        { 0.15, 0.06 },
        _WpD65,
        563.0/256.0,
        0.0,
        {{ 0, 0, 0, 0 },                // transfer - zero must be computed
         { 0,0,0, 0,0,0, 0,0,0 }}       // transform - zero must be computed
    },
    {
        "g18_ap1",
        { 0.713, 0.293 },
        { 0.165, 0.830 },
        { 0.128, 0.044 },
        _WpACES,
        1.8,
        0.0,
        {{ 0, 0, 0, 0 },                // transfer - zero must be computed
         { 0,0,0, 0,0,0, 0,0,0 }}       // transform - zero must be computed
    },
    {
        "g22_ap1",
        { 0.713, 0.293 },
        { 0.165, 0.830 },
        { 0.128, 0.044 },
        _WpACES,
        2.2,
        0.0,
        {{ 0, 0, 0, 0 },                // transfer - zero must be computed
         { 0,0,0, 0,0,0, 0,0,0 }}       // transform - zero must be computed
    },
    {
        "g18_rec709",
        { 0.640, 0.330 },
        { 0.300, 0.600 },
        { 0.150, 0.060 },
        _WpD65,
        1.8,
        0.0,
        {{ 0, 0, 0, 0 },                // transfer - zero must be computed
         { 0,0,0, 0,0,0, 0,0,0 }}       // transform - zero must be computed
    },
    {
        "g22_rec709",
        { 0.640, 0.330 },
        { 0.300, 0.600 },
        { 0.150, 0.060 },
        _WpD65,
        2.2,
        0.0,
        {{ 0, 0, 0, 0 },                // transfer - zero must be computed
         { 0,0,0, 0,0,0, 0,0,0 }}       // transform - zero must be computed
    },
    {
        "lin_adobergb",
        { 0.64, 0.33 },
        { 0.21, 0.71 },
        { 0.15, 0.06 },
        _WpD65,
        1.0,
        0.0,
        {{ 0, 0, 0, 0 },                // transfer - zero must be computed
         { 0,0,0, 0,0,0, 0,0,0 }}       // transform - zero must be computed
    },
    {
        "lin_ap0",
        { 0.7347, 0.2653  },
        { 0.0000, 1.0000  },
        { 0.0001, -0.0770 },
        _WpACES,
        1.0,
        0.0,
        {{ 0, 0, 0, 0 },                // transfer - zero must be computed
         { 0,0,0, 0,0,0, 0,0,0 }}       // transform - zero must be computed
    },
    {
        "lin_ap1",                      // same as acescg
        { 0.713, 0.293 },
        { 0.165, 0.830 },
        { 0.128, 0.044 },
        _WpACES,
        1.0,
        0.0,
        {{ 0, 0, 0, 0 },                // transfer - zero must be computed
         { 0,0,0, 0,0,0, 0,0,0 }}       // transform - zero must be computed
    },
    {
        "lin_displayp3",
        { 0.6800, 0.3200 },
        { 0.2650, 0.6900 },
        { 0.1500, 0.0600 },
        _WpD65,
        1.0,
        0.0,
        {{ 0, 0, 0, 0 },                // transfer - zero must be computed
         { 0,0,0, 0,0,0, 0,0,0 }}       // transform - zero must be computed
    },
    {
        "lin_rec709",
        { 0.640, 0.330 },
        { 0.300, 0.600 },
        { 0.150, 0.060 },
        _WpD65,
        1.0,
        0.0,
        {{ 0, 0, 0, 0 },                // transfer - zero must be computed
         { 0,0,0, 0,0,0, 0,0,0 }}       // transform - zero must be computed
    },
    {
        "lin_rec2020",
        { 0.708, 0.292 },
        { 0.170, 0.797 },
        { 0.131, 0.046 },
        _WpD65,
        1.0,
        0.0,
        {{ 0, 0, 0, 0 },                // transfer - zero must be computed
         { 0,0,0, 0,0,0, 0,0,0 }}       // transform - zero must be computed
    },
    {
        "lin_srgb",             // the same as lin_rec709
        { 0.640, 0.330 },
        { 0.300, 0.600 },
        { 0.150, 0.060 },
        _WpD65,
        1.0,
        0.0,
        {{ 0, 0, 0, 0 },                // transfer - zero must be computed
         { 0,0,0, 0,0,0, 0,0,0 }}       // transform - zero must be computed
    },
    {
        "srgb_displayp3",
        { 0.6800, 0.3200 },
        { 0.2650, 0.6900 },
        { 0.1500, 0.0600 },
        _WpD65,
        2.2,
        0.055,
        {{ 0, 0, 0, 0 },                // transfer - zero must be computed
         { 0,0,0, 0,0,0, 0,0,0 }}       // transform - zero must be computed
    },
    {
        "srgb_texture",
        { 0.640, 0.330 },
        { 0.300, 0.600 },
        { 0.150, 0.060 },
        _WpD65,
        2.2,
        0.055,
        {{ 0, 0, 0, 0 },                // transfer - zero must be computed
         { 0,0,0, 0,0,0, 0,0,0 }}       // transform - zero must be computed
    },
    {
        "identity",
        { 1.0, 0.0 },                   // these chromaticities generate identity
        { 0.0, 1.0 },
        { 0.0, 0.0 },
        { 1.0/3.0, 1.0/3.0 },
        1.0,
        0.0,
        {{ 0, 0, 0, 0 },                // transfer - zero must be computed
         { 0,0,0, 0,0,0, 0,0,0 }}       // transform - zero must be computed
    }
};

const char** NcRegisteredColorSpaceNames()
{
    const int colorspaces = sizeof(_colorSpaces) / sizeof(NcColorSpace);
    static const char* colorspaceNames[colorspaces + 1];
    static int registeredColorSpaces = 0;
    if (!registeredColorSpaces) {
        for (int i = 0; i < colorspaces; ++i)
            colorspaceNames[i] = _colorSpaces[i].name;
        colorspaceNames[colorspaces] = nullptr;
        registeredColorSpaces = colorspaces;
    }
    return colorspaceNames;
}


static NcM33f NcM3ffInvert(NcM33f m) {
    NcM33f inv;
    const int M0 = 0, M1 = 3, M2 = 6, M3 = 1, M4 = 4, M5 = 7, M6 = 2, M7 = 5, M8 = 8;
    float det = m.m[M0] * (m.m[M4] * m.m[M8] - m.m[M5] * m.m[M7]) -
    m.m[M1] * (m.m[M3] * m.m[M8] - m.m[M5] * m.m[M6]) +
    m.m[M2] * (m.m[M3] * m.m[M7] - m.m[M4] * m.m[M6]);
    float invdet = 1.0 / det;
    inv.m[M0] = (m.m[M4] * m.m[M8] - m.m[M5] * m.m[M7]) * invdet;
    inv.m[M1] = (m.m[M2] * m.m[M7] - m.m[M1] * m.m[M8]) * invdet;
    inv.m[M2] = (m.m[M1] * m.m[M5] - m.m[M2] * m.m[M4]) * invdet;
    inv.m[M3] = (m.m[M5] * m.m[M6] - m.m[M3] * m.m[M8]) * invdet;
    inv.m[M4] = (m.m[M0] * m.m[M8] - m.m[M2] * m.m[M6]) * invdet;
    inv.m[M5] = (m.m[M2] * m.m[M3] - m.m[M0] * m.m[M5]) * invdet;
    inv.m[M6] = (m.m[M3] * m.m[M7] - m.m[M4] * m.m[M6]) * invdet;
    inv.m[M7] = (m.m[M1] * m.m[M6] - m.m[M0] * m.m[M7]) * invdet;
    inv.m[M8] = (m.m[M0] * m.m[M4] - m.m[M1] * m.m[M3]) * invdet;
    return inv;
}

static NcM33f NcM33fMultiply(NcM33f lh, NcM33f rh) {
    NcM33f m;
    m.m[0] = lh.m[0] * rh.m[0] + lh.m[1] * rh.m[3] + lh.m[2] * rh.m[6];
    m.m[1] = lh.m[0] * rh.m[1] + lh.m[1] * rh.m[4] + lh.m[2] * rh.m[7];
    m.m[2] = lh.m[0] * rh.m[2] + lh.m[1] * rh.m[5] + lh.m[2] * rh.m[8];
    m.m[3] = lh.m[3] * rh.m[0] + lh.m[4] * rh.m[3] + lh.m[5] * rh.m[6];
    m.m[4] = lh.m[3] * rh.m[1] + lh.m[4] * rh.m[4] + lh.m[5] * rh.m[7];
    m.m[5] = lh.m[3] * rh.m[2] + lh.m[4] * rh.m[5] + lh.m[5] * rh.m[8];
    m.m[6] = lh.m[6] * rh.m[0] + lh.m[7] * rh.m[3] + lh.m[8] * rh.m[6];
    m.m[7] = lh.m[6] * rh.m[1] + lh.m[7] * rh.m[4] + lh.m[8] * rh.m[7];
    m.m[8] = lh.m[6] * rh.m[2] + lh.m[7] * rh.m[5] + lh.m[8] * rh.m[8];
    return m;
}

#if 0
/// @TODO move to test suite
void checkInvertAndMultiply() {
    // this gives the correct result per Annex C
    NcM33f s = { 0.56711181859, 0.2793268677, 0, 0.1903210663, 0.6434664624, 0.0725032634, 0.1930166748, 0.0772066699, 1.0165544874 };
    NcM33f d = { 0.4123907993, 0.2126390059, 0.0193308187, 0.3575843394, 0.7151686788, 0.1191947798, 0.1804807884, 0.0721923154, 0.9505321522 };
    NcM33f di = NcM3ffInvert(d);
    NcM33f sd = NcM33fMultiply(s, di);
}
#endif

void NcInitColorSpace(NcColorSpace* cs) {
    if (!cs || cs->colorTransform.transform.m[8] != 0.0)
        return;
    
    const float a = cs->linearBias;
    const float gamma = cs->gamma;
    
    cs->colorTransform.transfer.linearBias = a;
    cs->colorTransform.transfer.K0 = 0.f;
    cs->colorTransform.transfer.gamma = cs->gamma;
    
    if (gamma == 1.f) {
        cs->colorTransform.transfer.K0 = 1.e9f;
        cs->colorTransform.transfer.phi = 1.f;
    }
    else {
        if (a <= 0.f) {
            cs->colorTransform.transfer.K0 = 0.f;
            cs->colorTransform.transfer.phi = 1.f;
        }
        else {
            cs->colorTransform.transfer.K0 = a / (gamma - 1.f);
            cs->colorTransform.transfer.phi = (a /
                                               expf(logf(gamma * a /
                                                         (gamma + gamma * a - 1.f - a)) * gamma)) /
            (gamma - 1.f);
        }
    }
    
    NcM33f m;
    // To be consistent, we use SMPTE RP 177-1993
    // compute xyz [little xyz]
    float red[3]   = { cs->redPrimary.x,   cs->redPrimary.y,   1.f - cs->redPrimary.x   - cs->redPrimary.y };
    float green[3] = { cs->greenPrimary.x, cs->greenPrimary.y, 1.f - cs->greenPrimary.x - cs->greenPrimary.y };
    float blue[3]  = { cs->bluePrimary.x,  cs->bluePrimary.y,  1.f - cs->bluePrimary.x  - cs->bluePrimary.y };
    float white[3] = { cs->whitePoint.x,   cs->whitePoint.y,   1.f - cs->whitePoint.x   - cs->whitePoint.y };
    
    // Build the P matrix by column binding red, green, and blue:
    m.m[0] = red[0];
    m.m[1] = green[0];
    m.m[2] = blue[0];
    m.m[3] = red[1];
    m.m[4] = green[1];
    m.m[5] = blue[1];
    m.m[6] = red[2];
    m.m[7] = green[2];
    m.m[8] = blue[2];
    
    // and W
    // white has luminance factor of 1.0, ie Y = 1
    float W[3] = { white[0] / white[1], white[1] / white[1], white[2] / white[1] };
    
    // compute the coefficients to scale primaries
    NcM33f mInv = NcM3ffInvert(m);
    float C[3] = {
        mInv.m[0] * W[0] + mInv.m[1] * W[1] + mInv.m[2] * W[2],
        mInv.m[3] * W[0] + mInv.m[4] * W[1] + mInv.m[5] * W[2],
        mInv.m[6] * W[0] + mInv.m[7] * W[1] + mInv.m[8] * W[2]
    };
    
    // multiply the P matrix by the diagonal matrix of coefficients
    m.m[0] *= C[0];
    m.m[1] *= C[1];
    m.m[2] *= C[2];
    m.m[3] *= C[0];
    m.m[4] *= C[1];
    m.m[5] *= C[2];
    m.m[6] *= C[0];
    m.m[7] *= C[1];
    m.m[8] *= C[2];
    
    // overwrite the transform. It's fine if two threads do it simultaneously
    // because they will both write the same value.
    cs->colorTransform.transform = m;
}

NcM33f NcGetRGBToCIEXYZMatrix(NcColorSpace* cs) {
    if (!cs)
        return {1,0,0, 0,1,0, 0,0,1};
    
    NcInitColorSpace(cs);
    return cs->colorTransform.transform;
}

NcM33f NcGetCIEXYZToRGBMatrix(NcColorSpace* cs) {
    if (!cs)
        return {1,0,0, 0,1,0, 0,0,1};
    
    return NcM3ffInvert(NcGetRGBToCIEXYZMatrix(cs));
}

NcColorTransform GetRGBtoRGBTransform(NcColorSpace* src, NcColorSpace* dst) {
    NcColorTransform t;
    t.transform = NcM33fMultiply(NcM3ffInvert(NcGetRGBToCIEXYZMatrix(src)),
                                 NcGetCIEXYZToRGBMatrix(dst));
    return t;
}

// convert from gamma to linear by raising to gamma
inline float nc_ToLinear(NcColorSpace* cs, float t) {
    const float gamma = cs->colorTransform.transfer.gamma;
    //return powf(t, gamma);
    if (t < cs->colorTransform.transfer.K0)
        return t / cs->colorTransform.transfer.phi;
    const float a = cs->colorTransform.transfer.linearBias;
    return powf((t + a) / (1.f + a), gamma);
}

// convert linear to gamma by raising to 1/gamma
inline float nc_FromLinear(NcColorSpace* cs, float t) {
    const float gamma = cs->colorTransform.transfer.gamma;
    //return powf(t, 1.f/gamma);
    if (t < cs->colorTransform.transfer.K0 / cs->colorTransform.transfer.phi)
        return t * cs->colorTransform.transfer.phi;
    const float a = cs->colorTransform.transfer.linearBias;
    return (1.f + a) * powf(t, 1.f / gamma) - a;
}

NcM33f NcGetRGBToRGBTransform(NcColorSpace* src, NcColorSpace* dst) {
    if (!dst || !src) {
        return {};
    }
    NcInitColorSpace(dst);
    NcInitColorSpace(src);
    
    NcM33f toXYZ = NcGetRGBToCIEXYZMatrix(src);
    NcM33f fromXYZ = NcGetCIEXYZToRGBMatrix(dst);
    
    NcM33f tx = NcM33fMultiply(fromXYZ, toXYZ);
    return tx;
}

NcRGB NcTransformColor(NcColorSpace* dst, NcColorSpace* src, NcRGB rgb) {
    if (!dst || !src) {
        return rgb;
    }
    
    NcInitColorSpace(dst);
    NcInitColorSpace(src);
    
    NcM33f tx = NcM33fMultiply(NcGetRGBToCIEXYZMatrix(src),
                               NcGetCIEXYZToRGBMatrix(dst));
    
    rgb.r = nc_ToLinear(src, rgb.r);
    rgb.g = nc_ToLinear(src, rgb.g);
    rgb.b = nc_ToLinear(src, rgb.b);
    
    NcRGB out;
    out.r = tx.m[0] * rgb.r + tx.m[1] * rgb.g + tx.m[2] * rgb.b;
    out.g = tx.m[3] * rgb.r + tx.m[4] * rgb.g + tx.m[5] * rgb.b;
    out.b = tx.m[6] * rgb.r + tx.m[7] * rgb.g + tx.m[8] * rgb.b;
    
    out.r = nc_FromLinear(dst, out.r);
    out.g = nc_FromLinear(dst, out.g);
    out.b = nc_FromLinear(dst, out.b);
    return out;
}

void NcTransformColors(NcColorSpace* dst, NcColorSpace* src, NcRGB* rgb, int count)
{
    if (!dst || !src || !rgb)
        return;
    
    NcInitColorSpace(dst);
    NcInitColorSpace(src);
    
    NcM33f tx = NcM33fMultiply(NcGetRGBToCIEXYZMatrix(src),
                               NcGetCIEXYZToRGBMatrix(dst));
    
    for (int i = 0; i < count; i++) {
        NcRGB out = rgb[i];
        out.r = nc_ToLinear(src, out.r);
        out.g = nc_ToLinear(src, out.g);
        out.b = nc_ToLinear(src, out.b);
        rgb[i] = out;
    }
    
    int start = 0;
#if HAVE_SSE2
    __m128 m0 = _mm_set_ps(tx.m[0], tx.m[1], tx.m[2], 0);
    __m128 m1 = _mm_set_ps(tx.m[3], tx.m[4], tx.m[5], 0);
    __m128 m2 = _mm_set_ps(tx.m[6], tx.m[7], tx.m[8], 0);
    __m128 m3 = _mm_set_ps(0, 0, 0, 1);
    
    for (int i = 0; i < count - 1; i++) {
        __m128 rgba = _mm_loadu_ps(&rgb[i].r);   // load rgbr
        
        // Set alpha component to 1.0 before multiplication
        rgba = _mm_add_ps(rgba, m3);
        
        // Perform the matrix multiplication
        __m128 rout = _mm_mul_ps(m0, rgba);
        rout = _mm_add_ps(rout, _mm_mul_ps(m1, rgba));
        rout = _mm_add_ps(rout, _mm_mul_ps(m2, rgba));
        rout = _mm_add_ps(rout, _mm_mul_ps(m3, rgba));
        
        // Store the result
        _mm_storeu_ps(&rgb[i].r, rout);
    }
    
    // transform the last value separately, because _mm_storeu_ps
    // writes 4 floats, and we may not have 4 floats left
    start = count - 2;
    count = 1;
#elif HAVE_NEON
    float32x4_t m0 = { tx.m[0], tx.m[1], tx.m[2], 0 };
    float32x4_t m1 = { tx.m[3], tx.m[4], tx.m[5], 0 };
    float32x4_t m2 = { tx.m[6], tx.m[7], tx.m[8], 0 };
    float32x4_t m3 = { 0, 0, 0, 1 };
    
    for (int i = 0; i < count - 1; i++) {
        float32x4_t rgba = vld1q_f32(&rgb[i].r);   // load rgbr
        
        // Set alpha component to 1.0 before multiplication
        rgba = vsetq_lane_f32(1.0f, rgba, 3);
        
        // Perform the matrix multiplication
        float32x4_t rout = vmulq_f32(m0, rgba);
        rout = vmlaq_f32(rout, m1, rgba);
        rout = vmlaq_f32(rout, m2, rgba);
        rout = vmlaq_f32(rout, m3, rgba);
        
        // Store the result
        vst1q_f32(&rgb[i].r, rout);
    }
    // transform the last value separately, because _mm_storeu_ps
    // writes 4 floats, and we may not have 4 floats left
    start = count - 2;
    count = 1;
#endif
    
    for (int i = start; i < count; i++) {
        NcRGB out = rgb[i];
        out.r = tx.m[0] * out.r + tx.m[1] * out.g + tx.m[2] * out.b;
        out.r = tx.m[3] * out.r + tx.m[4] * out.g + tx.m[5] * out.b;
        out.r = tx.m[6] * out.r + tx.m[7] * out.g + tx.m[8] * out.b;
        rgb[i] = out;
    }
    
    for (int i = 0; i < count; i++) {
        NcRGB out = rgb[i];
        out.r = nc_FromLinear(dst, out.r);
        out.g = nc_FromLinear(dst, out.g);
        out.b = nc_FromLinear(dst, out.b);
        rgb[i] = out;
    }
}

// same as NcTransformColor, but preserve alpha in the transformation
void NcTransformColorsWithAlpha(NcColorSpace* dst, NcColorSpace* src, float* rgba, int count)
{
    if (!dst || !src || !rgba)
        return;
    
    NcInitColorSpace(dst);
    NcInitColorSpace(src);
    
    NcM33f tx = NcM33fMultiply(NcGetRGBToCIEXYZMatrix(src),
                               NcGetCIEXYZToRGBMatrix(dst));
    
    for (int i = 0; i < count; i++) {
        NcRGB out = { rgba[i * 4 + 0], rgba[i * 4 + 1], rgba[i * 4 + 2] };
        out.r = nc_ToLinear(src, out.r);
        out.g = nc_ToLinear(src, out.g);
        out.b = nc_ToLinear(src, out.b);
        rgba[i * 4 + 0] = out.r;
        rgba[i * 4 + 1] = out.g;
        rgba[i * 4 + 2] = out.b;
    }
    
#if HAVE_SSE2
    __m128 m0 = _mm_set_ps(tx.m[0], tx.m[1], tx.m[2], 0);
    __m128 m1 = _mm_set_ps(tx.m[3], tx.m[4], tx.m[5], 0);
    __m128 m2 = _mm_set_ps(tx.m[6], tx.m[7], tx.m[8], 0);
    __m128 m3 = _mm_set_ps(0,0,0,1);
    
    for (int i = 0; i < count; i += 4) {
        __m128 rgbaVec = _mm_loadu_ps(&rgba[i * 4]);  // Load all components (r, g, b, a)
        
        __m128  rout = _mm_mul_ps(m0, rgbaVec);
        rout = _mm_add_ps(rout, _mm_mul_ps(m1, rgbaVec));
        rout = _mm_add_ps(rout, _mm_mul_ps(m2, rgbaVec));
        rout = _mm_add_ps(rout, _mm_mul_ps(m3, rgbaVec));
        
        _mm_storeu_ps(&rgba[i * 4], rout);  // Store the result
    }
#elif HAVE_NEON
    float32x4x4_t matrix = {
        {tx.m[0], tx.m[1], tx.m[2], 0},
        {tx.m[3], tx.m[4], tx.m[5], 0},
        {tx.m[6], tx.m[7], tx.m[8], 0},
        {0, 0, 0, 1}
    };
    
    for (int i = 0; i < count; i += 4) {
        float32x4x4_t rgba_values = vld4q_f32(&rgba[i * 4]);
        
        float32x4_t rout = vmulq_f32(matrix.val[0], rgba_values.val[0]);
        rout = vmlaq_f32(rout, matrix.val[1], rgba_values.val[1]);
        rout = vmlaq_f32(rout, matrix.val[2], rgba_values.val[2]);
        rout = vmlaq_f32(rout, matrix.val[3], rgba_values.val[3]);
        
        vst1q_f32(&rgba[i * 4], rout);
    }
#else
    for (int i = 0; i < count; i++) {
        NcRGB out = { rgba[i * 4 + 0], rgba[i * 4 + 1], rgba[i * 4 + 2] };
        out.r = tx.m[0] * out.r + tx.m[1] * out.g + tx.m[2] * out.b;
        out.r = tx.m[3] * out.r + tx.m[4] * out.g + tx.m[5] * out.b;
        out.r = tx.m[6] * out.r + tx.m[7] * out.g + tx.m[8] * out.b;
        rgba[i * 4 + 0] = out.r;
        rgba[i * 4 + 1] = out.g;
        rgba[i * 4 + 2] = out.b;
        // leave alpha alone
    }
#endif
    for (int i = 0; i < count; i++) {
        NcRGB out = { rgba[i * 4 + 0], rgba[i * 4 + 1], rgba[i * 4 + 2] };
        out.r = nc_FromLinear(dst, out.r);
        out.g = nc_FromLinear(dst, out.g);
        out.b = nc_FromLinear(dst, out.b);
        rgba[i * 4 + 0] = out.r;
        rgba[i * 4 + 1] = out.g;
        rgba[i * 4 + 2] = out.b;
    }
}

NcCIEXYZ NcRGBToXYZ(NcColorSpace* ct, NcRGB rgb) {
    if (!ct)
        return (NcCIEXYZ
                ) {0,0,0};
    
    rgb.r = nc_ToLinear(ct, rgb.r);
    rgb.g = nc_ToLinear(ct, rgb.g);
    rgb.b = nc_ToLinear(ct, rgb.b);
    
    NcM33f m = NcGetRGBToCIEXYZMatrix(ct);
    return (NcCIEXYZ
            ) {
        m.m[0] * rgb.r + m.m[1] * rgb.g + m.m[2] * rgb.b,
        m.m[3] * rgb.r + m.m[4] * rgb.g + m.m[5] * rgb.b,
        m.m[6] * rgb.r + m.m[7] * rgb.g + m.m[8] * rgb.b
    };
}

NcRGB NcXYZToRGB(NcColorSpace* ct, NcCIEXYZ xyz) {
    if (!ct)
        return (NcRGB) {0,0,0};
    
    NcM33f m = NcGetCIEXYZToRGBMatrix(ct);
    
    NcRGB rgb = {
        m.m[0] * xyz.x + m.m[1] * xyz.y + m.m[2] * xyz.z,
        m.m[3] * xyz.x + m.m[4] * xyz.y + m.m[5] * xyz.z,
        m.m[6] * xyz.x + m.m[7] * xyz.y + m.m[8] * xyz.z
    };
    
    rgb.r = nc_FromLinear(ct, rgb.r);
    rgb.g = nc_FromLinear(ct, rgb.g);
    rgb.b = nc_FromLinear(ct, rgb.b);
    return rgb;
}

NcColorSpace NcGetNamedColorSpace(const char* name_)
{
    if (name_) {
        const char* name = name_;
        if (!strcmp(name, "raw")) {
            // USD files may name "raw" to mean identity
            name = "identity";
        }
        else if (!strcmp(name, "auto")) {
            // what acutally is the intent of "auto"?
            name = "identity";
        }
        else if (!strcmp(name, "sRGB")) {
            // USD files may name "sRGB" to mean srgb_texture
            name = "srgb_texture";
        }
        for (int i = 0; i < sizeof(_colorSpaces) / sizeof(_colorSpaces[0]); i++) {
            if (strcmp(name, _colorSpaces[i].name) == 0) {
                return _colorSpaces[i];
            }
        }
    }
    
    NcColorSpace ret = NcColorSpace();
    memset(&ret, 0, sizeof(ret));
    return ret;
}

// Note: This routine is exposed via NanocolorUtils, but the tables aren't
// exported so the implementation is here.

static bool CompareCIEXYZ(const NcCIEXYZ& a, const NcCIEXYZ& b, float threshold) {
    return fabsf(a.x - b.x) < threshold &&
    fabsf(a.y - b.y) < threshold &&
    fabsf(a.z - b.z) < threshold;
}

static bool CompareCIEXYChromaticity(const NcXYChromaticity& a, const NcXYChromaticity& b, float threshold) {
    return fabsf(a.x - b.x) < threshold &&
    fabsf(a.y - b.y) < threshold;
}

// The main reason this exists is that OpenEXR encodes colorspaces via primaries
// and white point, and it would be good to be able to match an EXR file to a
// known colorspace, rather than setting up unique transforms for each image.
// Therefore constructing the namespaced name here via macro, to avoid including
// utils itself.

const char*
NCCONCAT(NCNAMESPACE, MatchLinearColorSpace)
(NcCIEXYZ redPrimary, NcCIEXYZ greenPrimary, NcCIEXYZ bluePrimary,
 NcXYChromaticity  whitePoint, float threshold) {
    for (int i = 0; i < sizeof(_colorSpaces) / sizeof(NcColorSpace); ++i) {
        if (CompareCIEXYZ(_colorSpaces[i].redPrimary, redPrimary, threshold) &&
            CompareCIEXYZ(_colorSpaces[i].greenPrimary, greenPrimary, threshold) &&
            CompareCIEXYZ(_colorSpaces[i].bluePrimary, bluePrimary, threshold) &&
            CompareCIEXYChromaticity(_colorSpaces[i].whitePoint, whitePoint, threshold))
            return _colorSpaces[i].name;
    }
    return NULL;
}

} // extern "C"
