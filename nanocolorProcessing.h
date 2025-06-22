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
#ifndef PXR_BASE_GF_NC_NANOCOLOR_PROCESSING_H
#define PXR_BASE_GF_NC_NANOCOLOR_PROCESSING_H

#include "nanocolor.h"
#ifdef __cplusplus
extern "C" {
#endif

// Declare the public interface using the namespacing macro.
#define NcTransformColor             NCCONCAT(NCNAMESPACE, TransformColor)
#define NcTransformColors            NCCONCAT(NCNAMESPACE, TransformColors)
#define NcTransformColorsWithAlpha   NCCONCAT(NCNAMESPACE, TransformColorsWithAlpha)
#define NcXYZToRGB                   NCCONCAT(NCNAMESPACE, XYZToRGB)
#define NcXYZToYxy                   NCCONCAT(NCNAMESPACE, XYZToYxy)
#define NcYxyToRGB                   NCCONCAT(NCNAMESPACE, YxyToRGB)
#define NcYxyToXYZ                   NCCONCAT(NCNAMESPACE, YxyToXYZ)
#define NcRGBToXYZ                   NCCONCAT(NCNAMESPACE, RGBToXYZ)
#define NcKelvinToYxy                NCCONCAT(NCNAMESPACE, KelvinToYxy)

/**
 * Transforms a color from one color space to another.
 *
 * @param dst Pointer to the destination color space object.
 * @param src Pointer to the source color space object.
 * @param rgb The RGB color to transform.
 * @return The transformed RGB color in the destination color space.
 */
NCAPI NcRGB NcTransformColor(const NcColorSpace* dst, const NcColorSpace* src, NcRGB rgb);

/**
 * Transforms an array of colors from one color space to another.
 *
 * @param dst Pointer to the destination color space object.
 * @param src Pointer to the source color space object.
 * @param rgb Pointer to the array of RGB colors to transform.
 * @param count Number of colors in the array.
 * @return void
 */
NCAPI void NcTransformColors(const NcColorSpace* dst, const NcColorSpace* src,
                             NcRGB* rgb, size_t count);

/**
 * Transforms an array of colors with alpha channel from one color space to another.
 *
 * @param dst Pointer to the destination color space object.
 * @param src Pointer to the source color space object.
 * @param rgba Pointer to the array of RGBA colors to transform.
 * @param count Number of colors in the array.
 * @return void
 */
NCAPI void NcTransformColorsWithAlpha(const NcColorSpace* dst, const NcColorSpace* src,
                                      float* rgba, size_t count);

/**
 * Converts an RGB color to XYZ color space using the provided color space.
 *
 * @param cs Pointer to the color space object.
 * @param rgb The RGB color to convert.
 * @return The XYZ color.
 */
NCAPI NcXYZ  NcRGBToXYZ(const NcColorSpace* cs, NcRGB rgb);

/**
 * Converts a XYZ color to RGB color space using the provided color space.
 *
 * @param cs Pointer to the color space object.
 * @param xyz The XYZ color to convert.
 * @return The RGB color.
 */
NCAPI NcRGB NcXYZToRGB(const NcColorSpace* cs, NcXYZ xyz);

/**
 * Converts a XYZ color to Yxy color space.
 *
 * @param xyz The XYZ color to convert.
 * @return The Yxy color.
*/
NCAPI NcYxy NcXYZToYxy(NcXYZ xyz);

/**
 * Converts an Yxy color coordinate to XYZ.
 *
 * @param Yxy The Yxy color coordinate.
 * @return The XYZ color coordinate.
 */
NCAPI NcXYZ NcYxyToXYZ(NcYxy Yxy);

/**
 * Converts an Yxy color coordinate to RGB using the specified color space.
 *
 * @param cs The color space.
 * @param c The Yxy color coordinate.
 * @return The RGB color coordinate.
 */
NCAPI NcRGB NcYxyToRGB(const NcColorSpace* cs, NcYxy c);

/**
 * @brief Returns an Yxy coordinate on the blackbody emission spectrum
 *
 * Returns an Yxy coordinate on the blackbody emission spectrum for values
 * between 1000 and 15000K. Note that temperatures below 1900 are out of gamut
 * for some common colorspaces, such as Rec709.
 *
 *  @param temperature The blackbody temperature in Kelvin.
 *  @param luminosity The luminosity.
 *  @return An Yxy coordinate.
 */
NCAPI NcYxy NcKelvinToYxy(float temperature, float luminosity);

#ifdef __cplusplus
}
#endif
#endif /* PXR_BASE_GF_NC_NANOCOLOR_H */
