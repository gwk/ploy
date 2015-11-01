// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class TypePar: CustomStringConvertible {
  
  let index: Int
  let label: Sym?
  let type: Type
  let form: Par?
  
  init(index: Int, label: Sym?, type: Type, form: Par?) {
    self.index = index
    self.label = label
    self.type = type
    self.form = form
  }
  
  var description: String {
    if let label = label {
      return "\(label.name):\(type)"
    } else {
      return type.description
    }
  }
  
  var hostName: String { return (label?.name.dashToUnder).or("\"\(index)\"") }

  func accepts(actual: TypePar) -> Bool {
    return index == actual.index && label?.name == actual.label?.name && type.accepts(actual.type)
  }
}
