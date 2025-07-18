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

#ifndef PXR_BASE_GF_NC_NANOCOLOR_UTILS_H
#define PXR_BASE_GF_NC_NANOCOLOR_UTILS_H

#include "nanocolor.h"

#ifdef __cplusplus
extern "C" {
#endif

#define NcISO17321ColorChipsAP0      NCCONCAT(NCNAMESPACE, ISO17321ColorChipsAP0)
#define NcISO17321ColorChipsNames    NCCONCAT(NCNAMESPACE, ISO17321ColorChipsNames)
#define NcCheckerColorChipsSRGB      NCCONCAT(NCNAMESPACE, CheckerColorChipsSRGB)
#define NcMcCamy1976ColorChipsYxy    NCCONCAT(NCNAMESPACE, McCamy1976ColorChipsYxy)
#define NcProjectToChromaticities    NCCONCAT(NCNAMESPACE, ProjectToChromaticities)
#define NcCIE1931ColorFromWavelength NCCONCAT(NCNAMESPACE, CIE1931ColorFromWavelength)

/// \brief Returns the names of the 24 color chips in the ISO 17321 color charts.
/// \return An array of const char pointers containing the names. A nullptr
///         follows the last name.
NCAPI const char** NcISO17321ColorChipsNames(void);

/// \brief Returns a pointer to 24 color values in AP0 corresponding to
///        the 24 color chips in ISO 17321-1:2012 Table D.1.
/// \return An array of NcRGB containing the color values.
NCAPI NcRGB* NcISO17321ColorChipsAP0(void);

/// \brief Returns color values under D65 illuminant for the checker color chips,
///        similar but not matching the ISO table.
/// \return An array of NcRGB containing the color values.
NCAPI NcRGB* NcCheckerColorChipsSRGB(void);

/// \brief Returns color values under Illuminant C for the McCamy 1976 color chips,
///        similar to but not matching the ISO table or the x-rite table.
/// \return An array of NcXYZ containing the color values.
NCAPI NcYxy* NcMcCamy1976ColorChipsYxy(void);

/// \brief Projects a XYZ 1931 color coordinate to the regularized chromaticity coordinate.
/// \param c The XYZ color coordinate.
/// \return The regularized chromaticity coordinate.
NCAPI NcXYZ NcProjectToChromaticities(NcXYZ c);

#ifdef __cplusplus
}
#endif

#endif /* PXR_BASE_GF_NC_NANOCOLOR_UTILS_H */

