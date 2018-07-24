// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


struct TypeLabField: Equatable, CustomStringConvertible {

  let label: String
  let type: Type

  var description: String {
    return "\(label):\(type)"
  }

  var accessorString: String { return label }

  var hostName: String { return label }

  func substitute(type: Type) -> TypeLabField {
    return TypeLabField(label: label, type: type)
  }

  func transformType(_ transform: (Type)->Type) -> TypeLabField {
    return substitute(type: transform(type))
  }
}
