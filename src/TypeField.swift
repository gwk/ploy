// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class TypeField: CustomStringConvertible {

  let index: Int
  let label: String?
  let type: Type

  var labelMsg: String {
    if let label = label {
      return "label `\(label)`"
     } else {
       return "no label"
     }
  }

  init(index: Int, label: String?, type: Type) {
    self.index = index
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

  var accessorString: String { return label.or(String(index)) }

  var hostName: String { return label.or("_\(index)") }
}
