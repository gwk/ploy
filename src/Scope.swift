// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


struct ScopeRec {
  enum Kind {
    case Type
    case Val
    case Lazy
  }
  
  let sym: Sym?
  let kind: Kind
  let typeVal: TypeVal
}


class Scope {
  let parent: Scope?
  let isModule: Bool
  var bindings: [String: ScopeRec] = [:]

  init(parent: Scope?, isModule: Bool) {
    self.parent = parent
    self.isModule = isModule
  }
  
  func addRec(sym: Sym, _ kind: ScopeRec.Kind, _ typeVal: TypeVal) {
    if let existing = bindings[sym.name] {
      sym.failRedef(existing.sym)
    }
    bindings[sym.name] = ScopeRec(sym: sym, kind: kind, typeVal: typeVal)
  }
  
  func getRec(sym: Sym) -> ScopeRec {
    if let rec = bindings[sym.name] {
      return rec
    }
    if let parent = parent {
      return parent.getRec(sym)
    }
    sym.failUndef()
  }
}


class GlobalScope: Scope {
  
  init() {
    super.init(parent: nil, isModule: false)
    for prim in [typeVoid, typeBool, typeInt, typeStr] {
      bindings[prim.name] = ScopeRec(sym: nil, kind: .Type, typeVal: prim)
    }
  }
}

let globalScope = GlobalScope()


