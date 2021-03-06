// © 2016 George King. Permission to use this file is granted in license.txt.


struct Conversion: Comparable, Hashable, CustomStringConvertible {

  let orig: Type
  let cast: Type

  var description: String { return "\(orig) ~> \(cast)" }

  var hostName: String { return "$c\(orig.globalIndex)_\(cast.globalIndex)" } // bling: $c<i>_<j>: conversion.

}

func <(l: Conversion, r: Conversion) -> Bool { return l.orig < r.orig || l.orig == r.orig && l.cast < r.cast }
