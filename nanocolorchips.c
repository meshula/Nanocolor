//
// Color Chip Generator for Nanocolor C - Implementation
//

// LICENSE: MIT License
// Copyright (c) 2025 Nick Porcino
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.


#include "color_chips.h"
#include <math.h>

// MARK: - Predefined Color Chip Data

// ACEScg ColorChecker reference values
static const NcColorChip acescg_colorchecker_chips[] = {
    // Row 1 (top)
    {"dark_skin", {0.4325f, 0.3127f, 0.2411f}, "ColorChecker patch 1"},
    {"light_skin", {0.7787f, 0.5925f, 0.4733f}, "ColorChecker patch 2"},
    {"blue_sky", {0.3570f, 0.4035f, 0.5733f}, "ColorChecker patch 3"},
    {"foliage", {0.3369f, 0.4219f, 0.2797f}, "ColorChecker patch 4"},
    {"blue_flower", {0.5479f, 0.5434f, 0.8156f}, "ColorChecker patch 5"},
    {"bluish_green", {0.4708f, 0.7749f, 0.6411f}, "ColorChecker patch 6"},
    
    // Row 2
    {"orange", {0.9309f, 0.4471f, 0.1330f}, "ColorChecker patch 7"},
    {"purplish_blue", {0.2906f, 0.3299f, 0.6549f}, "ColorChecker patch 8"},
    {"moderate_red", {0.7285f, 0.3447f, 0.4019f}, "ColorChecker patch 9"},
    {"purple", {0.3174f, 0.2210f, 0.3394f}, "ColorChecker patch 10"},
    {"yellow_green", {0.6157f, 0.8067f, 0.2482f}, "ColorChecker patch 11"},
    {"orange_yellow", {0.9847f, 0.7369f, 0.1090f}, "ColorChecker patch 12"},
    
    // Row 3
    {"blue", {0.2131f, 0.2373f, 0.6580f}, "ColorChecker patch 13"},
    {"green", {0.2744f, 0.5175f, 0.2297f}, "ColorChecker patch 14"},
    {"red", {0.6910f, 0.1926f, 0.1395f}, "ColorChecker patch 15"},
    {"yellow", {0.9892f, 0.9011f, 0.1060f}, "ColorChecker patch 16"},
    {"magenta", {0.7380f, 0.3039f, 0.6192f}, "ColorChecker patch 17"},
    {"cyan", {0.1864f, 0.6377f, 0.7554f}, "ColorChecker patch 18"},
    
    // Row 4 (grayscale)
    {"white", {0.9131f, 0.9131f, 0.9131f}, "ColorChecker patch 19 - White"},
    {"neutral_8", {0.5894f, 0.5894f, 0.5894f}, "ColorChecker patch 20 - 80% gray"},
    {"neutral_65", {0.3668f, 0.3668f, 0.3668f}, "ColorChecker patch 21 - 65% gray"},
    {"neutral_5", {0.1903f, 0.1903f, 0.1903f}, "ColorChecker patch 22 - 50% gray (18%)"},
    {"neutral_35", {0.0898f, 0.0898f, 0.0898f}, "ColorChecker patch 23 - 35% gray"},
    {"black", {0.0313f, 0.0313f, 0.0313f}, "ColorChecker patch 24 - Black"},
};

// SMPTE Color Bars
static const NcColorChip smpte_color_bars[] = {
    {"white", {1.0f, 1.0f, 1.0f}, "100% white"},
    {"yellow", {1.0f, 1.0f, 0.0f}, "100% yellow"},
    {"cyan", {0.0f, 1.0f, 1.0f}, "100% cyan"},
    {"green", {0.0f, 1.0f, 0.0f}, "100% green"},
    {"magenta", {1.0f, 0.0f, 1.0f}, "100% magenta"},
    {"red", {1.0f, 0.0f, 0.0f}, "100% red"},
    {"blue", {0.0f, 0.0f, 1.0f}, "100% blue"},
    {"black", {0.0f, 0.0f, 0.0f}, "0% black"},
};

