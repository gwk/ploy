// © 2016 George King. Permission to use this file is granted in license.txt.


struct Conversion: CustomStringConvertible {

  let orig: Type
  let conv: Type

  var description: String { return "\(orig) -> \(conv)" }
}


