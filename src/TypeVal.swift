// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class TypeVal: Hashable {
  
  var hashValue: Int { return ObjectIdentifier(self).hashValue }

  func accepts(actual: TypeVal) -> Bool { fatalError() }
}

func ==(l: TypeVal, r: TypeVal) -> Bool { return l === r }


class TypeValAny: TypeVal {
  override func accepts(actual: TypeVal) -> Bool { return true }
}

class TypeValPrim: TypeVal {
  let name: Sym
  
  init(name: Sym) {
    self.name = name
    super.init()
  }
  
  override func accepts(actual: TypeVal) -> Bool { return actual === self }
}


class TypeValSig: TypeVal {
  let par: TypeVal
  let ret: TypeVal
  
  init(par: TypeVal, ret: TypeVal) {
    self.par = par
    self.ret = ret
    super.init()
  }
  
  override func accepts(actual: TypeVal) -> Bool {
    if let a = actual as? TypeValSig {
      return par.accepts(a.par) && ret.accepts(a.ret)
    }
    return false
  }
}

let typeAny = TypeValAny()

func anySigReturning(ret: TypeVal) -> TypeVal {
  return TypeValSig(par: typeAny, ret: ret)
}
