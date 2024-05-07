
color input values are scene-referred, which means that the color values encoded
are just numbers that meant something in the scene they came from.

color inputs must be invertible to linear space via gamma and lift. So an srgb 
input is allowable, however an ACESCg color with a render transform is not. Such
a transformed color will be respected, but if a grade has been applied, those
colors are not going to be inveerted to the other side of the grade.

color output values are layer-referred, which means the color values are numbers
that mean something in the layer's color space

color outputs may be transformed via a gamma and lift, however general render
transformations are not allowed.

layer color is always in a linear space. This means, a space whose chromaticities,
whitepoint, and reference luminance values are indicated. No non-linearities
are preserved in a layer cs.

if a color property or attribute on a layer is overridden from another layer, reading the output of the
property or attribute will occur through a transformation from the originating
layer to the layer being interrorgated.

If a color is overridden, reading the value will involve a transformation from the originating color space to the color space of the value being interrogated.

 the key thing is that if the stronger layer direclty overrides the property's colorSpace metadata, then the weaker layer's value is not considered at all.  If the stronger layer sets colorSpace on the prim (or an ancestor prim) then the colorSpace metadata on the property is still considered the colorspace for the property, because it is "closer".  But we never need to walk through the PropertyStack to find all colorSpace opinions for a property.
 
applied api schema allows applying the attribute that names the color space and
it inherits down the naemspace

example

    token triangleSubdivisionRule = "catmullClark" (
        allowedTokens = ["catmullClark", "smooth"]
        doc = """Specifies an option to the subdivision rules for the
        Catmull-Clark scheme to try and improve undesirable artifacts when
        subdividing triangles.  Valid values are "catmullClark" for the
        standard rules (the default) and "smooth" for the improvement.

        See https://graphics.pixar.com/opensubdiv/docs/subdivision_surfaces.html#triangle-subdivision-rule""")
    
one multiapply schema declares a new colorspace

regular sg mechanisms work for custom cs is a "yellow override", ie allowed but flagged
overriding the 13 is a "red override", ie disallowed

https://www.shadertoy.com/view/Dt3XDr AgX DS impl
https://www.shadertoy.com/view/dtSGD1 AgX
https://www.shadertoy.com/view/cd3XWr AgXMinimal
https://macrofacet.github.io/horoma/ horoma https://github.com/macrofacet/horoma 


from usd/attribute.h


    // ---------------------------------------------------------------------- //
    /// \anchor Usd_AttributeColorSpaceAPI
    /// \name ColorSpace API
    /// 
    /// The color space in which a given color or texture valued attribute is 
    /// authored is set as token-valued metadata 'colorSpace' on the attribute. 
    /// For color or texture attributes that don't have an authored 'colorSpace'
    /// value, the fallback color-space is gleaned from whatever color 
    /// management system is specified by UsdStage::GetColorManagementSystem().
    /// 
    /// @{
    // ---------------------------------------------------------------------- //

    /// Gets the color space in which the attribute is authored.
    /// \sa SetColorSpace()
    /// \ref Usd_ColorConfigurationAPI "UsdStage Color Configuration API"
    USD_API
    TfToken GetColorSpace() const;

    /// Sets the color space of the attribute to \p colorSpace.
    /// \sa GetColorSpace()
    /// \ref Usd_ColorConfigurationAPI "UsdStage Color Configuration API"
    USD_API
    void SetColorSpace(const TfToken &colorSpace) const;

    /// Returns whether color-space is authored on the attribute.
    /// \sa GetColorSpace()
    USD_API
    bool HasColorSpace() const;

    /// Clears authored color-space value on the attribute.
    /// \sa SetColorSpace()
    USD_API
    bool ClearColorSpace() const;



