// © 2016 George King. Permission to use this file is granted in license-quilt.txt.


import PackageDescription

let package = Package(
  name: "ploy",
  dependencies: [
    .Package(url: "git@github.com:gwk/quilt.git", majorVersion: 0)
  ]
)
