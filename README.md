# Nanocolor

## A very small color transform library

### Pixar Animation Studios

## Introduction

Color management and transformation is a complex domain.
Values are captured by cameras or generated by renderers,
transferred to a storage medium, combined into frame buffers
to make new images, transformed for display, and projected
by devices. During each step, the color values may be
transformed by photochemical, electro-optical, and digital
processes.

A renderer's input working space to output working space is
an interesting subset of that domain, and it's the subset
that Nanocolor concerns itself with.

OpenEXR goes so far as to restrict itself to linear working
spaces, and describes them completed by specifying chromaticities
and an adapted whitepoint in the CIEXYZ 1931 space. Nanocolor
takes inspiration from this, and uses the equations in SMPTE
document RP177-1993 (reaffirmed in 2002) ~ SMPTE Recommended
Practice: Derivation of Basic Television Equations.

Interesting colors do not just come from OpenEXR however, but
may originate as properties in a MaterialX shade graph, vertex
attributes in an OpenUSD file, or PNG or TIFF textures, to
name a few common sources.

Amongst all these sources, only OpenEXR specifies colors in terms
of chromaticities and whitepoint. Some sources specify the color
space in documentation, whereas others name color spaces in the
data itself, or refer to site specific configuration files in
the OpenColorIO format, and other alternatives. This lack of
broad agreement on such things as what the name of a colorspace
actually refers to makes accurate and reproducible color
calculations between software packages and studios challenging.

MaterialX takes an interesting perspective; it names a bakers'
dozen of color spaces and defines them as OpenEXR does, and
also introduces a notion of being able to remove an input transform
from a color in order to accomodate image formats commonly used
as texture sources for shader graphs.

Nanocolor follows this idea, and also introduces that all the
color spaces must be invertible, in the sense that a value can
have its input transform removed to make it a linear color value,
linear values may be transformed as desired through matrix
multiplication, and an output transform may be re-applied. This
allows Nanocolor to transform any color space with this invertible
property to any other with the invertible property.

_____

## Definitions

Nomenclature shall be as per ISO 22028-1 terminology, and will occasionally spell colour with a u per common usage.

### Colour space

A geometric representation of colors in a metrical space.

### Colorimetric colour space

A colour space having an exact and simple relationship to CIEXY colorimetric values.

### Adopted white

A “spectral radiance distribution” that converts to achromatic colour signals where each component is 1.0

### Additive RGB colour space

colorimetric colour space with three primary chromaticities, a white point, and a transfer function

### Colour space encoding

“digital encoding of a colour space, including ... digital encoding method, and ... value range”

### Colour image encoding

Colour space encoding plus context, including image state, intended viewing environment, and for print, reference medium

_____

## Scope

Colour space encoding is in scope.

Colour image encoding is out of scope.

Camera vendor specific colour spaces are out of scope.

Colour spaces relative to a particular encoded white (cf. LAB, LUV, etc but also IPT and other spaces optimized for gamut mapping) are out of scope.

Hybrid Log Gamma encoding is out of scope.

_____

## Nanocolor API

Refer to nanocolor.h

## Building

There are no build scripts included with Nanocolor. You may build
it as a library if you wish, or you may include nanocolor.c,
and optionally nanocolorUtils.c in your project.

## License and Copyright

```c
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
```

## Acknowledgements

Thanks to the scientists at Pixar, OpenColorIO, OpenEXR, OpenUSD, and MaterialX
for the fruitful advice and feedback that helped guide the creation of Nanocolor.