from stage.h

  // --------------------------------------------------------------------- //
    /// \anchor Usd_ColorConfigurationAPI
    /// \name Color Configuration API
    ///
    /// Methods for authoring and querying the color configuration to 
    /// be used to interpret the per-attribute color-spaces. An external 
    /// system (like OpenColorIO) is typically used for interpreting the
    /// configuration.
    /// 
    /// Site-wide fallback values for the colorConfiguration and
    /// colorManagementSystem metadata can be set in the plugInfo.json file of 
    /// a plugin using this structure:
    /// 
    /// \code{.json}
    ///         "UsdColorConfigFallbacks": {
    ///             "colorConfiguration" = "https://github.com/imageworks/OpenColorIO-Configs/blob/master/aces_1.0.1/config.ocio",
    ///             "colorManagementSystem" : "OpenColorIO"
    ///         }
    /// \endcode
    /// 
    /// The color space in which a given color or texture attribute is authored 
    /// is set as token-valued metadata 'colorSpace' on the attribute. For 
    /// color or texture attributes that don't have an authored 'colorSpace'
    /// value, the fallback color-space is gleaned from the color configuration 
    /// oracle. This is usually the config's <b>scene_linear</b> role
    /// color-space.
    /// 
    /// Here's the pseudo-code for determining an attribute's color-space.
    /// 
    /// \code{.cpp}
    /// UsdStageRefPtr stage = UsdStage::Open(filePath);
    /// UsdPrim prim = stage->GetPrimAtPath("/path/to/prim")
    /// UsdAttribute attr = prim.GetAttribute("someColorAttr");
    /// TfToken colorSpace = attr.GetColorSpace();
    /// if (colorSpace.IsEmpty()) {
    ///     // If colorSpace is empty, get the default from the stage's 
    ///     // colorConfiguration, using external API (not provided by USD).
    ///     colorSpace = ExternalAPI::GetDefaultColorSpace(
    ///                         stage->GetColorConfiguration());
    /// }
    /// \endcode
    ///
    /// \sa \ref Usd_AttributeColorSpaceAPI "UsdAttribute ColorSpace API"
    /// 


    /// Sets the default color configuration to be used to interpret the 
    /// per-attribute color-spaces in the composed USD stage. This is specified
    /// as asset path which can be resolved to the color spec file.
    /// 
    /// \ref Usd_ColorConfigurationAPI "Color Configuration API"
    USD_API
    void SetColorConfiguration(const SdfAssetPath &colorConfig) const;

    /// Returns the default color configuration used to interpret the per-
    /// attribute color-spaces in the composed USD stage.
    /// 
    /// \ref Usd_ColorConfigurationAPI "Color Configuration API"
    USD_API
    SdfAssetPath GetColorConfiguration() const;

    /// Sets the name of the color management system used to interpret the 
    /// color configuration file pointed at by the colorConfiguration metadata.
    /// 
    /// \ref Usd_ColorConfigurationAPI "Color Configuration API"
    USD_API
    void SetColorManagementSystem(const TfToken &cms) const;

    /// Sets the name of the color management system to be used for loading 
    /// and interpreting the color configuration file.
    /// 
    /// \ref Usd_ColorConfigurationAPI "Color Configuration API"
    USD_API
    TfToken GetColorManagementSystem() const;

    /// Returns the global fallback values of 'colorConfiguration' and 
    /// 'colorManagementSystem'. These are set in the plugInfo.json file 
    /// of a plugin, but can be overridden by calling the static method 
    /// SetColorConfigFallbacks().
    /// 
    /// The python wrapping of this method returns a tuple containing 
    /// (colorConfiguration, colorManagementSystem).
    /// 
    /// 
    /// \sa SetColorConfigFallbacks,
    /// \ref Usd_ColorConfigurationAPI "Color Configuration API"
    USD_API
    static void GetColorConfigFallbacks(SdfAssetPath *colorConfiguration,
                                        TfToken *colorManagementSystem);

    /// Sets the global fallback values of color configuration metadata which 
    /// includes the 'colorConfiguration' asset path and the name of the 
    /// color management system. This overrides any fallback values authored 
    /// in plugInfo files.
    /// 
    /// If the specified value of \p colorConfiguration or 
    /// \p colorManagementSystem is empty, then the corresponding fallback 
    /// value isn't set. In other words, for this call to have an effect, 
    /// at least one value must be non-empty. Additionally, these can't be
    /// reset to empty values.
    ///
    /// \sa GetColorConfigFallbacks()
    /// \ref Usd_ColorConfigurationAPI "Color Configuration API"
    USD_API
    static void
    SetColorConfigFallbacks(const SdfAssetPath &colorConfiguration, 
                            const TfToken &colorManagementSystem);
