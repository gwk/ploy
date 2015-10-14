// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Type: CustomStringConvertible, Hashable {
  
  var hashValue: Int { return ObjectIdentifier(self).hashValue }

  var description: String { fatalError() }
  
  func accepts(actual: Type) -> Bool { return actual === self }
}

func ==(l: Type, r: Type) -> Bool { return l === r }


class TypeAny: Type {
  
  override var description: String { return "Any" }

  override func accepts(actual: Type) -> Bool { return true }
}


class TypeCmpd: Type {
  let pars: [TypePar]
  
  init(pars: [TypePar]) {
    self.pars = pars
    super.init()
  }
  
  override var description: String {
    let s = pars.map({ $0.description }).joinWithSeparator(" ")
    return "<\(s)>"
  }
  
  override func accepts(actual: Type) -> Bool {
    guard let actual = actual as? TypeCmpd else {
      return false
    }
    for (exp, act) in zip(pars, actual.pars) {
      if !exp.accepts(act) {
        return false
      }
    }
    return true
  }
}

/// Type value for a declared type (enum, host, struct).
class TypeDecl: Type {
  let sym: Sym
  
  init(sym: Sym) {
    self.sym = sym
    super.init()
  }
  
  override var description: String { return sym.name }
}


class TypePrim: Type {
  let name: String
  
  init(name: String) {
    self.name = name
    super.init()
  }
  
  override var description: String { return name }
}


class TypeSig: Type {
  let par: Type
  let ret: Type
  
  init(par: Type, ret: Type) {
    self.par = par
    self.ret = ret
    super.init()
  }
  
  override var description: String { return "\(par)%\(ret)" }

  override func accepts(actual: Type) -> Bool {
    if let a = actual as? TypeSig {
      return par.accepts(a.par) && ret.accepts(a.ret)
    }
    return false
  }
}


let typeAny = TypeAny() // not currently available as an intrinsic type; only for 'accept' testing.

let typeVoid = TypeCmpd(pars: [])

let typeBool      = TypePrim(name: "Bool")
let typeInt       = TypePrim(name: "Int")
let typeNamespace = TypePrim(name: "Namespace")
let typeStr       = TypePrim(name: "Str")
let typeType      = TypePrim(name: "Type")

let intrinsicTypes = [
  typeBool,
  typeInt,
  typeNamespace,
  typeStr,
  typeType,
]


func anySigReturning(ret: Type) -> Type {
  return TypeSig(par: typeAny, ret: ret)
}

let typeAnySig = TypeSig(par: typeAny, ret: typeAny)
