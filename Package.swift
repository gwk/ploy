// swift-tools-version:5.0
// © 2016 George King. Permission to use this file is granted in license-ploy.txt.


import PackageDescription

let package = Package(
  name: "ploy",
  platforms: [.macOS(.v10_14)],
  products: [
    .executable(name: "ploy", targets: ["ploy"])
  ],
  targets: [
    .target(name: "ploy",
      path: ".",
      exclude: [],
      sources: [
        "src",
        "legs/legs/legs_base.swift",
        "quilt/src/Quilt/AppendableStruct.swift",
        "quilt/src/Quilt/ArithmeticInt.swift",
        "quilt/src/Quilt/ArithmeticProtocol.swift",
        "quilt/src/Quilt/Array.swift",
        "quilt/src/Quilt/BidirectionalCollection.swift",
        "quilt/src/Quilt/Buffer.swift",
        "quilt/src/Quilt/Bundle.swift",
        "quilt/src/Quilt/Chain.swift",
        "quilt/src/Quilt/Character.swift",
        "quilt/src/Quilt/Collection.swift",
        "quilt/src/Quilt/CountableRange.swift",
        "quilt/src/Quilt/Data.swift",
        "quilt/src/Quilt/DefaultInitializable.swift",
        "quilt/src/Quilt/DictOfSet.swift",
        "quilt/src/Quilt/Dictionary.swift",
        "quilt/src/Quilt/Dir.swift",
        "quilt/src/Quilt/DuplicateElError.swift",
        "quilt/src/Quilt/DuplicateKeyError.swift",
        "quilt/src/Quilt/Err.swift",
        "quilt/src/Quilt/Encoder.swift",
        "quilt/src/Quilt/Error.swift",
        "quilt/src/Quilt/File.swift",
        "quilt/src/Quilt/FileHandle.swift",
        "quilt/src/Quilt/FileManager.swift",
        "quilt/src/Quilt/Index.swift",
        "quilt/src/Quilt/Int.swift",
        "quilt/src/Quilt/IntegerInitable.swift",
        "quilt/src/Quilt/MutBuffer.swift",
        "quilt/src/Quilt/MutPtr.swift",
        "quilt/src/Quilt/MutRawBuffer.swift",
        "quilt/src/Quilt/MutRawPtr.swift",
        "quilt/src/Quilt/OptionSet.swift",
        "quilt/src/Quilt/Optional-String.swift",
        "quilt/src/Quilt/Optional.swift",
        "quilt/src/Quilt/OutputStream.swift",
        "quilt/src/Quilt/Path.swift",
        "quilt/src/Quilt/Process.swift",
        "quilt/src/Quilt/ProcessInfo.swift",
        "quilt/src/Quilt/Ptr.swift",
        "quilt/src/Quilt/RangeReplaceableCollection.swift",
        "quilt/src/Quilt/RawBuffer.swift",
        "quilt/src/Quilt/RawPtr.swift",
        "quilt/src/Quilt/Ref.swift",
        "quilt/src/Quilt/Result.swift",
        "quilt/src/Quilt/Sequence-Bool.swift",
        "quilt/src/Quilt/Sequence-Comparable.swift",
        "quilt/src/Quilt/Sequence-Equatable.swift",
        "quilt/src/Quilt/Sequence-String.swift",
        "quilt/src/Quilt/Sequence-Substring.swift",
        "quilt/src/Quilt/Sequence.swift",
        "quilt/src/Quilt/Set.swift",
        "quilt/src/Quilt/String.swift",
        "quilt/src/Quilt/StringInitable.swift",
        "quilt/src/Quilt/TextInitable.swift",
        "quilt/src/Quilt/TextOutputStream.swift",
        "quilt/src/Quilt/TextOutputStreamable.swift",
        "quilt/src/Quilt/TextTreeStreamable.swift",
        "quilt/src/Quilt/UInt16.swift",
        "quilt/src/Quilt/UInt8.swift",
        "quilt/src/Quilt/UnicodePoint.swift",
        "quilt/src/Quilt/Zip3.swift",
        "quilt/src/Quilt/check.swift",
        "quilt/src/Quilt/fs.swift",
        "quilt/src/Quilt/func.swift",
        "quilt/src/Quilt/sys.swift",
      ])],
  swiftLanguageVersions: [.v5]
)
