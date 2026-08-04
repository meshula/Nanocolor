//
// Color Chip Generator for Nanocolor C - Main Program
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
#include <getopt.h>

typedef struct {
    NcChipSetType chip_set;
    const char* target_space;
    NcOutputFormat format;
    const char* output_file;
    bool list_spaces;
    bool list_chip_sets;
    bool help;
} Config;

static void init_config(Config* config) {
    config->chip_set = NC_CHIPSET_COLORCHECKER;
    config->target_space = "sRGB";
    config->format = NC_OUTPUT_TEXT;
    config->output_file = NULL;
    config->list_spaces = false;
    config->list_chip_sets = false;
    config->help = false;
}

static int parse_args(int argc, char* argv[], Config* config) {
    static struct option long_options[] = {
        {"chip-set", required_argument, 0, 's'},
        {"target-space", required_argument, 0, 't'},
        {"format", required_argument, 0, 'f'},
        {"output", required_argument, 0, 'o'},
        {"list-spaces", no_argument, 0, 'l'},
        {"list-chip-sets", no_argument, 0, 'L'},
        {"help", no_argument, 0, 'h'},
        {0, 0, 0, 0}
    };
    
    int c;
    while ((c = getopt_long(argc, argv, "s:t:f:o:lLh", long_options, NULL)) != -1) {
        switch (c) {
            case 's': {
                int type = NcParseChipSetType(optarg);
                if (type < 0) {
                    fprintf(stderr, "Error: Unknown chip set '%s'\n", optarg);
                    return -1;
                }
                config->chip_set = (NcChipSetType)type;
                break;
            }
            case 't':
                config->target_space = optarg;
                break;
            case 'f': {
                int fmt = NcParseOutputFormat(optarg);
                if (fmt < 0) {
                    fprintf(stderr, "Error: Unknown format '%s'\n", optarg);
                    return -1;
                }
                config->format = (NcOutputFormat)fmt;
                break;
            }
            case 'o':
                config->output_file = optarg;
                break;
            case 'l':
                config->list_spaces = true;
                break;
            case 'L':
                config->list_chip_sets = true;
                break;
            case 'h':
                config->help = true;
                break;
            case '?':
                return -1;
            default:
                return -1;
        }
    }
    
    return 0;
}

static int generate_chips(const Config* config) {
    // Initialize nanocolor
    NcInitColorSpaceLibrary();
    
    // Validate target color space
    const NcColorSpace* target_cs = NcGetNamedColorSpace(config->target_space);
    if (!target_cs) {
        fprintf(stderr, "Error: Unknown color space '%s'\n", config->target_space);
        fprintf(stderr, "Use --list-spaces to see available color spaces\n");
        return -1;
    }
    
    // Maximum number of chips we'll handle
    const size_t MAX_CHIPS = 64;
    NcColorChip chips[MAX_CHIPS];
    size_t chip_count = 0;
    const char* set_name = "Unknown";
    
    // Generate chip set
    if (config->chip_set == NC_CHIPSET_BLACKBODY) {
        int count = NcGenerateBlackbodySeries(2000.0f, 10000.0f, 17, chips, MAX_CHIPS);
        if (count < 0) {
            fprintf(stderr, "Error: Failed to generate blackbody series\n");
            return -1;
        }
        chip_count = count;
        set_name = "Blackbody Temperature Series";
    } else {
        const NcColorChipSet* predefined = NcGetPredefinedChipSet(config->chip_set);
        if (!predefined) {
            fprintf(stderr, "Error: Unknown chip set type\n");
            return -1;
        }
        
        // Transform if needed
        if (strcmp(predefined->color_space, config->target_space) == 0) {
            // No transformation needed
            chip_count = predefined->chip_count;
            if (chip_count > MAX_CHIPS) chip_count = MAX_CHIPS;
            memcpy(chips, predefined->chips, chip_count * sizeof(NcColorChip));
        } else {
            // Transform to target space
            int count = NcTransformChipSet(predefined, config->target_space, chips, MAX_CHIPS);
            if (count < 0) {
                fprintf(stderr, "Error: Failed to transform color chips\n");
                return -1;
            }
            chip_count = count;
        }
        set_name = predefined->name;
    }
    
    // Output results
    if (config->output_file) {
        if (NcWriteChipSetToFile(chips, chip_count, config->target_space, set_name, 
                                config->format, config->output_file) == 0) {
            printf("Exported %zu chips to %s\n", chip_count, config->output_file);
        } else {
            fprintf(stderr, "Error: Failed to write to file '%s'\n", config->output_file);
            return -1;
        }
    } else {
        // Output to stdout
        const size_t buffer_size = 1024// Output to stdout
        const size_t buffer_size = 1024 * 1024; // 1MB
        char* buffer = malloc(buffer_size);
        if (!buffer) {
            fprintf(stderr, "Error: Memory allocation failed\n");
            return -1;
        }
        
        int written = NcExportChipSet(chips, chip_count, config->target_space, set_name, 
                                     config->format, buffer, buffer_size);
        if (written > 0) {
            printf("%s", buffer);
        } else {
            fprintf(stderr, "Error: Failed to export chip set\n");
            free(buffer);
            return -1;
        }
        
        free(buffer);
    }
    
    return 0;
}

int main(int argc, char* argv[]) {
    Config config;
    init_config(&config);
    
    if (parse_args(argc, argv, &config) < 0) {
        NcPrintUsage(argv[0]);
        return 1;
    }
    
    if (config.help) {
        NcPrintUsage(argv[0]);
        return 0;
    }
    
    if (config.list_spaces) {
        NcInitColorSpaceLibrary();
        NcListColorSpaces();
        return 0;
    }
    
    if (config.list_chip_sets) {
        NcListChipSets();
        return 0;
    }
    
    return generate_chips(&config) == 0 ? 0 : 1;
}