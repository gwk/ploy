// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


struct TypeField: Equatable, CustomStringConvertible {

  let isVariant: Bool
  let label: String?
  let type: Type

  var labelMsg: String {
    if let label = label {
      return "label `\(label)`"
     } else {
       return "no label"
     }
  }

  init(isVariant: Bool, label: String?, type: Type) {
    self.isVariant = isVariant
    self.label = label
    self.type = type
  }

  var description: String {
    let l = label.and({$0 + ":"}) ?? ""
    return "\(isVariant ? "-" : "")\(l)\(type)"
  }

  var hasLabel: Bool { return label != nil }

  func accessorString(index: Int) -> String { return label ?? String(index) }

  func hostName(index: Int) -> String { return label ?? "_\(index)" }

  func substitute(type: Type) -> TypeField {
    return TypeField(isVariant: isVariant, label: label, type: type)
  }

  func transformType(_ transform: (Type)->Type) -> TypeField {
    return substitute(type: transform(type))
  }
}
