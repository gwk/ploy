// swift-tools-version:4.0
// © 2016 George King. Permission to use this file is granted in license-ploy.txt.


import PackageDescription

let package = Package(
  name: "ploy",
  products: [
    .executable(name: "ploy", targets: ["ploy"])
  ],
  targets: [
    .target(name: "ploy", path: "src")
  ],
  swiftLanguageVersions: [4]
)