// Grayscale patches
static const NcColorChip grayscale_patches[] = {
    {"white_100", {1.0f, 1.0f, 1.0f}, "100% white"},
    {"gray_90", {0.9f, 0.9f, 0.9f}, "90% gray"},
    {"gray_80", {0.8f, 0.8f, 0.8f}, "80% gray"},
    {"gray_70", {0.7f, 0.7f, 0.7f}, "70% gray"},
    {"gray_60", {0.6f, 0.6f, 0.6f}, "60% gray"},
    {"gray_50", {0.5f, 0.5f, 0.5f}, "50% gray"},
    {"gray_40", {0.4f, 0.4f, 0.4f}, "40% gray"},
    {"gray_30", {0.3f, 0.3f, 0.3f}, "30% gray"},
    {"gray_20", {0.2f, 0.2f, 0.2f}, "20% gray"},
    {"gray_18", {0.18f, 0.18f, 0.18f}, "18% gray (photographic mid-gray)"},
    {"gray_10", {0.1f, 0.1f, 0.1f}, "10% gray"},
    {"black_0", {0.0f, 0.0f, 0.0f}, "0% black"},
};

// Spectral primaries
static const NcColorChip spectral_primaries[] = {
    {"red_700nm", {1.0f, 0.0f, 0.0f}, "Approximate 700nm red"},
    {"orange_600nm", {1.0f, 0.5f, 0.0f}, "Approximate 600nm orange"},
    {"yellow_580nm", {1.0f, 1.0f, 0.0f}, "Approximate 580nm yellow"},
    {"green_530nm", {0.0f, 1.0f, 0.0f}, "Approximate 530nm green"},
    {"cyan_485nm", {0.0f, 1.0f, 1.0f}, "Approximate 485nm cyan"},
    {"blue_450nm", {0.0f, 0.0f, 1.0f}, "Approximate 450nm blue"},
    {"violet_400nm", {0.5f, 0.0f, 1.0f}, "Approximate 400nm violet"},
};

// Predefined chip sets
static const NcColorChipSet predefined_chip_sets[] = {
    {"ColorChecker Classic", "acescg", acescg_colorchecker_chips, 
     sizeof(acescg_colorchecker_chips) / sizeof(acescg_colorchecker_chips[0])},
    {"SMPTE Color Bars", "lin_srgb", smpte_color_bars, 
     sizeof(smpte_color_bars) / sizeof(smpte_color_bars[0])},
    {"Grayscale Patches", "lin_srgb", grayscale_patches, 
     sizeof(grayscale_patches) / sizeof(grayscale_patches[0])},
    {"Spectral Primaries", "lin_srgb", spectral_primaries, 
     sizeof(spectral_primaries) / sizeof(spectral_primaries[0])},
};

static const size_t NUM_PREDEFINED_SETS = sizeof(predefined_chip_sets) / sizeof(predefined_chip_sets[0]);

// MARK: - API Implementation

const NcColorChipSet* NcGetPredefinedChipSet(NcChipSetType type) {
    if (type < 0 || type >= NUM_PREDEFINED_SETS) {
        return NULL;
    }
    return &predefined_chip_sets[type];
}

int NcTransformChipSet(const NcColorChipSet* src_set, const char* target_space, 
                       NcColorChip* out_chips, size_t max_chips) {
    if (!src_set || !target_space || !out_chips) {
        return -1;
    }
    
    const NcColorSpace* src_cs = NcGetNamedColorSpace(src_set->color_space);
    const NcColorSpace* dst_cs = NcGetNamedColorSpace(target_space);
    
    if (!src_cs || !dst_cs) {
        return -1;
    }
    
    size_t count = src_set->chip_count;
    if (count > max_chips) {
        count = max_chips;
    }
    
    for (size_t i = 0; i < count; i++) {
        out_chips[i].name = src_set->chips[i].name;
        out_chips[i].description = src_set->chips[i].description;
        out_chips[i].rgb = NcTransformColor(dst_cs, src_cs, src_set->chips[i].rgb);
    }
    
    return (int)count;
}

