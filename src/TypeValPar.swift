// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class TypeValPar: CustomStringConvertible {

  let par: Par
  let typeVal: TypeVal
  
  init(par: Par, typeVal: TypeVal) {
    self.par = par
    self.typeVal = typeVal
  }
  
  var description: String { return "\(par.hostName):\(typeVal)" } // TODO: do not use hostname.
  
  func accepts(actual: TypeValPar) -> Bool {
    return par.hostName == actual.par.hostName && typeVal.accepts(actual.typeVal)
  }
}

