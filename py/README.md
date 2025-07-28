
using usd-colorchecker.py

```python
# List available color spaces
python usd-colorchecker.py --list-spaces

# Generate ColorChecker in sRGB
python usd-colorchecker.py --color-space sRGB

# Generate in ACEScg with custom output name
python usd-colorchecker.py -c acescg -o my_colorchecker.usda

# Generate in linear Rec.709 with 2x scale
python usd-colorchecker.py -c lin_rec709 --scale 2.0

# Generate in ASCII format for version control
python usd-colorchecker.py -c lin_srgb --ascii

# View the result
usdview colorchecker-srgb.usda
```