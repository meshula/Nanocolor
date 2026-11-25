// swift-tools-version:6.0
import PackageDescription

let package = Package(
  name: "Nanocolor",
  products: [
    .library(name: "Nanocolor", targets: ["Nanocolor"]),
  ],
  targets: [
    .target(
      name: "Nanocolor",
      path: ".",
      sources: ["nanocolor.c", "nanocolorUtils.c"],
      publicHeadersPath: "swift/include"
    ),

    .testTarget(
      name: "NanocolorTests",
      dependencies: ["Nanocolor"],
      path: "swift/Tests/NanocolorTests"
    ),
  ],
  cLanguageStandard: .c11
)
