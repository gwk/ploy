// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class TypeValPar: CustomStringConvertible {
  
  let index: Int
  let label: Sym?
  let typeVal: TypeVal
  let form: Par?
  
  init(index: Int, label: Sym?, typeVal: TypeVal, form: Par?) {
    self.index = index
    self.label = label
    self.typeVal = typeVal
    self.form = form
  }
  
  var description: String {
    if let label = label {
      return "\(label.name):\(typeVal)"
    } else {
      return typeVal.description
    }
  }
  
  var hostName: String { return (label?.name.dashToUnder).or("\"\(index)\"") }

  func accepts(actual: TypeValPar) -> Bool {
    return index == actual.index && label?.name == actual.label?.name && typeVal.accepts(actual.typeVal)
  }
}

