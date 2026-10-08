import Nanocolor
import Testing

private let libraryInitialized: Void = initColorSpaceLibrary()

@Suite struct NanocolorTests {
  init() { libraryInitialized }

  @Test func namedColorSpaces() throws {
    #expect(namedColorSpace("lin_ap1_scene") != nil)
    #expect(namedColorSpace("not_a_color_space") == nil)
  }

  @Test func roundTrip() throws {
    let acescg = try #require(namedColorSpace("lin_ap1_scene"))
    let srgb = try #require(namedColorSpace("srgb_rec709_scene"))
    let rgb = RGB(r: 0.5, g: 0.3, b: 0.8)
    let back = transformColor(to: acescg, from: srgb, transformColor(to: srgb, from: acescg, rgb))
    #expect(abs(back.r - rgb.r) < 1e-4)
    #expect(abs(back.g - rgb.g) < 1e-4)
    #expect(abs(back.b - rgb.b) < 1e-4)
  }

  @Test func transformColorsInPlace() throws {
    let acescg = try #require(namedColorSpace("lin_ap1_scene"))
    let rec709 = try #require(namedColorSpace("lin_rec709_scene"))
    var colors = [RGB(r: 1, g: 0, b: 0), RGB(r: 0, g: 1, b: 0)]
    var rgba = colors.map { RGBA(rgb: $0, alpha: 0.5) }
    transformColors(to: rec709, from: acescg, &colors, count: colors.count)
    transformColors(to: rec709, from: acescg, &rgba, count: rgba.count)
    for (c, a) in zip(colors, rgba) {
      #expect(c.r == a.rgb.r && c.g == a.rgb.g && c.b == a.rgb.b)
      #expect(a.alpha == 0.5)
    }
  }

  @Test func matchLinear() throws {
    let rec709 = try #require(namedColorSpace("lin_rec709_scene"))
    var desc = ColorSpaceDescriptor()
    #expect(getColorSpaceDescriptor(rec709, &desc))
    let name = try #require(matchLinearColorSpace(
      red: desc.redPrimary, green: desc.greenPrimary, blue: desc.bluePrimary,
      white: desc.whitePoint, epsilon: 1e-4))
    #expect(String(cString: name) == "lin_rec709_scene")
  }

  @Test func kelvin() {
    let d65 = kelvinToYxy(temperature: 6504, luminosity: 1)
    #expect(abs(d65.x - 0.3127) < 1e-2)
    #expect(abs(d65.y - 0.3290) < 1e-2)
  }
}