int NcGenerateBlackbodySeries(float start_temp, float end_temp, int steps,
                              NcColorChip* out_chips, size_t max_chips) {
    if (!out_chips || steps <= 0 || steps > (int)max_chips) {
        return -1;
    }
    
    const NcColorSpace* lin_srgb = NcGetNamedColorSpace("lin_srgb");
    if (!lin_srgb) {
        return -1;
    }
    
    for (int i = 0; i < steps; i++) {
        float temp = start_temp + (end_temp - start_temp) * (float)i / (float)(steps - 1);
        NcYxy yxy = NcKelvinToYxy(temp, 1.0f);
        NcXYZ xyz = NcYxyToXYZ(yxy);
        NcRGB rgb = NcXYZToRGB(lin_srgb, xyz);
        
        // Static storage for names (in real implementation, you'd want dynamic allocation)
        static char names[32][64];
        static char descriptions[32][128];
        
        snprintf(names[i], sizeof(names[i]), "blackbody_%dK", (int)temp);
        snprintf(descriptions[i], sizeof(descriptions[i]), "Blackbody at %dK", (int)temp);
        
        out_chips[i].name = names[i];
        out_chips[i].rgb = rgb;
        out_chips[i].description = descriptions[i];
    }
    
    return steps;
}

int NcExportChipSet(const NcColorChip* chip_set, size_t chip_count, 
                    const char* color_space, const char* set_name,
                    NcOutputFormat format, char* buffer, size_t buffer_size) {
    if (!chip_set || !color_space || !set_name || !buffer || buffer_size == 0) {
        return -1;
    }
    
    int written = 0;
    
    switch (format) {
        case NC_OUTPUT_TEXT: {
            written += snprintf(buffer + written, buffer_size - written, 
                               "# %s in %s\n", set_name, color_space);
            written += snprintf(buffer + written, buffer_size - written, 
                               "============================================================\n");
            
            for (size_t i = 0; i < chip_count && written < (int)buffer_size - 1; i++) {
                written += snprintf(buffer + written, buffer_size - written,
                                   "%s: RGB(%.6f, %.6f, %.6f)\n",
                                   chip_set[i].name,
                                   chip_set[i].rgb.r,
                                   chip_set[i].rgb.g,
                                   chip_set[i].rgb.b);
                
                if (chip_set[i].description && strlen(chip_set[i].description) > 0) {
                    written += snprintf(buffer + written, buffer_size - written,
                                       "    %s\n", chip_set[i].description);
                }
            }
            
            written += snprintf(buffer + written, buffer_size - written,
                               "\nTotal: %zu color chips\n", chip_count);
            break;
        }
        
        case NC_OUTPUT_CSV: {
            written += snprintf(buffer + written, buffer_size - written,
                               "# %s in %s\n", set_name, color_space);
            written += snprintf(buffer + written, buffer_size - written,
                               "Name,R,G,B,Description\n");
            
            for (size_t i = 0; i < chip_count && written < (int)buffer_size - 1; i++) {
                written += snprintf(buffer + written, buffer_size - written,
                                   "%s,%.6f,%.6f,%.6f,%s\n",
                                   chip_set[i].name,
                                   chip_set[i].rgb.r,
                                   chip_set[i].rgb.g,
                                   chip_set[i].rgb.b,
                                   chip_set[i].description ? chip_set[i].description : "");
            }
            break;
        }
        
        case NC_OUTPUT_JSON: {
            written += snprintf(buffer + written, buffer_size - written, "{\n");
            written += snprintf(buffer + written, buffer_size - written,
                               "  \"name\": \"%s\",\n", set_name);
            written += snprintf(buffer + written, buffer_size - written,
                               "  \"color_space\": \"%s\",\n", color_space);
            written += snprintf(buffer + written, buffer_size - written, "  \"chips\": [\n");
            
            for (size_t i = 0; i < chip_count && written < (int)buffer_size - 1; i++) {
                const char* comma = (i < chip_count - 1) ? "," : "";
                written += snprintf(buffer + written, buffer_size - written,
                                   "    {\"name\": \"%s\", \"rgb\": [%.6f, %.6f, %.6f], \"description\": \"%s\"}%s\n",
                                   chip_set[i].name,
                                   chip_set[i].rgb.r,
                                   chip_set[i].rgb.g,
                                   chip_set[i].rgb.b,
                                   chip_set[i].description ? chip_set[i].description : "",
                                   comma);
            }
            
            written += snprintf(buffer + written, buffer_size - written, "  ]\n}\n");
            break;
        }
    }
    
    return written;
}

