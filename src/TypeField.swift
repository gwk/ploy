// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


struct TypeField: Equatable, CustomStringConvertible {

  let label: String?
  let type: Type

  var labelMsg: String {
    if let label = label {
      return "label `\(label)`"
     } else {
       return "no label"
     }
  }

  init(label: String?, type: Type) {
    self.label = label
    self.type = type
  }

  var description: String {
    if let label = label {
      return "\(label):\(type)"
    } else {
      return type.description
    }
  }

  func accessorString(index: Int) -> String { return label ?? String(index) }

  func hostName(index: Int) -> String { return label ?? "_\(index)" }

  static func ==(l: TypeField, r: TypeField) -> Bool { return l.label == r.label && l.type == r.type }
}
