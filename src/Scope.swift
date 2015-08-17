// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


struct ScopeRec {
  enum Kind {
    case Type
    case Val
    case Lazy
  }
  
  let name: Sym
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
  
  func addRec(name: Sym, _ kind: ScopeRec.Kind, _ typeVal: TypeVal) {
    if let existing = bindings[name.string] {
      name.failRedef(existing.name)
    }
    bindings[name.string] = ScopeRec(name: name, kind: kind, typeVal: typeVal)
  }
  
  func getRec(sym: Sym) -> ScopeRec {
    if let rec = bindings[sym.string] {
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
    bindings["Void"] = ScopeRec(name: typeVoid.sym, kind: .Type, typeVal: typeVoid)
  }
}


let intrinsicSrc = Src(name: "<intrinsic>")
let intrinsicPos = intrinsicSrc.startPos
let intrinsicSyn = Syn(src: intrinsicSrc, pos: intrinsicPos, visEnd: intrinsicPos, end: intrinsicPos)

let typeVoid = TypeValPrim(sym: Sym(intrinsicSyn, string: "Void"))

let typeInt = globalScope.bindings["Int"]!.typeVal
let typeStr = globalScope.bindings["Str"]!.typeVal

let globalScope = GlobalScope()