int NcWriteChipSetToFile(const NcColorChip* chip_set, size_t chip_count,
                         const char* color_space, const char* set_name,
                         NcOutputFormat format, const char* filename) {
    if (!filename) {
        return -1;
    }
    
    FILE* file = fopen(filename, "w");
    if (!file) {
        return -1;
    }
    
    // Use a large buffer for output
    const size_t buffer_size = 1024 * 1024; // 1MB
    char* buffer = malloc(buffer_size);
    if (!buffer) {
        fclose(file);
        return -1;
    }
    
    int written = NcExportChipSet(chip_set, chip_count, color_space, set_name, format, buffer, buffer_size);
    if (written > 0) {
        fwrite(buffer, 1, written, file);
    }
    
    free(buffer);
    fclose(file);
    
    return (written > 0) ? 0 : -1;
}

int NcParseChipSetType(const char* str) {
    if (!str) return -1;
    
    if (strcmp(str, "colorchecker") == 0) return NC_CHIPSET_COLORCHECKER;
    if (strcmp(str, "smpte_bars") == 0) return NC_CHIPSET_SMPTE_BARS;
    if (strcmp(str, "grayscale") == 0) return NC_CHIPSET_GRAYSCALE;
    if (strcmp(str, "spectral") == 0) return NC_CHIPSET_SPECTRAL;
    if (strcmp(str, "blackbody") == 0) return NC_CHIPSET_BLACKBODY;
    
    return -1;
}

int NcParseOutputFormat(const char* str) {
    if (!str) return -1;
    
    if (strcmp(str, "text") == 0) return NC_OUTPUT_TEXT;
    if (strcmp(str, "csv") == 0) return NC_OUTPUT_CSV;
    if (strcmp(str, "json") == 0) return NC_OUTPUT_JSON;
    
    return -1;
}

void NcPrintUsage(const char* program_name) {
    printf("Color Chip Generator for Nanocolor C\n\n");
    printf("Usage: %s [options]\n\n", program_name);
    printf("Options:\n");
    printf("  --chip-set, -s <name>     Chip set to generate (colorchecker, smpte_bars, grayscale, spectral, blackbody)\n");
    printf("  --target-space, -t <name> Target color space name (default: sRGB)\n");
    printf("  --format, -f <format>     Output format (text, csv, json) (default: text)\n");
    printf("  --output, -o <file>       Output filename (default: stdout)\n");
    printf("  --list-spaces, -l         List available color spaces\n");
    printf("  --list-chip-sets          List available chip sets\n");
    printf("  --help, -h                Show this help\n\n");
    printf("Examples:\n");
    printf("  %s --list-spaces\n", program_name);
    printf("  %s -s colorchecker -t sRGB\n", program_name);
    printf("  %s -s smpte_bars -t g22_rec709 -f csv -o smpte_rec709.csv\n", program_name);
    printf("  %s -s blackbody -t acescg -f json -o blackbody_acescg.json\n", program_name);
}

void NcListColorSpaces(void) {
    printf("Available color spaces:\n");
    const char** names = NcRegisteredColorSpaceNames();
    if (names) {
        for (int i = 0; names[i] != NULL; i++) {
            printf("  %s\n", names[i]);
        }
    }
}

void NcListChipSets(void) {
    printf("Available chip sets:\n");
    printf("  colorchecker: ColorChecker Classic (24 chips)\n");
    printf("  smpte_bars: SMPTE Color Bars (8 chips)\n");
    printf("  grayscale: Grayscale Patches (12 chips)\n");
    printf("  spectral: Spectral Primaries (7 chips)\n");
    printf("  blackbody: Blackbody Temperature Series (17 chips)\n");
}