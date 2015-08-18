// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class TypeVal: Hashable, CustomStringConvertible {
  
  var hashValue: Int { return ObjectIdentifier(self).hashValue }

  var description: String { fatalError() }
  
  func accepts(actual: TypeVal) -> Bool { return actual === self }
}

func ==(l: TypeVal, r: TypeVal) -> Bool { return l === r }


class TypeValAny: TypeVal {
  
  override var description: String { return "Any" }

  override func accepts(actual: TypeVal) -> Bool { return true }
}


class TypeValPrim: TypeVal {
  let name: String
  
  init(name: String) {
    self.name = name
    super.init()
  }
  
  override var description: String { return name }
}


class TypeValHost: TypeVal {
  let sym: Sym
  
  init(sym: Sym) {
    self.sym = sym
    super.init()
  }
  
  override var description: String { return sym.name }
}


class TypeValSig: TypeVal {
  let par: TypeVal
  let ret: TypeVal
  
  init(par: TypeVal, ret: TypeVal) {
    self.par = par
    self.ret = ret
    super.init()
  }
  
  override var description: String { return "\(par)%\(ret)" }

  override func accepts(actual: TypeVal) -> Bool {
    if let a = actual as? TypeValSig {
      return par.accepts(a.par) && ret.accepts(a.ret)
    }
    return false
  }
}


let typeAny     = TypeValAny()
let typeBool    = TypeValPrim(name: "Bool")
let typeInt     = TypeValPrim(name: "Int")
let typeModule  = TypeValPrim(name: "Module")
let typeStr     = TypeValPrim(name: "Str")
let typeType    = TypeValPrim(name: "Type")
let typeVoid    = TypeValPrim(name: "Void")

let intrinsicTypes = [
  typeAny,
  typeBool,
  typeInt,
  typeModule,
  typeStr,
  typeType,
  typeVoid,
]


func anySigReturning(ret: TypeVal) -> TypeVal {
  return TypeValSig(par: typeAny, ret: ret)
}
