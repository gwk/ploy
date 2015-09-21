// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


struct ScopeRecord {
  typealias _Type = Type // Type type gets masked by the variant name.

  enum Kind {
    case Lazy(_Type)
    case Space(Scope)
    case Type(_Type)
    case Val(_Type)
    
    var kindDesc: String {
      switch self {
      case Lazy:  return "lazy value"
      case Space: return "namespace"
      case Type:  return "type"
      case Val:   return "value"
      }
    }
  }
  
  let sym: Sym?
  let hostName: String
  let isFwd: Bool
  let kind: Kind
  
  init(sym: Sym?, hostName: String, isFwd: Bool, kind: Kind) {
    self.sym = sym
    self.hostName = hostName
    self.isFwd = isFwd
    self.kind = kind
  }
}


class Scope {
  let pathNames: [String]
  let hostPrefix: String
  let parent: Scope?
  
  var bindings: [String: ScopeRecord] = [:]
  var defs: [String: Def] = [:]
  var usedDefs: [Def] = []
  
  init(pathNames: [String], parent: Scope?) {
    self.pathNames = pathNames
    self.hostPrefix = pathNames.isEmpty ? "" : (pathNames.joinWithSeparator("__") + "__")
    self.parent = parent
  }
  
  var name: String { return pathNames.joinWithSeparator("/") }
  
  func makeChild(bindings: [String:Type] = [:]) -> Scope {
    return Scope.init(pathNames: [], parent: self)
  }
  
  func addRecord(sym: Sym, isFwd: Bool, kind: ScopeRecord.Kind) -> ScopeRecord {
    if let existing = bindings[sym.name] {
      if existing.isFwd {
        assert(!isFwd)
        assert(existing.sym!.name == sym.name)
        //assert(existing.kind == kind) // would be nice to have, but equality of Kind enum is a pain to implement.
        bindings.removeValueForKey(sym.name)
      } else {
        sym.failRedef(existing.sym)
      }
    }
    let r = ScopeRecord(sym: sym, hostName: hostPrefix + sym.hostName, isFwd: isFwd, kind: kind)
    bindings[sym.name] = r
    return r
  }
  
  func addValRecord(key: String, type: Type) {
    assert(!bindings.contains(key))
    bindings[key] = ScopeRecord(sym: nil, hostName: key, isFwd: false, kind: .Val(type))
  }
  
  func getRecord(sym: Sym) -> ScopeRecord? {
    if let r = bindings[sym.name] {
      return r
    }
    if let def = defs[sym.name] {
      let r = addRecord(def.sym, isFwd: true, kind: def.scopeRecordKind(self))
      usedDefs.append(def)
      return r
    }
    return nil
  }
  
  func rec(sym: Sym) -> ScopeRecord {
    if let r = getRecord(sym) {
      return r
    }
    if let parent = parent {
      return parent.rec(sym)
    }
    sym.failUndef()
  }
  
  func rec(path: Path) -> ScopeRecord {
    var scope = self
    for (i, sym) in path.syms.enumerate() {
      let r = scope.rec(sym)
      if i == path.syms.lastIndex! {
        return r
      }
      switch r.kind {
      case .Space(let space):
        scope = space
      default: sym.failType("expected a space; found a \(r.kind.kindDesc)")
      }
    }
    fatalError()
  }
}

