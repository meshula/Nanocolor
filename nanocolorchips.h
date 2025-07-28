//
// Color Chip Generator for Nanocolor C
//
// Generates SMPTE 2065-1 / ACES color chips and reference patterns
// in any nanocolor color space.
//
// Copyright 2024 Pixar
// Licensed under the Apache License, Version 2.0
//

#ifndef NANOCOLOR_COLOR_CHIPS_H
#define NANOCOLOR_COLOR_CHIPS_H

#include "nanocolor.h"
#include "nanocolorProcessing.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// MARK: - Color Chip Structures

typedef struct {
    const char* name;
    NcRGB rgb;
    const char* description;
} NcColorChip;

typedef struct {
    const char* name;
    const char* color_space;
    const NcColorChip* chips;
    size_t chip_count;
} NcColorChipSet;

typedef enum {
    NC_OUTPUT_TEXT,
    NC_OUTPUT_CSV,
    NC_OUTPUT_JSON
} NcOutputFormat;

typedef enum {
    NC_CHIPSET_COLORCHECKER,
    NC_CHIPSET_SMPTE_BARS,
    NC_CHIPSET_GRAYSCALE,
    NC_CHIPSET_SPECTRAL,
    NC_CHIPSET_BLACKBODY
} NcChipSetType;

// MARK: - API Functions

/**
 * @brief Get a predefined color chip set by type
 * @param type The chip set type to retrieve
 * @return Pointer to the chip set, or NULL if not found
 */
const NcColorChipSet* NcGetPredefinedChipSet(NcChipSetType type);

/**
 * @brief Transform a color chip set to a different color space
 * @param src_set Source chip set
 * @param target_space Target color space name
 * @param out_chips Output array (caller must allocate)
 * @param max_chips Maximum number of chips in output array
 * @return Number of chips transformed, or -1 on error
 */
int NcTransformChipSet(const NcColorChipSet* src_set, const char* target_space, 
                       NcColorChip* out_chips, size_t max_chips);

/**
 * @brief Generate blackbody color series
 * @param start_temp Starting temperature in Kelvin
 * @param end_temp Ending temperature in Kelvin
 * @param steps Number of steps
 * @param out_chips Output array (caller must allocate)
 * @param max_chips Maximum number of chips in output array
 * @return Number of chips generated, or -1 on error
 */
int NcGenerateBlackbodySeries(float start_temp, float end_temp, int steps,
                              NcColorChip* out_chips, size_t max_chips);

/**
 * @brief Export chip set to string format
 * @param chip_set Chip set to export
 * @param chip_count Number of chips in the set
 * @param color_space Color space name
 * @param format Output format
 * @param buffer Output buffer (caller must allocate)
 * @param buffer_size Size of output buffer
 * @return Number of characters written, or -1 on error
 */
int NcExportChipSet(const NcColorChip* chip_set, size_t chip_count, 
                    const char* color_space, const char* set_name,
                    NcOutputFormat format, char* buffer, size_t buffer_size);

/**
 * @brief Write chip set to file
 * @param chip_set Chip set to write
 * @param chip_count Number of chips in the set
 * @param color_space Color space name
 * @param set_name Name of the chip set
 * @param format Output format
 * @param filename Output filename
 * @return 0 on success, -1 on error
 */
int NcWriteChipSetToFile(const NcColorChip* chip_set, size_t chip_count,
                         const char* color_space, const char* set_name,
                         NcOutputFormat format, const char* filename);

/**
 * @brief Parse chip set type from string
 * @param str String to parse
 * @return Chip set type, or -1 if invalid
 */
int NcParseChipSetType(const char* str);

/**
 * @brief Parse output format from string
 * @param str String to parse
 * @return Output format, or -1 if invalid
 */
int NcParseOutputFormat(const char* str);

/**
 * @brief Print usage information
 */
void NcPrintUsage(const char* program_name);

/**
 * @brief List available color spaces
 */
void NcListColorSpaces(void);

/**
 * @brief List available chip sets
 */
void NcListChipSets(void);

#ifdef __cplusplus
}
#endif

#endif /* NANOCOLOR_COLOR_CHIPS_H */