// © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Type: CustomStringConvertible, Hashable, Comparable {
  
  var hashValue: Int { return ObjectIdentifier(self).hashValue }

  let description: String

  init(description: String) {
    self.description = description
  }
  
  func accepts(actual: Type) -> Bool { return actual === self }
}

func ==(l: Type, r: Type) -> Bool { return l === r }

func <(l: Type, r: Type) -> Bool { return l.description < r.description }


class TypeObj: Type {

  init() {
    super.init(description: "Obj")
  }

  override func accepts(actual: Type) -> Bool { return true }
}


class TypeCmpd: Type {
  let pars: [TypePar]
  
  init(pars: [TypePar]) {
    self.pars = pars
    super.init(description: "<\(pars.map({$0.description}).joinWithSeparator(" "))>")
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
    super.init(description: sym.name)
  }
}


class TypePrim: Type {
  let name: String
  
  init(name: String) {
    self.name = name
    super.init(description: name)
  }
}


class TypeSig: Type {
  let par: Type
  let ret: Type
  
  init(par: Type, ret: Type) {
    self.par = par
    self.ret = ret
    super.init(description: "\(par)%\(ret)")
  }
  
  override func accepts(actual: Type) -> Bool {
    if let a = actual as? TypeSig {
      return par.accepts(a.par) && ret.accepts(a.ret)
    }
    return false
  }
}


class TypeAny: Type {
  let els: Set<Type>

  init(els: Set<Type>) {
    assert(els.isSorted)
    self.els = els
    super.init(description: "Any<\(els.map({$0.description}).sort().joinWithSeparator(" "))>")
  }

  override func accepts(actual: Type) -> Bool {
    if let actual = actual as? TypeAny {
      return els.isSupersetOf(actual.els)
    } else {
      return els.contains(actual)
    }
  }
}


let typeObj = TypeObj() // not currently available as an intrinsic type; only for 'accept' testing.

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
  typeObj,
  typeStr,
  typeType,
]


func typeSigReturning(ret: Type) -> Type {
  return TypeSig(par: typeObj, ret: ret)
}

let typeObjSig = TypeSig(par: typeObj, ret: typeObj)
