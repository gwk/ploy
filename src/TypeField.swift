// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


struct TypeField: CustomStringConvertible {

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

  func accessorString(index: Int) -> String { return label.or(String(index)) }

  func hostName(index: Int) -> String { return label.or("_\(index)") }
}
